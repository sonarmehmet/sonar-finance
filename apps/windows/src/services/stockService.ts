/** Manuel stok işlemleri — docs/04 §7. Android `stock_service.dart` ile aynı davranış.
 * Hepsi tek runTransaction, txId ile idempotent, yalnız çevrimiçi; yetki `stock.write`.
 * Eşleme: giriş → `opening` (+, ağırlıklı ortalama maliyet); çıkış → `adjust` (−, neden zorunlu);
 * sayım → `adjust` (sayılan − mevcut, neden zorunlu); transfer → `transfer_out` + `transfer_in` (maliyet değişmez). */
import { doc, runTransaction, serverTimestamp, type DocumentData, type DocumentReference } from 'firebase/firestore';
import { db } from '@/core/firebase';
import { todayIso, formatMilli } from '@/core/money';
import { weightedAverageCost } from '@/core/calc/invoiceCalculator';
import { TxError } from './txErrors';

export interface StockCtx { companyId: string; uid: string; can(p: 'stock.write'): boolean }

const int = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? Math.trunc(v) : 0);
const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const ref = (cid: string, coll: string, id: string): DocumentReference<DocumentData> => doc(db, 'companies', cid, coll, id);
const levelId = (p: string, w: string) => `${p}_${w}`;

function guard(ctx: StockCtx): void {
  if (!ctx.can('stock.write')) throw new TxError('noPermission');
  if (typeof navigator !== 'undefined' && !navigator.onLine) throw new TxError('offline');
}
const needReason = (r: string) => { if (!r.trim()) throw new TxError('reasonRequired'); };

async function withAbortRetry<T>(run: () => Promise<T>): Promise<T> {
  const delays = [300, 900, 2700];
  for (let i = 0; ; i++) {
    try { return await run(); } catch (e) {
      if ((e as { code?: string }).code !== 'aborted' || i >= delays.length) throw e;
      await new Promise((r) => setTimeout(r, delays[i]));
    }
  }
}

interface SingleOpts {
  txId: string; txType: string; productId: string; warehouseId: string; movementType: string;
  resolveDelta(current: number): number; unitCostMinor?: number; applyAvgCost?: boolean; note?: string;
}

async function single(ctx: StockCtx, o: SingleOpts): Promise<void> {
  guard(ctx);
  const cid = ctx.companyId, date = todayIso(), note = (o.note ?? '').trim();
  await withAbortRetry(() => runTransaction(db, async (tx) => {
    const txRef = ref(cid, 'txns', o.txId);
    if ((await tx.get(txRef)).exists()) throw new TxError('alreadyProcessed');
    const allowNegative = ((((await tx.get(doc(db, 'companies', cid))).data()?.settings) ?? {}) as Record<string, unknown>).allowNegativeStock === true;
    const pRef = ref(cid, 'products', o.productId);
    const pSnap = await tx.get(pRef);
    if (!pSnap.exists()) throw new TxError('productNotFound', { id: o.productId });
    const p = pSnap.data() as DocumentData;
    const pName = str(p.name);
    if (p.trackStock === false) throw new TxError('stockNotTracked', { product: pName });
    const whSnap = await tx.get(ref(cid, 'warehouses', o.warehouseId));
    if (!whSnap.exists()) throw new TxError('warehouseNotFound');
    const lid = levelId(o.productId, o.warehouseId);
    const lRef = ref(cid, 'stock_levels', lid);
    const lSnap = await tx.get(lRef);
    const cur = int(lSnap.data()?.qtyMilli);
    const delta = o.resolveDelta(cur);
    const newQty = cur + delta;
    if (delta < 0 && newQty < 0 && !allowNegative) {
      throw new TxError('insufficientStock', { product: pName, warehouse: str(whSnap.data()?.name), qty: formatMilli(cur < 0 ? 0 : cur) });
    }
    // ---- yazmalar ----
    if (lSnap.exists()) tx.update(lRef, { qtyMilli: newQty, lastTxId: o.txId });
    else tx.set(lRef, { companyId: cid, productId: o.productId, warehouseId: o.warehouseId, qtyMilli: newQty, lastTxId: o.txId });
    const cost = o.unitCostMinor ?? int(p.avgCostMinor);
    tx.set(ref(cid, 'stock_movements', `${o.txId}_${lid}`), {
      companyId: cid, txId: o.txId, productId: o.productId, warehouseId: o.warehouseId, deltaMilli: delta, type: o.movementType,
      unitCostMinor: cost, refType: 'manual', refId: '', note, date, createdBy: ctx.uid, createdAt: serverTimestamp(),
    });
    const upd: Record<string, unknown> = { totalQtyMilli: int(p.totalQtyMilli) + delta, updatedAt: serverTimestamp() };
    if (o.applyAvgCost) {
      upd.avgCostMinor = weightedAverageCost({ oldQtyMilli: int(p.totalQtyMilli), oldAvgMinor: int(p.avgCostMinor), inQtyMilli: delta, unitCostMinor: cost });
    }
    tx.update(pRef, upd);
    writeAudit(tx, cid, ctx.uid, o.txId, o.txType, o.productId, pName, delta, note);
  }));
}

