'use strict';
// SONAR FINANCE - Emulator seed (DEMO verisi). Sozlesme v1.0.0 ile uyumludur.
// Guvenlik: yalnizca emulatore yazar; emulator ortam degiskenleri yoksa durur.
const admin = require('firebase-admin');

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  console.error('HATA: FIRESTORE_EMULATOR_HOST ve FIREBASE_AUTH_EMULATOR_HOST tanimli degil. Uretime yazmamak icin durduruldu.');
  console.error('Ornek: set FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 ve set FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099');
  process.exit(1);
}

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-sonar-finance';
admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const auth = admin.auth();
const TS = admin.firestore.Timestamp;

const CID = 'sonar';
const TODAY = '2026-11-16';
const now = TS.now();
const base = (extra) => Object.assign({ companyId: CID }, extra);
const col = (name, id) => db.doc(`companies/${CID}/${name}/${id}`);

const OPEN_STOCK_TX = 'seed-open-stock-001';
const OPEN_CASH_TX = 'seed-open-cash-001';

// --- Ana veri ---
const warehouses = [
  { id: 'wh-main', name: 'Ana Depo', location: 'Merkez', isDefault: true },
  { id: 'wh-site', name: 'Şantiye Deposu', location: 'Proje alani', isDefault: false },
];

// qty: { depoId: miktar (adet/metre) }, avg: birim maliyet (kurus)
const products = [
  { id: 'p-valve', code: 'PRD-0001', name: 'Küresel Vana DN50', category: 'Armatür', unit: 'adet', vatBp: 2000, buy: 85000, sell: 120000, min: 10, qty: { 'wh-main': 40, 'wh-site': 10 } },
  { id: 'p-pipe', code: 'PRD-0002', name: 'PPR Boru 32mm', category: 'Boru', unit: 'metre', vatBp: 2000, buy: 4500, sell: 6800, min: 100, qty: { 'wh-main': 500 } },
  { id: 'p-pump', code: 'PRD-0003', name: 'Sirkülasyon Pompası', category: 'Ekipman', unit: 'adet', vatBp: 2000, buy: 1250000, sell: 1650000, min: 2, qty: { 'wh-main': 6 } },
  { id: 'p-radiator', code: 'PRD-0004', name: 'Panel Radyatör 600x1000', category: 'Isıtma', unit: 'adet', vatBp: 2000, buy: 185000, sell: 245000, min: 6, qty: { 'wh-main': 24 } },
  { id: 'p-sprinkler', code: 'PRD-0005', name: 'Sprinkler Başlığı', category: 'Yangın', unit: 'adet', vatBp: 2000, buy: 22000, sell: 32000, min: 30, qty: { 'wh-main': 120, 'wh-site': 30 } },
  { id: 'p-labor', code: 'HZM-0001', name: 'Montaj İşçilik', category: 'Hizmet', unit: 'saat', vatBp: 2000, buy: 0, sell: 85000, min: 0, qty: {}, trackStock: false },
];

const parties = [
  { id: 'pt-acme', kinds: ['customer'], name: 'Acme Yapı A.Ş.', taxOffice: 'Kilis', taxNo: '1111111111', phone: '0348 000 00 01', email: 'muhasebe@acme.example', address: 'Kilis' },
  { id: 'pt-vega', kinds: ['customer'], name: 'Vega Otel İşletmeleri', taxOffice: 'Gaziantep', taxNo: '2222222222', phone: '0342 000 00 02', email: 'info@vega.example', address: 'Gaziantep' },
  { id: 'pt-tedarik', kinds: ['supplier'], name: 'Mega Tesisat Toptan', taxOffice: 'Gaziantep', taxNo: '3333333333', phone: '0342 000 00 03', email: 'satis@mega.example', address: 'Gaziantep' },
  { id: 'pt-both', kinds: ['customer', 'supplier'], name: 'Delta Mühendislik', taxOffice: 'Kilis', taxNo: '4444444444', phone: '0348 000 00 04', email: 'info@delta.example', address: 'Kilis' },
];

// Hesaplar: acilis bakiyesi hareket belgesiyle desteklenir
const accounts = [
  { id: 'acc-cash', type: 'cash', name: 'Ana Kasa', bankName: '', iban: '', opening: 5000000 },
  { id: 'acc-ziraat', type: 'bank', name: 'Ziraat Bankası', bankName: 'Ziraat Bankası', iban: 'TR000000000000000000000000', opening: 25000000 },
  { id: 'acc-is', type: 'bank', name: 'İş Bankası', bankName: 'İş Bankası', iban: 'TR000000000000000000000001', opening: 0 },
];

const project = {
  id: 'prj-otel', name: 'Vega Otel - Mekanik Tesisat', partyId: 'pt-vega', location: 'Gaziantep',
  startDate: '2026-10-01', endDate: '2027-03-31', contractMinor: 450000000, status: 'active',
  budgets: { heating: 90000000, cooling: 70000000, ventilation: 40000000, fire_protection: 60000000, plumbing: 50000000, labor: 80000000, transport: 10000000, general: 10000000 },
  notes: 'DEMO proje',
};

