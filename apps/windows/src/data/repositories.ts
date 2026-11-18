import {
  collection, doc, orderBy, query, limit, where, setDoc, updateDoc, writeBatch, serverTimestamp,
  type DocumentData, type Query,
} from 'firebase/firestore';
import { db } from '@/core/firebase';
import { newId } from '@/core/id';
import type { PartyMaster, ProductMaster, WarehouseMaster } from './models';

const col = (cid: string, name: string) => collection(db, 'companies', cid, name);
const ref = (cid: string, name: string, id: string) => doc(db, 'companies', cid, name, id);

/** Ana veri yazımı (cari/ürün/depo): çevrimdışıyken yazma yerel kuyruğa alınır, sunucu onayı beklenmez.
 * Dönüş: true = sunucu onayladı, false = süre doldu, kuyrukta bekliyor. Kural reddi gibi gerçek hatalar fırlatılır.
 * Finansal işlemler (04) bunu KULLANMAZ; onlar runTransaction ile çevrimdışıyken reddedilir. */
export async function writeOrQueue(write: Promise<unknown>, waitMs = 6000): Promise<boolean> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<'timeout'>((resolve) => { timer = setTimeout(() => resolve('timeout'), waitMs); });
  try {
    const r = await Promise.race([write.then(() => 'ok' as const), timeout]);
    return r === 'ok';
  } finally {
    clearTimeout(timer);
  }
}

// ---- Sorgular ----
export const partiesQuery = (cid: string): Query<DocumentData> => query(col(cid, 'parties'), orderBy('name'), limit(1000));
export const productsQuery = (cid: string): Query<DocumentData> => query(col(cid, 'products'), orderBy('name'), limit(1000));
export const warehousesQuery = (cid: string): Query<DocumentData> => query(col(cid, 'warehouses'), orderBy('name'), limit(200));
export const stockLevelsQuery = (cid: string): Query<DocumentData> => query(col(cid, 'stock_levels'), limit(5000));
/** Cari ekstre: (partyId, date) index'i var (firestore.indexes.json). */
export const ledgerQuery = (cid: string, partyId: string): Query<DocumentData> =>
  query(col(cid, 'ledger_entries'), where('partyId', '==', partyId), orderBy('date', 'asc'), limit(1000));

