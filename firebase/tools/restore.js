'use strict';
// Kullanim: node restore.js --file yedek.json[.enc] [--force] [--production --i-know-what-i-am-doing]
// Varsayilan: yalnizca EMULATORE yazar. Sifreli dosya icin BACKUP_PASSWORD.
const fs = require('fs');
const admin = require('firebase-admin');
const { SUBCOLLECTIONS, decodeValue, decrypt } = require('./lib');

function arg(name, def) {
  const i = process.argv.indexOf('--' + name);
  if (i === -1) return def;
  const next = process.argv[i + 1];
  return !next || next.startsWith('--') ? true : next;
}

async function main() {
  const file = arg('file');
  if (!file || file === true) { console.error('--file gerekli'); process.exit(1); }

  const isEmu = !!process.env.FIRESTORE_EMULATOR_HOST;
  if (!isEmu && !(arg('production', false) && arg('i-know-what-i-am-doing', false))) {
    console.error('Emulator ortam degiskeni yok. Gercek projeye yazmak icin: --production --i-know-what-i-am-doing');
    process.exit(1);
  }

  let buf = fs.readFileSync(file);
  if (buf.subarray(0, 7).toString() === 'SNRENC1') {
    if (!process.env.BACKUP_PASSWORD) { console.error('Sifreli yedek: BACKUP_PASSWORD gerekli'); process.exit(1); }
    buf = decrypt(buf, process.env.BACKUP_PASSWORD);
  }
  const bk = JSON.parse(buf.toString());
  if (bk.format !== 'sonar-backup') { console.error('Gecersiz yedek dosyasi'); process.exit(1); }
  const cid = bk.companyId;

  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'demo-sonar-finance' });
  const db = admin.firestore();

  const exists = await db.doc(`companies/${cid}`).get();
  if (exists.exists && !arg('force', false)) {
    console.error(`Hedefte companies/${cid} zaten var. Uzerine yazmak icin --force kullanin.`);
    process.exit(1);
  }

  let writer = db.bulkWriter();
  let n = 0;
  const put = (path, data) => { writer.set(db.doc(path), decodeValue(data)); n++; };

  put(`companies/${cid}`, bk.company);
  for (const u of bk.users || []) put(`users/${u.id}`, u.data);
  for (const name of SUBCOLLECTIONS) {
    for (const d of (bk.collections[name] || [])) put(`companies/${cid}/${name}/${d.id}`, d.data);
  }
  await writer.close();
  console.log(`Geri yukleme tamam: ${n} belge. Sirket: ${cid}`);
  console.log('Sonraki adim: bakiyeleri hareket toplamlariyla dogrula (docs/06).');
}
main().catch((e) => { console.error(e); process.exit(1); });