function writeAudit(tx: { set(r: DocumentReference<DocumentData>, d: DocumentData): unknown }, cid: string, uid: string, txId: string,
  txType: string, productId: string, name: string, delta: number, note: string): void {
  tx.set(ref(cid, 'txns', txId), { companyId: cid, type: txType, createdBy: uid, createdAt: serverTimestamp(), refs: { productId } });
  tx.set(ref(cid, 'audit_logs', `a_${txId}`), {
    companyId: cid, action: `stock.${txType}`, entityType: 'product', entityId: productId, userId: uid, at: serverTimestamp(),
    summary: `${name} ${delta > 0 ? '+' : ''}${formatMilli(delta)}${note ? ` · ${note}` : ''}`,
  });
}

export function stockIn(ctx: StockCtx, p: { txId: string; productId: string; warehouseId: string; qtyMilli: number; unitCostMinor: number; note?: string }) {
  if (p.qtyMilli <= 0) throw new TxError('invalidQty');
  if (p.unitCostMinor < 0) throw new TxError('invalidAmount');
  return single(ctx, { ...p, txType: 'stock_in', movementType: 'opening', resolveDelta: () => p.qtyMilli, applyAvgCost: true });
}

export function stockOut(ctx: StockCtx, p: { txId: string; productId: string; warehouseId: string; qtyMilli: number; reason: string }) {
  needReason(p.reason);
  if (p.qtyMilli <= 0) throw new TxError('invalidQty');
  return single(ctx, { ...p, txType: 'stock_out', movementType: 'adjust', resolveDelta: () => -p.qtyMilli, note: p.reason });
}

export function stockCount(ctx: StockCtx, p: { txId: string; productId: string; warehouseId: string; countedMilli: number; reason: string }) {
  needReason(p.reason);
  if (p.countedMilli < 0) throw new TxError('invalidQty');
  return single(ctx, {
    ...p, txType: 'stock_adjust', movementType: 'adjust', note: p.reason,
    resolveDelta: (cur) => { const d = p.countedMilli - cur; if (d === 0) throw new TxError('noChange'); return d; },
  });
}

export async function stockTransfer(ctx: StockCtx, p: { txId: string; productId: string; fromWarehouseId: string; toWarehouseId: string; qtyMilli: number; note?: string }): Promise<void> {
  guard(ctx);
  if (p.qtyMilli <= 0) throw new TxError('invalidQty');
  if (p.fromWarehouseId === p.toWarehouseId) throw new TxError('sameWarehouse');
  const cid = ctx.companyId, date = todayIso(), note = (p.note ?? '').trim();
  await withAbortRetry(() => runTransaction(db, async (tx) => {
    const txRef = ref(cid, 'txns', p.txId);
    if ((await tx.get(txRef)).exists()) throw new TxError('alreadyProcessed');
    const allowNegative = ((((await tx.get(doc(db, 'companies', cid))).data()?.settings) ?? {}) as Record<string, unknown>).allowNegativeStock === true;
    const pSnap = await tx.get(ref(cid, 'products', p.productId));
    if (!pSnap.exists()) throw new TxError('productNotFound', { id: p.productId });
    const prod = pSnap.data() as DocumentData;
    if (prod.trackStock === false) throw new TxError('stockNotTracked', { product: str(prod.name) });
    const fromWh = await tx.get(ref(cid, 'warehouses', p.fromWarehouseId));
    const toWh = await tx.get(ref(cid, 'warehouses', p.toWarehouseId));
    if (!fromWh.exists() || !toWh.exists()) throw new TxError('warehouseNotFound');
    const fromId = levelId(p.productId, p.fromWarehouseId), toId = levelId(p.productId, p.toWarehouseId);
    const fromRef = ref(cid, 'stock_levels', fromId), toRef = ref(cid, 'stock_levels', toId);
    const fromSnap = await tx.get(fromRef), toSnap = await tx.get(toRef);
    const fromCur = int(fromSnap.data()?.qtyMilli), toCur = int(toSnap.data()?.qtyMilli);
    if (!allowNegative && fromCur - p.qtyMilli < 0) {
      throw new TxError('insufficientStock', { product: str(prod.name), warehouse: str(fromWh.data()?.name), qty: formatMilli(fromCur < 0 ? 0 : fromCur) });
    }
    const writeLevel = (r: DocumentReference<DocumentData>, exists: boolean, wh: string, qty: number) => {
      if (exists) tx.update(r, { qtyMilli: qty, lastTxId: p.txId });
      else tx.set(r, { companyId: cid, productId: p.productId, warehouseId: wh, qtyMilli: qty, lastTxId: p.txId });
    };
    const writeMove = (lid: string, wh: string, delta: number, type: string) => tx.set(ref(cid, 'stock_movements', `${p.txId}_${lid}`), {
      companyId: cid, txId: p.txId, productId: p.productId, warehouseId: wh, deltaMilli: delta, type, unitCostMinor: int(prod.avgCostMinor),
      refType: 'manual', refId: '', note, date, createdBy: ctx.uid, createdAt: serverTimestamp(),
    });
    writeLevel(fromRef, fromSnap.exists(), p.fromWarehouseId, fromCur - p.qtyMilli);
    writeLevel(toRef, toSnap.exists(), p.toWarehouseId, toCur + p.qtyMilli);
    writeMove(fromId, p.fromWarehouseId, -p.qtyMilli, 'transfer_out');
    writeMove(toId, p.toWarehouseId, p.qtyMilli, 'transfer_in');
    writeAudit(tx, cid, ctx.uid, p.txId, 'stock_transfer', p.productId, str(prod.name), p.qtyMilli, note);
  }));
}
