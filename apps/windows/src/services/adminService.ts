/** Yönetici işlemleri: kullanıcı yönetimi, şirket ayarları, yedek (JSON), salt-okunur tutarlılık denetimi (docs/06, docs/08 §7). */
import { deleteApp, initializeApp } from 'firebase/app';
import { connectAuthEmulator, createUserWithEmailAndPassword, getAuth, signOut as signOutAuth } from 'firebase/auth';
import { collection, doc, getDocs, getDoc, serverTimestamp, setDoc, updateDoc, query, where, type DocumentData } from 'firebase/firestore';
import { db, firebaseConfig, isEmulator } from '@/core/firebase';
import { newId } from '@/core/id';
import type { Permission, Role } from '@/core/types';
import { writeOrQueue } from '@/data/repositories';
import { TxError } from './txErrors';

export interface AdminCtx { companyId: string; uid: string; isAdmin: boolean }
const guard = (c: AdminCtx) => { if (!c.isAdmin) throw new TxError('noPermission'); };

// ----------------------------------------------------------------- kullanıcılar

export interface UserInput { displayName: string; email: string; role: Role; permissions: Partial<Record<Permission, boolean>>; active: boolean }
export interface UserRow extends UserInput { uid: string }

export async function listUsers(c: AdminCtx): Promise<UserRow[]> {
  guard(c);
  const snap = await getDocs(query(collection(db, 'users'), where('companyId', '==', c.companyId)));
  return snap.docs.map((d): UserRow => { const x = d.data(); return { uid: d.id, displayName: String(x.displayName ?? ''), email: String(x.email ?? ''), role: x.role === 'admin' ? 'admin' : 'employee', permissions: (x.permissions ?? {}) as UserRow['permissions'], active: x.active !== false }; })
    .sort((a, b) => a.displayName.localeCompare(b.displayName, 'tr'));
}

/** İkinci (geçici) Firebase uygulamasıyla Auth kullanıcısı açar: yönetici oturumu kapanmaz. */
export async function createUser(c: AdminCtx, u: UserInput, password: string): Promise<string> {
  guard(c);
  if (password.length < 6) throw new TxError('weakPassword');
  const app2 = initializeApp(firebaseConfig, `secondary-${newId()}`);
  try {
    const auth2 = getAuth(app2);
    if (isEmulator) connectAuthEmulator(auth2, 'http://127.0.0.1:9099', { disableWarnings: true });
    const cred = await createUserWithEmailAndPassword(auth2, u.email.trim(), password);
    await signOutAuth(auth2);
    await setDoc(doc(db, 'users', cred.user.uid), { companyId: c.companyId, displayName: u.displayName.trim(), email: u.email.trim(), role: u.role, permissions: u.permissions, active: u.active, createdAt: serverTimestamp() });
    await setDoc(doc(db, 'companies', c.companyId, 'audit_logs', newId()), { companyId: c.companyId, action: 'user.create', entityType: 'user', entityId: cred.user.uid, userId: c.uid, at: serverTimestamp(), summary: u.email.trim() });
    return cred.user.uid;
  } finally { await deleteApp(app2); }
}

export async function updateUser(c: AdminCtx, uid: string, u: Omit<UserInput, 'email'>): Promise<void> {
  guard(c);
  if (uid === c.uid && (!u.active || u.role !== 'admin')) throw new TxError('selfLockout');
  await updateDoc(doc(db, 'users', uid), { displayName: u.displayName.trim(), role: u.role, permissions: u.permissions, active: u.active });
}

// ------------------------------------------------------------------ ayarlar

export interface SettingsInput {
  name: string; taxNo: string; taxOffice: string; address: string; phone: string;
  allowNegativeStock: boolean; defaultVatBp: number; prefixes: { sales: string; purchase: string; sales_return: string; purchase_return: string };
}
export function saveSettings(c: AdminCtx, s: SettingsInput): Promise<boolean> {
  guard(c);
  return writeOrQueue(updateDoc(doc(db, 'companies', c.companyId), {
    name: s.name.trim(), taxNo: s.taxNo.trim(), taxOffice: s.taxOffice.trim(), address: s.address.trim(), phone: s.phone.trim(),
    'settings.allowNegativeStock': s.allowNegativeStock, 'settings.defaultVatBp': s.defaultVatBp,
    'settings.invoicePrefix.sales': s.prefixes.sales.trim() || 'SF', 'settings.invoicePrefix.purchase': s.prefixes.purchase.trim() || 'AF',
    'settings.invoicePrefix.sales_return': s.prefixes.sales_return.trim() || 'SI', 'settings.invoicePrefix.purchase_return': s.prefixes.purchase_return.trim() || 'AI',
  }));
}

// -------------------------------------------------------------------- yedek

const COLLECTIONS = ['parties', 'products', 'warehouses', 'stock_levels', 'stock_movements', 'invoices', 'payments', 'accounts', 'account_movements', 'ledger_entries',
  'expenses', 'expense_categories', 'income_categories', 'projects', 'project_stats', 'stats', 'counters', 'txns', 'audit_logs'];

