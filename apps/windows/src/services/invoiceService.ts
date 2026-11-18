/** Fatura işlemleri — docs/04 §3 (kes), §4 (iptal). Android `invoice_service.dart` ile aynı davranış.
 * UI doğrudan Firestore'a yazmaz (docs/01). Kes/iptal: TEK runTransaction, önce tüm okumalar sonra yazmalar.
 * Çevrimdışıyken kesinleştirme yapılmaz (CONTRACTS kural 5): yalnız taslak kaydedilir. */
import {
  deleteDoc, deleteField, doc, increment, runTransaction, serverTimestamp, setDoc, updateDoc,
  type DocumentData, type DocumentReference, type DocumentSnapshot,
} from 'firebase/firestore';
import { db } from '@/core/firebase';
import { newId } from '@/core/id';
import { monthKey, parseIsoDate, yearOf } from '@/core/dates';
import { formatMilli, formatMinorTry, todayIso } from '@/core/money';
import {
  calculateLine, calculateTotals, unitCostMinorFromTaxable, type InvoiceTotals, type LineAmounts,
} from '@/core/calc/invoiceCalculator';
import {
  balanceSign, defaultPrefix, invoiceFromData, lineInput, lineToMap, stockMovementTypeFor, stockSign,
  type InvoiceDraft, type InvoiceLine, type InvoiceType,
} from '@/data/invoice';
import { writeOrQueue } from '@/data/repositories';
import { planStock, newAverageCostForPurchase } from './stockPlan';
import { buildProjectStatsWrite, buildSummaryWrite, partyContribution } from './statsHelpers';
import { TxError } from './txErrors';

export interface ServiceCtx {
  companyId: string;
  uid: string;
  can(permission: 'invoice.write'): boolean;
}

export interface ComputedInvoice { lines: InvoiceLine[]; amounts: LineAmounts[]; totals: InvoiceTotals }
export interface IssueResult { invoiceId: string; number: string }

const ref = (cid: string, coll: string, id: string): DocumentReference<DocumentData> => doc(db, 'companies', cid, coll, id);
const int = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? Math.trunc(v) : 0);
const str = (v: unknown): string => (typeof v === 'string' ? v : '');

function requirePermission(ctx: ServiceCtx): void {
  if (!ctx.can('invoice.write')) throw new TxError('noPermission');
}

/** Girdiyi doğrular ve tutarları YENİDEN hesaplar. İstemci değeri değil HESAPLANAN yazılır (04 §3). */
export function computeInvoice(d: InvoiceDraft, requireLines: boolean): ComputedInvoice {
  if (!d.partyId) throw new TxError('partyRequired');
  if (!parseIsoDate(d.issueDate) || !parseIsoDate(d.dueDate) || d.dueDate < d.issueDate) throw new TxError('invalidDates');
  if (requireLines && d.lines.length === 0) throw new TxError('noLines');

  const amounts: LineAmounts[] = [];
  const lines: InvoiceLine[] = [];
  for (const l of d.lines) {
    if (!l.description.trim() || l.qtyMilli <= 0 || l.unitPriceMinor < 0 || l.discountBp < 0 || l.discountBp > 10000 || l.vatBp < 0) {
      throw new TxError('invalidLine');
    }
    const a = calculateLine(lineInput(l), d.priceIncludesVat);
    amounts.push(a);
    lines.push({ ...l, netMinor: a.netMinor, discountMinor: a.discountMinor, vatMinor: a.vatMinor, totalMinor: a.totalMinor });
  }
  return { lines, amounts, totals: calculateTotals(amounts) };
}

// ---------------------------------------------------------------- taslak