// ---- Yazımlar ----
export const partyRepo = {
  create(cid: string, m: PartyMaster) {
    const id = newId();
    // Kural: yeni cari bakiye 0 ve lastTxId '' ile açılır.
    const p = setDoc(ref(cid, 'parties', id), {
      ...m, companyId: cid, balanceMinor: 0, lastTxId: '', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    return writeOrQueue(p).then((synced) => ({ id, synced }));
  },
  update(cid: string, id: string, m: PartyMaster) {
    return writeOrQueue(updateDoc(ref(cid, 'parties', id), { ...m, updatedAt: serverTimestamp() }));
  },
};

export const productRepo = {
  create(cid: string, m: ProductMaster) {
    const id = newId();
    const p = setDoc(ref(cid, 'products', id), {
      ...m, companyId: cid, avgCostMinor: 0, totalQtyMilli: 0, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    return writeOrQueue(p).then((synced) => ({ id, synced }));
  },
  update(cid: string, id: string, m: ProductMaster) {
    return writeOrQueue(updateDoc(ref(cid, 'products', id), { ...m, updatedAt: serverTimestamp() }));
  },
};

export const warehouseRepo = {
  /** `isDefault` true ise diğer depoların varsayılanı kaldırılır (tek batch). */
  async save(cid: string, id: string | null, m: WarehouseMaster, otherDefaultIds: string[]) {
    const wid = id ?? newId();
    const batch = writeBatch(db);
    if (id) batch.update(ref(cid, 'warehouses', id), { ...m });
    else batch.set(ref(cid, 'warehouses', wid), { ...m, companyId: cid });
    if (m.isDefault) for (const other of otherDefaultIds) if (other !== wid) batch.update(ref(cid, 'warehouses', other), { isDefault: false });
    const synced = await writeOrQueue(batch.commit());
    return { id: wid, synced };
  },
};

// ---- Faturalar (index: type+issueDate, status+issueDate) ----
export type InvoiceTab = 'all' | 'sales' | 'purchase' | 'returns' | 'drafts';
export function invoicesQuery(cid: string, tab: InvoiceTab, max: number): Query<DocumentData> {
  const c = col(cid, 'invoices');
  switch (tab) {
    case 'sales': return query(c, where('type', '==', 'sales'), orderBy('issueDate', 'desc'), limit(max));
    case 'purchase': return query(c, where('type', '==', 'purchase'), orderBy('issueDate', 'desc'), limit(max));
    case 'returns': return query(c, where('type', 'in', ['sales_return', 'purchase_return']), orderBy('issueDate', 'desc'), limit(max));
    case 'drafts': return query(c, where('status', '==', 'draft'), orderBy('issueDate', 'desc'), limit(max));
    default: return query(c, orderBy('issueDate', 'desc'), limit(max));
  }
}
export const invoiceRef = (cid: string, id: string) => ref(cid, 'invoices', id);

/** Son stok hareketleri (tek alan sıralama: ek index gerekmez). */
export const stockMovementsQuery = (cid: string, max: number): Query<DocumentData> =>
  query(col(cid, 'stock_movements'), orderBy('date', 'desc'), limit(max));

// ---- Kasa/banka, tahsilat/ödeme ----
export const accountsQuery = (cid: string): Query<DocumentData> => query(col(cid, 'accounts'), orderBy('name'), limit(200));
/** Index: accountId + date desc. */
export const accountMovementsQuery = (cid: string, accountId: string, max: number): Query<DocumentData> =>
  query(col(cid, 'account_movements'), where('accountId', '==', accountId), orderBy('date', 'desc'), limit(max));
export const paymentsQuery = (cid: string, max: number): Query<DocumentData> => query(col(cid, 'payments'), orderBy('date', 'desc'), limit(max));
/** Index: partyId + date desc. */
export const partyPaymentsQuery = (cid: string, partyId: string): Query<DocumentData> =>
  query(col(cid, 'payments'), where('partyId', '==', partyId), orderBy('date', 'desc'), limit(200));
/** Index: partyId + issueDate desc. */
export const partyInvoicesQuery = (cid: string, partyId: string): Query<DocumentData> =>
  query(col(cid, 'invoices'), where('partyId', '==', partyId), orderBy('issueDate', 'desc'), limit(300));

// ---- Gider, proje ----
export const expensesQuery = (cid: string, max: number): Query<DocumentData> => query(col(cid, 'expenses'), orderBy('date', 'desc'), limit(max));
export const projectsQuery = (cid: string): Query<DocumentData> => query(col(cid, 'projects'), orderBy('name'), limit(300));
export const projectStatsQuery = (cid: string): Query<DocumentData> => query(col(cid, 'project_stats'), limit(300));
export const statsRef = (cid: string) => ref(cid, 'stats', 'summary');
/** Index: projectId + issueDate desc. */
export const projectInvoicesQuery = (cid: string, projectId: string): Query<DocumentData> =>
  query(col(cid, 'invoices'), where('projectId', '==', projectId), orderBy('issueDate', 'desc'), limit(300));

export const projectRepo = {
  async save(cid: string, id: string | null, m: Record<string, unknown>): Promise<{ id: string; synced: boolean }> {
    const pid = id ?? newId();
    const write = id
      ? updateDoc(ref(cid, 'projects', pid), { ...m, updatedAt: serverTimestamp() })
      : (async () => {
        const b = writeBatch(db);
        b.set(ref(cid, 'projects', pid), { companyId: cid, ...m, createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
        b.set(ref(cid, 'project_stats', pid), { companyId: cid, revenueMinor: 0, costMinor: 0, collectedMinor: 0, paidOutMinor: 0, byDiscipline: {}, lastTxId: '' });
        await b.commit();
      })();
    return { id: pid, synced: await writeOrQueue(write) };
  },
};

// ---- Genel Bakış listeleri (docs/08 §3) ----
const recent = (cid: string, coll: string) => query(col(cid, coll), orderBy('createdAt', 'desc'), limit(20));
export const recentInvoicesQuery = (cid: string) => recent(cid, 'invoices');
export const recentPaymentsQuery = (cid: string) => recent(cid, 'payments');
export const recentExpensesQuery = (cid: string) => recent(cid, 'expenses');
/** Index: paymentStatus + dueDate. */
export const dueInvoicesQuery = (cid: string): Query<DocumentData> =>
  query(col(cid, 'invoices'), where('paymentStatus', 'in', ['unpaid', 'partial']), orderBy('dueDate', 'asc'), limit(100));