/** Timestamp → {"__ts":{"s","n"}} (docs/06); diğer değerler düz JSON. */
function ser(v: unknown): unknown {
  if (v && typeof v === 'object') {
    const o = v as { seconds?: number; nanoseconds?: number; toMillis?: unknown };
    if (typeof o.toMillis === 'function' && typeof o.seconds === 'number') return { __ts: { s: o.seconds, n: o.nanoseconds ?? 0 } };
    if (Array.isArray(v)) return v.map(ser);
    return Object.fromEntries(Object.entries(v as Record<string, unknown>).map(([k, x]) => [k, ser(x)]));
  }
  return v;
}

export async function exportBackup(c: AdminCtx, onProgress?: (name: string) => void): Promise<{ filename: string; docs: number }> {
  guard(c);
  const out: Record<string, unknown> = { format: 'sonar-backup', version: 1, companyId: c.companyId, createdAt: new Date().toISOString(), data: {} as Record<string, unknown> };
  const data = out.data as Record<string, Record<string, unknown>>;
  let docs = 0;
  const comp = await getDoc(doc(db, 'companies', c.companyId));
  data.company = { [c.companyId]: ser(comp.data()) };
  for (const name of COLLECTIONS) {
    onProgress?.(name);
    const snap = await getDocs(collection(db, 'companies', c.companyId, name));
    data[name] = Object.fromEntries(snap.docs.map((d) => [d.id, ser(d.data())]));
    docs += snap.size;
  }
  const users = await getDocs(query(collection(db, 'users'), where('companyId', '==', c.companyId)));
  data.users = Object.fromEntries(users.docs.map((d) => [d.id, ser(d.data())]));
  docs += users.size;
  const d = new Date(), p = (n: number) => String(n).padStart(2, '0');
  const filename = `sonar-backup-${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}.json`;
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([JSON.stringify(out)], { type: 'application/json' }));
  a.download = filename; document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 10000);
  await setDoc(doc(db, 'companies', c.companyId, 'audit_logs', newId()), { companyId: c.companyId, action: 'backup.export', entityType: 'company', entityId: c.companyId, userId: c.uid, at: serverTimestamp(), summary: `${filename} · ${docs}` });
  try { const k = 'sonar.backups'; const l = JSON.parse(localStorage.getItem(k) ?? '[]') as string[]; localStorage.setItem(k, JSON.stringify([`${new Date().toISOString()} ${filename}`, ...l].slice(0, 20))); } catch { /* yerel geçmiş isteğe bağlı */ }
  return { filename, docs };
}

export function backupHistory(): string[] {
  try { return JSON.parse(localStorage.getItem('sonar.backups') ?? '[]') as string[]; } catch { return []; }
}

// --------------------------------------------------------- tutarlılık denetimi

export interface Diff { kind: string; id: string; label: string; stored: number; computed: number }

/** docs/08 §7: salt-okunur. Düzeltme `firebase/tools/recalc.js --fix` ile yapılır. */
export async function checkConsistency(c: AdminCtx, onProgress?: (n: string) => void): Promise<Diff[]> {
  guard(c);
  const read = async (n: string): Promise<{ id: string; x: DocumentData }[]> => { onProgress?.(n); return (await getDocs(collection(db, 'companies', c.companyId, n))).docs.map((d) => ({ id: d.id, x: d.data() })); };
  const sumBy = (rows: { x: DocumentData }[], key: string, f: string) => { const m = new Map<string, number>(); for (const r of rows) m.set(String(r.x[key]), (m.get(String(r.x[key])) ?? 0) + (Number(r.x[f]) || 0)); return m; };
  const diffs: Diff[] = [];
  const cmp = (kind: string, items: { id: string; x: DocumentData }[], field: string, sums: Map<string, number>, label: string) => {
    for (const it of items) { const stored = Number(it.x[field]) || 0, computed = sums.get(it.id) ?? 0; if (stored !== computed) diffs.push({ kind, id: it.id, label: String(it.x[label] ?? it.id), stored, computed }); }
  };
  const [parties, ledger, accounts, am, levels, sm, products, invoices, payments] = await Promise.all(['parties', 'ledger_entries', 'accounts', 'account_movements', 'stock_levels', 'stock_movements', 'products', 'invoices', 'payments'].map(read));
  cmp('party', parties, 'balanceMinor', sumBy(ledger, 'partyId', 'deltaMinor'), 'name');
  cmp('account', accounts, 'balanceMinor', sumBy(am, 'accountId', 'deltaMinor'), 'name');
  const lvSum = new Map<string, number>(); for (const m of sm) { const k = `${m.x.productId}_${m.x.warehouseId}`; lvSum.set(k, (lvSum.get(k) ?? 0) + (Number(m.x.deltaMilli) || 0)); }
  cmp('stockLevel', levels, 'qtyMilli', lvSum, 'productId');
  cmp('productTotal', products, 'totalQtyMilli', sumBy(levels, 'productId', 'qtyMilli'), 'name');
  const paid = new Map<string, number>();
  for (const p of payments) if (p.x.status === 'active') for (const a of (p.x.allocations ?? []) as { invoiceId: string; amountMinor: number }[]) paid.set(a.invoiceId, (paid.get(a.invoiceId) ?? 0) + a.amountMinor);
  cmp('invoicePaid', invoices.filter((i) => i.x.status === 'issued'), 'paidMinor', paid, 'number');
  return diffs;
}