/** Taslak kaydet (çevrimdışı da çalışır: yazma yerel kuyruğa alınır). */
export async function saveDraft(ctx: ServiceCtx, d: InvoiceDraft): Promise<{ id: string; synced: boolean }> {
  requirePermission(ctx);
  const c = computeInvoice(d, false);
  const id = d.id ?? newId();
  const r = ref(ctx.companyId, 'invoices', id);
  const data: Record<string, unknown> = {
    companyId: ctx.companyId, type: d.type, status: 'draft', partyId: d.partyId, partyName: d.partyName,
    issueDate: d.issueDate, dueDate: d.dueDate, currency: 'TRY', priceIncludesVat: d.priceIncludesVat, note: d.note,
    lines: c.lines.map(lineToMap), subtotalMinor: c.totals.subtotalMinor, discountMinor: c.totals.discountMinor,
    vatMinor: c.totals.vatMinor, totalMinor: c.totals.totalMinor, paidMinor: 0, paymentStatus: 'none', lastTxId: '',
    updatedAt: serverTimestamp(),
  };
  let write: Promise<void>;
  if (!d.id) {
    write = setDoc(r, {
      ...data, ...(d.projectId ? { projectId: d.projectId } : {}), ...(d.costCategory ? { costCategory: d.costCategory } : {}),
      rev: 1, createdBy: ctx.uid, createdAt: serverTimestamp(),
    });
  } else {
    write = updateDoc(r, {
      ...data, rev: increment(1),
      projectId: d.projectId ?? deleteField(), costCategory: d.costCategory ?? deleteField(),
    });
  }
  return { id, synced: await writeOrQueue(write) };
}

/** Yalnız taslak silinebilir (firestore.rules). */
export function deleteDraft(ctx: ServiceCtx, invoiceId: string): Promise<boolean> {
  requirePermission(ctx);
  return writeOrQueue(deleteDoc(ref(ctx.companyId, 'invoices', invoiceId)));
}

// ------------------------------------------------------------- yardımcılar

/** docs/05: `aborted` (yarış) → 3 kez üstel gecikmeyle (300/900/2700 ms), AYNI txId ile yeniden dene. */
async function withAbortRetry<T>(run: () => Promise<T>): Promise<T> {
  const delays = [300, 900, 2700];
  for (let i = 0; ; i++) {
    try {
      return await run();
    } catch (e) {
      if ((e as { code?: string }).code !== 'aborted' || i >= delays.length) throw e;
      await new Promise((r) => setTimeout(r, delays[i]));
    }
  }
}

function assertOnline(): void {
  if (typeof navigator !== 'undefined' && !navigator.onLine) throw new TxError('offline');
}

const revenueDelta = (type: InvoiceType, taxable: number): number => (type === 'sales' ? taxable : type === 'sales_return' ? -taxable : 0);
const costDelta = (type: InvoiceType, taxable: number): number => (type === 'purchase' ? taxable : type === 'purchase_return' ? -taxable : 0);

interface ProductInfo { name: string; trackStock: boolean; avgCostMinor: number; totalQtyMilli: number }
const readProduct = (s: DocumentSnapshot<DocumentData>): ProductInfo => {
  const x = s.data() ?? {};
  return { name: str(x.name), trackStock: x.trackStock !== false, avgCostMinor: int(x.avgCostMinor), totalQtyMilli: int(x.totalQtyMilli) };
};

// ------------------------------------------------------------- faturayı kes

/** docs/04 §3. `txId` form açılınca üretilir; aynı form yeniden gönderilirse AYNI txId kullanılır (çift kayıt olmaz).
 * `force`: "Benimkini koru (üzerine yaz)" seçimi; rev denetimini atlar. */
