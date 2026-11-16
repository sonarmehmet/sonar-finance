'use strict';
// Kullanim: node export.js --company sonar [--out dosya.json] [--encrypt]
// Parola icin ortam degiskeni: BACKUP_PASSWORD. Emulator icin FIRESTORE_EMULATOR_HOST ayarlayin.
// Gercek proje icin GOOGLE_APPLICATION_CREDENTIALS (servis hesabi) gerekir; bu anahtari ASLA istemci uygulamasina koymayin.
const fs = require('fs');
const admin = require('firebase-admin');
const { SUBCOLLECTIONS, encodeValue, encrypt } = require('./lib');

function arg(name, def) {
  const i = process.argv.indexOf('--' + name);
  if (i === -1) return def;
  const next = process.argv[i + 1];
  return !next || next.startsWith('--') ? true : next;
}

async function main() {
  const cid = arg('company');
  if (!cid || cid === true) { console.error('--company <id> gerekli'); process.exit(1); }
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'demo-sonar-finance' });
  const db = admin.firestore();

  const out = { format: 'sonar-backup', version: 1, createdAt: new Date().toISOString(), companyId: cid, counts: {}, company: null, users: [], collections: {} };

  const comp = await db.doc(`companies/${cid}`).get();
  if (!comp.exists) { console.error('Sirket bulunamadi: ' + cid); process.exit(1); }
  out.company = encodeValue(comp.data());

  const users = await db.collection('users').where('companyId', '==', cid).get();
  out.users = users.docs.map((d) => ({ id: d.id, data: encodeValue(d.data()) }));
  out.counts.users = out.users.length;

  for (const name of SUBCOLLECTIONS) {
    const docs = [];
    let last = null;
    for (;;) {
      let q = db.collection(`companies/${cid}/${name}`).orderBy(admin.firestore.FieldPath.documentId()).limit(500);
      if (last) q = q.startAfter(last);
      const snap = await q.get();
      if (snap.empty) break;
      snap.docs.forEach((d) => docs.push({ id: d.id, data: encodeValue(d.data()) }));
      last = snap.docs[snap.docs.length - 1];
      if (snap.size < 500) break;
    }
    out.collections[name] = docs;
    out.counts[name] = docs.length;
  }

  const stamp = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 12);
  let file = arg('out', `sonar-backup-${stamp}.json`);
  let data = Buffer.from(JSON.stringify(out));
  if (arg('encrypt', false)) {
    const pw = process.env.BACKUP_PASSWORD;
    if (!pw) { console.error('--encrypt icin BACKUP_PASSWORD ortam degiskeni gerekli'); process.exit(1); }
    data = encrypt(data, pw);
    if (!file.endsWith('.enc')) file += '.enc';
  }
  fs.writeFileSync(file, data);
  console.log('Yedek yazildi:', file);
  console.log(JSON.stringify(out.counts));
}
main().catch((e) => { console.error(e); process.exit(1); });
