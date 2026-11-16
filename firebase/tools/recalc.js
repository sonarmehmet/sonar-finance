'use strict';
// Tutarlilik denetimi (docs/08 §7). Kullanim: node recalc.js --company sonar [--fix]
// Varsayilan: salt-okunur rapor. --fix yalniz bakiye/toplam alanlarini hareket toplamlarina esitler.
// Emulator icin FIRESTORE_EMULATOR_HOST; gercek proje icin servis hesabi (GOOGLE_APPLICATION_CREDENTIALS).
const admin = require('firebase-admin');

function arg(name, def) {
  const i = process.argv.indexOf('--' + name);
  if (i === -1) return def;
  const next = process.argv[i + 1];
  return !next || next.startsWith('--') ? true : next;
}
async function all(db, path) {
  const snap = await db.collection(path).get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}
function sumBy(rows, key, val) {
  const m = {};
  for (const r of rows) m[r[key]] = (m[r[key]] || 0) + r[val];
  return m;
}

async function main() {
  const cid = arg('company');
  if (!cid || cid === true) { console.error('--company <id> gerekli'); process.exit(1); }
  const fix = !!arg('fix', false);
  if (fix && !process.env.FIRESTORE_EMULATOR_HOST && !(arg('production', false) && arg('i-know-what-i-am-doing', false))) {
    console.error('Gercek projede --fix icin: --production --i-know-what-i-am-doing'); process.exit(1);
  }
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'demo-sonar-finance' });
  const db = admin.firestore();
  const base = `companies/${cid}`;

  const [parties, accounts, products, levels, invoices, payments, ledger, accMov, stockMov] = await Promise.all([
    all(db, `${base}/parties`), all(db, `${base}/accounts`), all(db, `${base}/products`), all(db, `${base}/stock_levels`),
    all(db, `${base}/invoices`), all(db, `${base}/payments`), all(db, `${base}/ledger_entries`),
    all(db, `${base}/account_movements`), all(db, `${base}/stock_movements`),
  ]);

  const issues = [];
  const writes = [];
  const check = (what, id, actual, expected, ref, field) => {
    if (actual !== expected) {
      issues.push({ what, id, actual, expected });
      if (fix) writes.push([ref, { [field]: expected }]);
    }
  };

  const ledSum = sumBy(ledger, 'partyId', 'deltaMinor');
  for (const p of parties) check('cari bakiye', p.id, p.balanceMinor, ledSum[p.id] || 0, db.doc(`${base}/parties/${p.id}`), 'balanceMinor');

  const accSum = sumBy(accMov, 'accountId', 'deltaMinor');
  for (const a of accounts) check('hesap bakiye', a.id, a.balanceMinor, accSum[a.id] || 0, db.doc(`${base}/accounts/${a.id}`), 'balanceMinor');

  const lvSum = {};
  for (const m of stockMov) { const k = `${m.productId}_${m.warehouseId}`; lvSum[k] = (lvSum[k] || 0) + m.deltaMilli; }
  const prodTotal = {};
  for (const l of levels) {
    check('stok seviye', l.id, l.qtyMilli, lvSum[l.id] || 0, db.doc(`${base}/stock_levels/${l.id}`), 'qtyMilli');
    prodTotal[l.productId] = (prodTotal[l.productId] || 0) + (lvSum[l.id] || 0);
  }
  for (const p of products) {
    if (p.trackStock === false) continue;
    check('urun toplam stok', p.id, p.totalQtyMilli, prodTotal[p.id] || 0, db.doc(`${base}/products/${p.id}`), 'totalQtyMilli');
  }

  const paidByInv = {};
  for (const pay of payments) {
    if (pay.status !== 'active') continue;
    for (const al of pay.allocations || []) paidByInv[al.invoiceId] = (paidByInv[al.invoiceId] || 0) + al.amountMinor;
  }
  for (const inv of invoices) {
    if (inv.status !== 'issued') continue;
    check('fatura odenen', inv.id, inv.paidMinor, paidByInv[inv.id] || 0, db.doc(`${base}/invoices/${inv.id}`), 'paidMinor');
  }

  console.log(issues.length ? `${issues.length} tutarsizlik:` : 'Tutarsizlik yok.');
  for (const i of issues) console.log(` - ${i.what} [${i.id}] mevcut=${i.actual} beklenen=${i.expected}`);

  if (fix && writes.length) {
    const w = db.bulkWriter();
    for (const [ref, data] of writes) w.update(ref, data);
    await w.close();
    console.log(`${writes.length} alan duzeltildi. paymentStatus/stats icin uygulamadan yeniden hesapla veya elle kontrol edin.`);
  }
  process.exit(issues.length && !fix ? 2 : 0);
}
main().catch((e) => { console.error(e); process.exit(1); });