export async function issueInvoice(ctx: ServiceCtx, draft: InvoiceDraft, txId: string, force = false): Promise<IssueResult> {
  requirePermission(ctx);
  assertOnline();
  const cid = ctx.companyId;
  const c = computeInvoice(draft, true);
  const type = draft.type;
  const invoiceId = draft.id ?? newId();
  const totals = c.totals;

  return withAbortRetry(() => runTransaction(db, async (tx): Promise<IssueResult> => {
    // ======================= OKUMALAR (yazmadan önce) =====================
    const txRef = ref(cid, 'txns', txId);
    if ((await tx.get(txRef)).exists()) throw new TxError('alreadyProcessed');

    const companySnap = await tx.get(doc(db, 'companies', cid));
    const settings = (companySnap.data()?.settings ?? {}) as Record<string, unknown>;
    const allowNegative = settings.allowNegativeStock === true;
    const prefixes = (settings.invoicePrefix ?? {}) as Record<string, unknown>;

    const invRef = ref(cid, 'invoices', invoiceId);
    const invSnap = await tx.get(invRef);
    if (invSnap.exists() && str(invSnap.data()?.status) !== 'draft') throw new TxError('invalidState');
    // Taslak çakışması (docs/05): ekrandaki rev sunucudakiyle aynı olmalı.
    const serverRev = int(invSnap.data()?.rev);
    if (invSnap.exists() && !force && serverRev !== draft.rev) throw new TxError('draftChanged');

    const partyRef = ref(cid, 'parties', draft.partyId);
    const partySnap = await tx.get(partyRef);
    if (!partySnap.exists()) throw new TxError('partyNotFound');
    const partyData = partySnap.data() as DocumentData;

    const counterRef = ref(cid, 'counters', `invoice_${type}`);
    const counterSnap = await tx.get(counterRef);

    // Ürünler (satırlardaki productId'ler)
    const products = new Map<string, ProductInfo>();
    for (const id of new Set(c.lines.filter((l) => l.productId).map((l) => l.productId!))) {
      const s = await tx.get(ref(cid, 'products', id));
      if (!s.exists()) throw new TxError('productNotFound', { id });
      products.set(id, readProduct(s));
    }

    // Stok takipli satırlar → plan (aynı ürün+depo tek harekette birleşir)
    const stockLines: { line: InvoiceLine; taxableMinor: number }[] = [];
    c.lines.forEach((l, i) => {
      const prod = l.productId ? products.get(l.productId) : undefined;
      if (!prod || !prod.trackStock) return;
      if (!l.warehouseId) throw new TxError('warehouseRequired', { product: prod.name });
      stockLines.push({ line: l, taxableMinor: c.amounts[i].taxableMinor });
    });
    const plan = planStock(stockLines, stockSign(type));

    const levelSnaps = new Map<string, DocumentSnapshot<DocumentData>>();
    for (const lp of plan.levels) levelSnaps.set(lp.levelId, await tx.get(ref(cid, 'stock_levels', lp.levelId)));

    // Stok yeterliliği (allowNegativeStock=false iken çıkış stoğu aşmamalı)
    if (!allowNegative) {
      for (const lp of plan.levels.filter((e) => e.deltaMilli < 0)) {
        const cur = int(levelSnaps.get(lp.levelId)!.data()?.qtyMilli);
        if (cur + lp.deltaMilli < 0) {
          const wh = await tx.get(ref(cid, 'warehouses', lp.warehouseId));
          throw new TxError('insufficientStock', {
            product: products.get(lp.productId)!.name, warehouse: str(wh.data()?.name), qty: formatMilli(cur < 0 ? 0 : cur),
          });
        }
      }
    }

    const statsRef = ref(cid, 'stats', 'summary');
    const statsSnap = await tx.get(statsRef);

    let projRef: DocumentReference<DocumentData> | null = null;
    let projSnap: DocumentSnapshot<DocumentData> | null = null;
    if (draft.projectId) {
      projRef = ref(cid, 'project_stats', draft.projectId);
      projSnap = await tx.get(projRef);
    }

    // ============================ YAZMALAR ================================
    // Numara: counters.last += 1 → "{prefix}-{yıl}-{last 6 hane}"
    const last = int(counterSnap.data()?.last) + 1;
    const prefix = str(prefixes[type]) || defaultPrefix(type);
    const number = `${prefix}-${yearOf(draft.issueDate)}-${String(last).padStart(6, '0')}`;
    if (counterSnap.exists()) tx.update(counterRef, { last }); else tx.set(counterRef, { last });

    // Cari bakiye + ledger
    const deltaBal = balanceSign(type) * totals.totalMinor;
    const oldBal = int(partyData.balanceMinor);
    const newBal = oldBal + deltaBal;
    tx.update(partyRef, { balanceMinor: newBal, lastTxId: txId, updatedAt: serverTimestamp() });
    tx.set(ref(cid, 'ledger_entries', `${txId}_${draft.partyId}`), {
      companyId: cid, txId, partyId: draft.partyId, deltaMinor: deltaBal, refType: 'invoice', refId: invoiceId,
      description: number, date: draft.issueDate, createdAt: serverTimestamp(),
    });

    // Stok seviyeleri + hareketler + ürün toplamları
    const moveType = stockMovementTypeFor(type);
    for (const lp of plan.levels) {
      const snap = levelSnaps.get(lp.levelId)!;
      const newQty = int(snap.data()?.qtyMilli) + lp.deltaMilli;
      const levelRef = ref(cid, 'stock_levels', lp.levelId);
      if (snap.exists()) tx.update(levelRef, { qtyMilli: newQty, lastTxId: txId });
      else tx.set(levelRef, { companyId: cid, productId: lp.productId, warehouseId: lp.warehouseId, qtyMilli: newQty, lastTxId: txId });
      // Alışta birim maliyet satır tutarından; satışta/iadede ortalama maliyet.
      const unitCost = type === 'purchase' ? unitCostMinorFromTaxable(lp.taxableMinor, lp.absQtyMilli) : products.get(lp.productId)!.avgCostMinor;
      tx.set(ref(cid, 'stock_movements', `${txId}_${lp.levelId}`), {
        companyId: cid, txId, productId: lp.productId, warehouseId: lp.warehouseId, deltaMilli: lp.deltaMilli, type: moveType,
        unitCostMinor: unitCost, refType: 'invoice', refId: invoiceId, date: draft.issueDate, createdBy: ctx.uid, createdAt: serverTimestamp(),
      });
    }
    for (const pp of plan.products.values()) {
      const prod = products.get(pp.productId)!;
      const upd: Record<string, unknown> = { totalQtyMilli: prod.totalQtyMilli + pp.deltaMilli, updatedAt: serverTimestamp() };
      if (type === 'purchase') upd.avgCostMinor = newAverageCostForPurchase({ oldQtyMilli: prod.totalQtyMilli, oldAvgMinor: prod.avgCostMinor, plan: pp });
      tx.update(ref(cid, 'products', pp.productId), upd);
    }

    // Proje istatistiği
    const taxable = totals.taxableMinor;
    const rev = revenueDelta(type, taxable);
    const cost = costDelta(type, taxable);
    if (projRef && projSnap) {
      tx.set(projRef, buildProjectStatsWrite({
        current: projSnap.data(), companyId: cid, txId, revenueDelta: rev, costDelta: cost,
        discipline: draft.costCategory, disciplineDelta: cost,
      }), { merge: true });
    }

    // Özet istatistik
    const contrib = partyContribution(oldBal, newBal);
    tx.set(statsRef, buildSummaryWrite({
      current: statsSnap.data(), companyId: cid, receivableDelta: contrib.receivable, payableDelta: contrib.payable,
      monthKey: monthKey(draft.issueDate), incomeDelta: rev, expenseDelta: cost,
    }), { merge: true });

    // Fatura belgesi
    const invData: Record<string, unknown> = {
      companyId: cid, type, status: 'issued', number, partyId: draft.partyId, partyName: str(partyData.name),
      issueDate: draft.issueDate, dueDate: draft.dueDate, currency: 'TRY', priceIncludesVat: draft.priceIncludesVat, note: draft.note,
      lines: c.lines.map(lineToMap), subtotalMinor: totals.subtotalMinor, discountMinor: totals.discountMinor,
      vatMinor: totals.vatMinor, totalMinor: totals.totalMinor, paidMinor: 0, paymentStatus: 'unpaid',
      rev: serverRev + 1, txId, lastTxId: txId, updatedAt: serverTimestamp(),
    };
    if (invSnap.exists()) {
      tx.update(invRef, { ...invData, projectId: draft.projectId ?? deleteField(), costCategory: draft.costCategory ?? deleteField() });
    } else {
      tx.set(invRef, {
        ...invData, ...(draft.projectId ? { projectId: draft.projectId } : {}), ...(draft.costCategory ? { costCategory: draft.costCategory } : {}),
        createdBy: ctx.uid, createdAt: serverTimestamp(),
      });
    }

    // Denetim çapası + audit
    tx.set(txRef, { companyId: cid, type: 'invoice_issue', createdBy: ctx.uid, createdAt: serverTimestamp(), refs: { invoiceId, partyId: draft.partyId } });
    tx.set(ref(cid, 'audit_logs', newId()), {
      companyId: cid, action: 'invoice.issue', entityType: 'invoice', entityId: invoiceId, userId: ctx.uid,
      at: serverTimestamp(), summary: `${number} ${formatMinorTry(totals.totalMinor)}`,
    });

    return { invoiceId, number };
  }));
}

