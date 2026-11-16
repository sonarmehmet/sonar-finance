'use strict';
const admin = require('firebase-admin');
const crypto = require('crypto');

const SUBCOLLECTIONS = [
  'parties', 'products', 'warehouses', 'stock_levels', 'stock_movements', 'invoices', 'payments',
  'accounts', 'account_movements', 'ledger_entries', 'expenses', 'expense_categories', 'income_categories',
  'projects', 'project_stats', 'stats', 'counters', 'txns', 'audit_logs',
];

// Timestamp <-> JSON
function encodeValue(v) {
  if (v instanceof admin.firestore.Timestamp) return { __ts: { s: v.seconds, n: v.nanoseconds } };
  if (Array.isArray(v)) return v.map(encodeValue);
  if (v && typeof v === 'object') {
    const o = {};
    for (const k of Object.keys(v)) o[k] = encodeValue(v[k]);
    return o;
  }
  return v;
}
function decodeValue(v) {
  if (Array.isArray(v)) return v.map(decodeValue);
  if (v && typeof v === 'object') {
    if (v.__ts && typeof v.__ts.s === 'number') return new admin.firestore.Timestamp(v.__ts.s, v.__ts.n || 0);
    const o = {};
    for (const k of Object.keys(v)) o[k] = decodeValue(v[k]);
    return o;
  }
  return v;
}

// AES-256-GCM, anahtar scrypt ile paroladan turetilir
function encrypt(buf, password) {
  const salt = crypto.randomBytes(16);
  const iv = crypto.randomBytes(12);
  const key = crypto.scryptSync(password, salt, 32);
  const c = crypto.createCipheriv('aes-256-gcm', key, iv);
  const enc = Buffer.concat([c.update(buf), c.final()]);
  const tag = c.getAuthTag();
  return Buffer.concat([Buffer.from('SNRENC1'), salt, iv, tag, enc]);
}
function decrypt(buf, password) {
  const magic = buf.subarray(0, 7).toString();
  if (magic !== 'SNRENC1') throw new Error('Sifreli yedek bicimi taninmadi');
  const salt = buf.subarray(7, 23);
  const iv = buf.subarray(23, 35);
  const tag = buf.subarray(35, 51);
  const data = buf.subarray(51);
  const key = crypto.scryptSync(password, salt, 32);
  const d = crypto.createDecipheriv('aes-256-gcm', key, iv);
  d.setAuthTag(tag);
  return Buffer.concat([d.update(data), d.final()]);
}

module.exports = { SUBCOLLECTIONS, encodeValue, decodeValue, encrypt, decrypt };