async function main() {
  // Auth kullanicilari (emulator)
  const users = [
    { uid: 'uid-admin', email: 'admin@sonar.local', password: 'Test1234!', displayName: 'Yönetici', role: 'admin', permissions: {} },
    { uid: 'uid-employee', email: 'calisan@sonar.local', password: 'Test1234!', displayName: 'Çalışan', role: 'employee',
      permissions: { 'invoice.write': true, 'party.write': true, 'stock.write': true, 'finance.write': false, 'project.write': false } },
  ];
  for (const u of users) {
    try {
      await auth.createUser({ uid: u.uid, email: u.email, password: u.password, displayName: u.displayName });
    } catch (e) {
      if (e.code === 'auth/uid-already-exists' || e.code === 'auth/email-already-exists') {
        await auth.updateUser(u.uid, { email: u.email, password: u.password, displayName: u.displayName });
      } else { throw e; }
    }
  }

  const batch = db.batch();
  const set = (ref, data) => batch.set(ref, data);

  for (const u of users) {
    set(db.doc(`users/${u.uid}`), { companyId: CID, displayName: u.displayName, email: u.email, role: u.role, permissions: u.permissions, active: true, createdAt: now });
  }

  set(db.doc(`companies/${CID}`), {
    companyId: CID, name: 'SONAR Mekanik (DEMO)', taxNo: '0000000000', taxOffice: 'Kilis', address: 'Kilis', phone: '', currency: 'TRY', schemaVersion: 1,
    settings: { allowNegativeStock: false, defaultVatBp: 2000, invoicePrefix: { sales: 'SF', purchase: 'AF', sales_return: 'SI', purchase_return: 'AI' } },
  });

  for (const w of warehouses) {
    set(col('warehouses', w.id), base({ name: w.name, location: w.location, isDefault: w.isDefault, active: true }));
  }

  // Urunler + acilis stoku (seviye + hareket + urun toplami)
  for (const p of products) {
    const track = p.trackStock !== false;
    let total = 0;
    for (const [wh, qty] of Object.entries(p.qty)) {
      const qtyMilli = Math.round(qty * 1000);
      total += qtyMilli;
      const levelId = `${p.id}_${wh}`;
      set(col('stock_levels', levelId), base({ productId: p.id, warehouseId: wh, qtyMilli, lastTxId: OPEN_STOCK_TX }));
      set(col('stock_movements', `${OPEN_STOCK_TX}_${levelId}`), base({
        txId: OPEN_STOCK_TX, productId: p.id, warehouseId: wh, deltaMilli: qtyMilli, type: 'opening',
        unitCostMinor: p.buy, refType: 'opening', refId: OPEN_STOCK_TX, date: TODAY, createdBy: 'uid-admin', createdAt: now,
      }));
    }
    set(col('products', p.id), base({
      code: p.code, name: p.name, category: p.category, unit: p.unit, vatBp: p.vatBp, trackStock: track,
      buyPriceMinor: p.buy, sellPriceMinor: p.sell, avgCostMinor: p.buy, totalQtyMilli: total,
      minStockMilli: Math.round(p.min * 1000), barcode: '', active: true, createdAt: now, updatedAt: now,
    }));
  }
  set(col('txns', OPEN_STOCK_TX), base({ type: 'opening_stock', createdBy: 'uid-admin', createdAt: now, refs: {} }));

  for (const p of parties) {
    set(col('parties', p.id), base({ kinds: p.kinds, name: p.name, taxOffice: p.taxOffice, taxNo: p.taxNo, phone: p.phone, email: p.email, address: p.address, notes: 'DEMO', balanceMinor: 0, lastTxId: '', active: true, createdAt: now, updatedAt: now }));
  }

  let cash = 0, bank = 0;
  for (const a of accounts) {
    set(col('accounts', a.id), base({ type: a.type, name: a.name, bankName: a.bankName, iban: a.iban, currency: 'TRY', balanceMinor: a.opening, lastTxId: a.opening ? OPEN_CASH_TX : '', active: true }));
    if (a.opening) {
      set(col('account_movements', `${OPEN_CASH_TX}_${a.id}`), base({ txId: OPEN_CASH_TX, accountId: a.id, deltaMinor: a.opening, kind: 'in', refType: 'opening', refId: OPEN_CASH_TX, date: TODAY, createdAt: now }));
    }
    if (a.type === 'cash') cash += a.opening; else bank += a.opening;
  }
  set(col('txns', OPEN_CASH_TX), base({ type: 'opening_balance', createdBy: 'uid-admin', createdAt: now, refs: {} }));

  set(col('projects', project.id), base({ name: project.name, partyId: project.partyId, location: project.location, startDate: project.startDate, endDate: project.endDate, contractMinor: project.contractMinor, status: project.status, budgets: project.budgets, notes: project.notes }));
  set(col('project_stats', project.id), base({ revenueMinor: 0, costMinor: 0, collectedMinor: 0, paidOutMinor: 0, byDiscipline: {}, lastTxId: '' }));

  const expenseCats = [['material', 'Malzeme'], ['labor', 'İşçilik'], ['transport', 'Nakliye'], ['subcontractor', 'Taşeron'], ['fuel', 'Yakıt'], ['rent', 'Kira'], ['electricity', 'Elektrik'], ['tax', 'Vergi'], ['general', 'Genel Gider'], ['other', 'Diğer Giderler']];
  for (const [id, name] of expenseCats) set(col('expense_categories', id), base({ name, kind: 'expense', active: true }));
  const incomeCats = [['material_sales', 'Malzeme Satışı'], ['labor_income', 'İşçilik Geliri'], ['project_collection', 'Proje Tahsilatı'], ['service_income', 'Hizmet Geliri'], ['other_income', 'Diğer Gelirler']];
  for (const [id, name] of incomeCats) set(col('income_categories', id), base({ name, kind: 'income', active: true }));

  set(col('stats', 'summary'), base({ receivableMinor: 0, payableMinor: 0, cashMinor: cash, bankMinor: bank, months: {}, updatedAt: now }));

  await batch.commit();
  console.log('Seed tamam. Proje:', PROJECT, '| Sirket:', CID);
  console.log('Giris: admin@sonar.local / Test1234!  ve  calisan@sonar.local / Test1234!');
}

main().catch((e) => { console.error(e); process.exit(1); });