// ------------------------------------------------------------ faturayı iptal

/** docs/04 §4: kes işleminin TAM tersi. Şart: `issued` ve `paidMinor == 0`. */
export async function cancelInvoice(ctx: ServiceCtx, invoiceId: string, txId: string): Promise<void> {
  requirePermission(ctx);
  assertOnline();
  const cid = ctx.companyId;

  await withAbortRetry(() => runTransaction(db, async (tx): Promise<void> => {
    // ======================= OKUMALAR =====================================
    const txRef = ref(cid, 'txns', txId);
    if ((await tx.get(txRef)).exists()) throw new TxError('alreadyProcessed');

    const invRef = ref(cid, 'invoices', invoiceId);
    const invSnap = await tx.get(invRef);
    if (!invSnap.exists()) throw new TxError('invoiceNotFound');
    const inv = invoiceFromData(invSnap.id, invSnap.data() as DocumentData);
    if (inv.status !== 'issued') throw new TxError('invalidState');
    if (inv.paidMinor !== 0) throw new TxError('cannotCancelPaid');

    const companySnap = await tx.get(doc(db, 'companies', cid));
    const allowNegative = ((companySnap.data()?.settings ?? {}) as Record<string, unknown>).allowNegativeStock === true;

    const partyRef = ref(cid, 'parties', inv.partyId);
    const partySnap = await tx.get(partyRef);
    if (!partySnap.exists()) throw new TxError('partyNotFound');
    const oldBal = int(partySnap.data()?.balanceMinor);

    // Asıl stok hareketleri: kesme işleminin `{txId}_{levelId}` belgeleri.
    // Hareket belgesi varsa o seviyede stok etkisi olmuştur; tersi alınır.
    const origTx = inv.txId ?? '';
    const candidates = new Map<string, { productId: string; warehouseId: string }>();
    for (const l of inv.lines) if (l.productId && l.warehouseId) candidates.set(`${l.productId}_${l.warehouseId}`, { productId: l.productId, warehouseId: l.warehouseId });
    const reversals = new Map<string, { productId: string; warehouseId: string; delta: number; unitCost: number }>();
    if (origTx) {
      for (const [key, v] of candidates) {
        const mv = await tx.get(ref(cid, 'stock_movements', `${origTx}_${key}`));
        if (mv.exists()) reversals.set(key, { ...v, delta: -int(mv.data()?.deltaMilli), unitCost: int(mv.data()?.unitCostMinor) });
      }
    }

    const products = new Map<string, ProductInfo>();
    for (const id of new Set([...reversals.values()].map((r) => r.productId))) {
      const s = await tx.get(ref(cid, 'products', id));
      if (s.exists()) products.set(id, readProduct(s));
    }
    const levelSnaps = new Map<string, DocumentSnapshot<DocumentData>>();
    for (const key of reversals.keys()) levelSnaps.set(key, await tx.get(ref(cid, 'stock_levels', key)));

    // Stok geri alımı yeterliliği (kesilmiş alış iptali çıkış yaratır)
    if (!allowNegative) {
      for (const [key, r] of reversals) {
        if (r.delta >= 0) continue;
        const cur = int(levelSnaps.get(key)!.data()?.qtyMilli);
        if (cur + r.delta < 0) {
          const wh = await tx.get(ref(cid, 'warehouses', r.warehouseId));
          throw new TxError('insufficientStock', {
            product: products.get(r.productId)?.name ?? r.productId, warehouse: str(wh.data()?.name), qty: formatMilli(cur < 0 ? 0 : cur),
          });
        }
      }
    }

    const statsRef = ref(cid, 'stats', 'summary');
    const statsSnap = await tx.get(statsRef);

    let projRef: DocumentReference<DocumentData> | null = null;
    let projSnap: DocumentSnapshot<DocumentData> | null = null;
    if (inv.projectId) {
      projRef = ref(cid, 'project_stats', inv.projectId);
      projSnap = await tx.get(projRef);
    }

    // ============================ YAZMALAR ================================
    const deltaBal = -balanceSign(inv.type) * inv.totalMinor;
    const newBal = oldBal + deltaBal;
    tx.update(partyRef, { balanceMinor: newBal, lastTxId: txId, updatedAt: serverTimestamp() });
    tx.set(ref(cid, 'ledger_entries', `${txId}_${inv.partyId}`), {
      companyId: cid, txId, partyId: inv.partyId, deltaMinor: deltaBal, refType: 'reversal', refId: invoiceId,
      description: inv.number ?? '', date: todayIso(), createdAt: serverTimestamp(),
    });

    // Ters stok hareketleri (ortalama maliyet değişmez)
    const productDelta = new Map<string, number>();
    for (const [key, r] of reversals) {
      const cur = int(levelSnaps.get(key)!.data()?.qtyMilli);
      tx.update(ref(cid, 'stock_levels', key), { qtyMilli: cur + r.delta, lastTxId: txId });
      tx.set(ref(cid, 'stock_movements', `${txId}_${key}`), {
        companyId: cid, txId, productId: r.productId, warehouseId: r.warehouseId, deltaMilli: r.delta,
        type: r.delta > 0 ? 'return_in' : 'return_out', unitCostMinor: r.unitCost, refType: 'invoice_cancel', refId: invoiceId,
        date: todayIso(), createdBy: ctx.uid, createdAt: serverTimestamp(),
      });
      productDelta.set(r.productId, (productDelta.get(r.productId) ?? 0) + r.delta);
    }
    for (const [pid, d] of productDelta) {
      const prod = products.get(pid);
      if (prod) tx.update(ref(cid, 'products', pid), { totalQtyMilli: prod.totalQtyMilli + d, updatedAt: serverTimestamp() });
    }

    // Proje + özet istatistik: kesmenin tersi (ay = orijinal belge ayı, docs/08 §1)
    const taxable = inv.subtotalMinor - inv.discountMinor;
    const rev = -revenueDelta(inv.type, taxable);
    const cost = -costDelta(inv.type, taxable);
    if (projRef && projSnap) {
      tx.set(projRef, buildProjectStatsWrite({
        current: projSnap.data(), companyId: cid, txId, revenueDelta: rev, costDelta: cost,
        discipline: inv.costCategory, disciplineDelta: cost,
      }), { merge: true });
    }
    const contrib = partyContribution(oldBal, newBal);
    tx.set(statsRef, buildSummaryWrite({
      current: statsSnap.data(), companyId: cid, receivableDelta: contrib.receivable, payableDelta: contrib.payable,
      monthKey: monthKey(inv.issueDate), incomeDelta: rev, expenseDelta: cost,
    }), { merge: true });

    // Fatura: yalnız izinli alanlar (firestore.rules changedOnly)
    tx.update(invRef, { status: 'cancelled', paymentStatus: 'void', cancelTxId: txId, lastTxId: txId, updatedAt: serverTimestamp() });

    tx.set(txRef, { companyId: cid, type: 'invoice_cancel', createdBy: ctx.uid, createdAt: serverTimestamp(), refs: { invoiceId, partyId: inv.partyId } });
    tx.set(ref(cid, 'audit_logs', newId()), {
      companyId: cid, action: 'invoice.cancel', entityType: 'invoice', entityId: invoiceId, userId: ctx.uid,
      at: serverTimestamp(), summary: `${inv.number ?? invoiceId} ${formatMinorTry(inv.totalMinor)}`,
    });
  }));
}
