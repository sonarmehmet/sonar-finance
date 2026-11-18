/** Tahsilat/ödeme, iptal, hesap ve hesaplar arası transfer — docs/04 §5-§7. Tek runTransaction, txId ile idempotent,
 * yalnız çevrimiçi; yetki `finance.write`. Önce tüm okumalar, sonra yazmalar. */
import { doc, runTransaction, serverTimestamp, updateDoc, type DocumentData, type DocumentReference } from 'firebase/firestore';
import { db } from '@/core/firebase';
import { newId } from '@/core/id';
import { monthKey } from '@/core/dates';
import { formatMinorTry, todayIso } from '@/core/money';
import { summaryDelta } from '@/core/calc/invoiceCalculator';
import type { Allocation, AccountType, PaymentDirection, PaymentMethod } from '@/data/finance';
import { writeOrQueue } from '@/data/repositories';
import { buildProjectStatsWrite, buildSummaryWrite } from './statsHelpers';
import { TxError } from './txErrors';

export interface FinanceCtx { companyId: string; uid: string; can(p: 'finance.write'): boolean }

const int = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? Math.trunc(v) : 0);
const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const ref = (cid: string, coll: string, id: string): DocumentReference<DocumentData> => doc(db, 'companies', cid, coll, id);

function guard(ctx: FinanceCtx, needOnline = true): void {
  if (!ctx.can('finance.write')) throw new TxError('noPermission');
  if (needOnline && typeof navigator !== 'undefined' && !navigator.onLine) throw new TxError('offline');
}
async function withAbortRetry<T>(run: () => Promise<T>): Promise<T> {
  const delays = [300, 900, 2700];
  for (let i = 0; ; i++) {
    try { return await run(); } catch (e) {
      if ((e as { code?: string }).code !== 'aborted' || i >= delays.length) throw e;
      await new Promise((r) => setTimeout(r, delays[i]));
    }
  }
}
const statusFor = (paid: number, total: number): string => (paid >= total ? 'paid' : paid > 0 ? 'partial' : 'unpaid');
/** Fatura türü ↔ ödeme yönü (04 §5). */
const compatible = (dir: PaymentDirection, type: string): boolean =>
  dir === 'in' ? type === 'sales' || type === 'purchase_return' : type === 'purchase' || type === 'sales_return';

// --------------------------------------------------------------- tahsilat / ödeme

export interface PaymentInput {
  txId: string; direction: PaymentDirection; partyId: string; accountId: string; amountMinor: number; date: string;
  method: PaymentMethod; allocations: Allocation[]; note: string;
}

export async function recordPayment(ctx: FinanceCtx, p: PaymentInput): Promise<string> {
  guard(ctx);
  const cid = ctx.companyId;
  if (!p.accountId) throw new TxError('accountRequired');
  if (!p.partyId) throw new TxError('partyRequired');
  if (!Number.isInteger(p.amountMinor) || p.amountMinor <= 0) throw new TxError('amountRequired');
  const allocs = p.allocations.filter((a) => a.amountMinor > 0);
  const allocSum = allocs.reduce((s, a) => s + a.amountMinor, 0);
  if (allocSum > p.amountMinor) throw new TxError('allocationExceeds');
  const paymentId = p.txId; // kararlı kimlik: aynı txId ile yeniden denemede aynı belge

  await withAbortRetry(() => runTransaction(db, async (tx) => {
    const txRef = ref(cid, 'txns', p.txId);
    if ((await tx.get(txRef)).exists()) throw new TxError('alreadyProcessed');
    const accRef = ref(cid, 'accounts', p.accountId);
    const accSnap = await tx.get(accRef);
    if (!accSnap.exists()) throw new TxError('accountNotFound');
    const partyRef = ref(cid, 'parties', p.partyId);
    const partySnap = await tx.get(partyRef);
    if (!partySnap.exists()) throw new TxError('partyNotFound');

    const invs: { ref: DocumentReference<DocumentData>; data: DocumentData; alloc: number }[] = [];
    for (const a of allocs) {
      const r = ref(cid, 'invoices', a.invoiceId);
      const s = await tx.get(r);
      const d = s.data();
      const label = str(d?.number) || a.invoiceId;
      if (!s.exists() || d!.status !== 'issued' || d!.partyId !== p.partyId || !compatible(p.direction, str(d!.type))) {
        throw new TxError('invoiceNotAllocatable', { number: label });
      }
      if (a.amountMinor > int(d!.totalMinor) - int(d!.paidMinor)) throw new TxError('allocationTooHigh', { number: label });
      invs.push({ ref: r, data: d!, alloc: a.amountMinor });
    }
    const projDelta = new Map<string, number>();
    for (const i of invs) { const pid = str(i.data.projectId); if (pid) projDelta.set(pid, (projDelta.get(pid) ?? 0) + i.alloc); }
    const projSnaps = new Map<string, DocumentData | undefined>();
    for (const pid of projDelta.keys()) projSnaps.set(pid, (await tx.get(ref(cid, 'project_stats', pid))).data());
    const statsRef = ref(cid, 'stats', 'summary');
    const statsSnap = await tx.get(statsRef);

    // ---- yazmalar ----
    const sign = p.direction === 'in' ? 1 : -1;
    const accType = accSnap.data()!.type === 'bank' ? 'bank' : 'cash';
    tx.update(accRef, { balanceMinor: int(accSnap.data()!.balanceMinor) + sign * p.amountMinor, lastTxId: p.txId });
    tx.set(ref(cid, 'account_movements', `${p.txId}_${p.accountId}`), {
      companyId: cid, txId: p.txId, accountId: p.accountId, deltaMinor: sign * p.amountMinor, kind: p.direction,
      refType: 'payment', refId: paymentId, date: p.date, createdAt: serverTimestamp(),
    });
    const oldBal = int(partySnap.data()!.balanceMinor);
    const newBal = oldBal - sign * p.amountMinor; // in: −amount, out: +amount
    tx.update(partyRef, { balanceMinor: newBal, lastTxId: p.txId, updatedAt: serverTimestamp() });
    tx.set(ref(cid, 'ledger_entries', `${p.txId}_${p.partyId}`), {
      companyId: cid, txId: p.txId, partyId: p.partyId, deltaMinor: newBal - oldBal, refType: 'payment', refId: paymentId,
      description: '', date: p.date, createdAt: serverTimestamp(),
    });
    for (const i of invs) {
      const paid = int(i.data.paidMinor) + i.alloc;
      tx.update(i.ref, { paidMinor: paid, paymentStatus: statusFor(paid, int(i.data.totalMinor)), lastTxId: p.txId, updatedAt: serverTimestamp() });
    }
    for (const [pid, amt] of projDelta) {
      tx.set(ref(cid, 'project_stats', pid), buildProjectStatsWrite({
        current: projSnaps.get(pid), companyId: cid, txId: p.txId,
        collectedDelta: p.direction === 'in' ? amt : 0, paidOutDelta: p.direction === 'out' ? amt : 0,
      }), { merge: true });
    }
    const c = summaryDelta(oldBal, newBal);
    tx.set(statsRef, buildSummaryWrite({
      current: statsSnap.data(), companyId: cid, receivableDelta: c.receivableDelta, payableDelta: c.payableDelta,
      cashDelta: accType === 'cash' ? sign * p.amountMinor : 0, bankDelta: accType === 'bank' ? sign * p.amountMinor : 0,
      monthKey: monthKey(p.date), inDelta: p.direction === 'in' ? p.amountMinor : 0, outDelta: p.direction === 'out' ? p.amountMinor : 0,
    }), { merge: true });
    tx.set(ref(cid, 'payments', paymentId), {
      companyId: cid, txId: p.txId, direction: p.direction, partyId: p.partyId, accountId: p.accountId, amountMinor: p.amountMinor,
      date: p.date, method: p.method, allocations: allocs, unallocatedMinor: p.amountMinor - allocSum,
      ...(projDelta.size === 1 ? { projectId: [...projDelta.keys()][0] } : {}), note: p.note.trim(), status: 'active',
      createdBy: ctx.uid, createdAt: serverTimestamp(),
    });
    tx.set(txRef, { companyId: cid, type: 'payment', createdBy: ctx.uid, createdAt: serverTimestamp(), refs: { paymentId, partyId: p.partyId, accountId: p.accountId } });
    tx.set(ref(cid, 'audit_logs', `a_${p.txId}`), {
      companyId: cid, action: 'payment.create', entityType: 'payment', entityId: paymentId, userId: ctx.uid, at: serverTimestamp(),
      summary: `${p.direction === 'in' ? '+' : '−'}${formatMinorTry(p.amountMinor)}`,
    });
  }));
  return paymentId;
}

/** docs/04 §6: tam ters kayıt (refType='reversal'). Hesap eksiye düşebilir (reddedilmez). */
export async function cancelPayment(ctx: FinanceCtx, paymentId: string, txId: string): Promise<void> {
  guard(ctx);
  const cid = ctx.companyId;
  await withAbortRetry(() => runTransaction(db, async (tx) => {
    const txRef = ref(cid, 'txns', txId);
    if ((await tx.get(txRef)).exists()) throw new TxError('alreadyProcessed');
    const pRef = ref(cid, 'payments', paymentId);
    const pSnap = await tx.get(pRef);
    if (!pSnap.exists()) throw new TxError('paymentNotFound');
    const pay = pSnap.data()!;
    if (pay.status !== 'active') throw new TxError('invalidState');
    const amount = int(pay.amountMinor);
    const sign = pay.direction === 'in' ? 1 : -1;
    const accRef = ref(cid, 'accounts', str(pay.accountId));
    const accSnap = await tx.get(accRef);
    const partyRef = ref(cid, 'parties', str(pay.partyId));
    const partySnap = await tx.get(partyRef);
    if (!accSnap.exists()) throw new TxError('accountNotFound');
    if (!partySnap.exists()) throw new TxError('partyNotFound');
    const allocs = (Array.isArray(pay.allocations) ? pay.allocations : []) as Allocation[];
    const invs: { ref: DocumentReference<DocumentData>; data: DocumentData; alloc: number }[] = [];
    for (const a of allocs) {
      const r = ref(cid, 'invoices', a.invoiceId);
      const s = await tx.get(r);
      if (s.exists()) invs.push({ ref: r, data: s.data()!, alloc: int(a.amountMinor) });
    }
    const projDelta = new Map<string, number>();
    for (const i of invs) { const pid = str(i.data.projectId); if (pid) projDelta.set(pid, (projDelta.get(pid) ?? 0) + i.alloc); }
    const projSnaps = new Map<string, DocumentData | undefined>();
    for (const pid of projDelta.keys()) projSnaps.set(pid, (await tx.get(ref(cid, 'project_stats', pid))).data());
    const statsRef = ref(cid, 'stats', 'summary');
    const statsSnap = await tx.get(statsRef);

    const accType = accSnap.data()!.type === 'bank' ? 'bank' : 'cash';
    tx.update(accRef, { balanceMinor: int(accSnap.data()!.balanceMinor) - sign * amount, lastTxId: txId });
    tx.set(ref(cid, 'account_movements', `${txId}_${str(pay.accountId)}`), {
      companyId: cid, txId, accountId: str(pay.accountId), deltaMinor: -sign * amount, kind: pay.direction === 'in' ? 'out' : 'in',
      refType: 'reversal', refId: paymentId, date: todayIso(), createdAt: serverTimestamp(),
    });
    const oldBal = int(partySnap.data()!.balanceMinor);
    const newBal = oldBal + sign * amount;
    tx.update(partyRef, { balanceMinor: newBal, lastTxId: txId, updatedAt: serverTimestamp() });
    tx.set(ref(cid, 'ledger_entries', `${txId}_${str(pay.partyId)}`), {
      companyId: cid, txId, partyId: str(pay.partyId), deltaMinor: newBal - oldBal, refType: 'reversal', refId: paymentId,
      description: '', date: todayIso(), createdAt: serverTimestamp(),
    });
    for (const i of invs) {
      const paid = Math.max(0, int(i.data.paidMinor) - i.alloc);
      tx.update(i.ref, { paidMinor: paid, paymentStatus: statusFor(paid, int(i.data.totalMinor)), lastTxId: txId, updatedAt: serverTimestamp() });
    }
    for (const [pid, amt] of projDelta) {
      tx.set(ref(cid, 'project_stats', pid), buildProjectStatsWrite({
        current: projSnaps.get(pid), companyId: cid, txId,
        collectedDelta: pay.direction === 'in' ? -amt : 0, paidOutDelta: pay.direction === 'out' ? -amt : 0,
      }), { merge: true });
    }
    const c = summaryDelta(oldBal, newBal);
    tx.set(statsRef, buildSummaryWrite({
      current: statsSnap.data(), companyId: cid, receivableDelta: c.receivableDelta, payableDelta: c.payableDelta,
      cashDelta: accType === 'cash' ? -sign * amount : 0, bankDelta: accType === 'bank' ? -sign * amount : 0,
      monthKey: monthKey(str(pay.date)), inDelta: pay.direction === 'in' ? -amount : 0, outDelta: pay.direction === 'out' ? -amount : 0,
    }), { merge: true });
    tx.update(pRef, { status: 'cancelled', cancelTxId: txId, updatedAt: serverTimestamp() });
    tx.set(txRef, { companyId: cid, type: 'payment_cancel', createdBy: ctx.uid, createdAt: serverTimestamp(), refs: { paymentId } });
    tx.set(ref(cid, 'audit_logs', `a_${txId}`), {
      companyId: cid, action: 'payment.cancel', entityType: 'payment', entityId: paymentId, userId: ctx.uid, at: serverTimestamp(), summary: formatMinorTry(amount),
    });
  }));
}

// ------------------------------------------------------------------ hesaplar

export interface AccountInput { type: AccountType; name: string; bankName: string; iban: string }

/** Yeni hesap. Açılış bakiyesi ≠ 0 ise `opening` hareketiyle desteklenir (rules backedCreate). */
export async function createAccount(ctx: FinanceCtx, a: AccountInput, openingMinor: number): Promise<string> {
  guard(ctx);
  if (!a.name.trim()) throw new TxError('nameRequired');
  if (!Number.isInteger(openingMinor)) throw new TxError('invalidAmount');
  const cid = ctx.companyId, id = newId(), txId = newId();
  await withAbortRetry(() => runTransaction(db, async (tx) => {
    const statsRef = ref(cid, 'stats', 'summary');
    const statsSnap = await tx.get(statsRef);
    tx.set(ref(cid, 'accounts', id), {
      companyId: cid, type: a.type, name: a.name.trim(), bankName: a.bankName.trim(), iban: a.iban.trim(), currency: 'TRY',
      balanceMinor: openingMinor, lastTxId: openingMinor !== 0 ? txId : '', active: true,
    });
    if (openingMinor !== 0) {
      tx.set(ref(cid, 'account_movements', `${txId}_${id}`), {
        companyId: cid, txId, accountId: id, deltaMinor: openingMinor, kind: openingMinor > 0 ? 'in' : 'out', refType: 'opening', refId: id,
        date: todayIso(), createdAt: serverTimestamp(),
      });
      tx.set(ref(cid, 'txns', txId), { companyId: cid, type: 'account_opening', createdBy: ctx.uid, createdAt: serverTimestamp(), refs: { accountId: id } });
      tx.set(statsRef, buildSummaryWrite({
        current: statsSnap.data(), companyId: cid, cashDelta: a.type === 'cash' ? openingMinor : 0, bankDelta: a.type === 'bank' ? openingMinor : 0,
      }), { merge: true });
    }
  }));
  return id;
}

/** Ad/banka/IBAN/aktiflik; bakiye ve lastTxId değişmez (rules). */
export function updateAccount(ctx: FinanceCtx, id: string, a: Omit<AccountInput, 'type'> & { active: boolean }): Promise<boolean> {
  guard(ctx, false);
  if (!a.name.trim()) throw new TxError('nameRequired');
  return writeOrQueue(updateDoc(ref(ctx.companyId, 'accounts', id), { name: a.name.trim(), bankName: a.bankName.trim(), iban: a.iban.trim(), active: a.active }));
}

/** docs/04 §7: iki hareket (transfer_out/in), gelir/gider değil. Kasa↔banka ise özet cash/bank kayar. */
export async function transferBetweenAccounts(ctx: FinanceCtx, p: { txId: string; fromId: string; toId: string; amountMinor: number; date: string; note: string }): Promise<void> {
  guard(ctx);
  if (p.fromId === p.toId) throw new TxError('sameAccount');
  if (!Number.isInteger(p.amountMinor) || p.amountMinor <= 0) throw new TxError('amountRequired');
  const cid = ctx.companyId;
  await withAbortRetry(() => runTransaction(db, async (tx) => {
    const txRef = ref(cid, 'txns', p.txId);
    if ((await tx.get(txRef)).exists()) throw new TxError('alreadyProcessed');
    const fRef = ref(cid, 'accounts', p.fromId), tRef = ref(cid, 'accounts', p.toId);
    const f = await tx.get(fRef), t2 = await tx.get(tRef);
    if (!f.exists() || !t2.exists()) throw new TxError('accountNotFound');
    const statsRef = ref(cid, 'stats', 'summary');
    const statsSnap = await tx.get(statsRef);
    tx.update(fRef, { balanceMinor: int(f.data()!.balanceMinor) - p.amountMinor, lastTxId: p.txId });
    tx.update(tRef, { balanceMinor: int(t2.data()!.balanceMinor) + p.amountMinor, lastTxId: p.txId });
    const mv = (accId: string, delta: number, kind: string) => tx.set(ref(cid, 'account_movements', `${p.txId}_${accId}`), {
      companyId: cid, txId: p.txId, accountId: accId, deltaMinor: delta, kind, refType: 'transfer', refId: p.txId, date: p.date, createdAt: serverTimestamp(),
    });
    mv(p.fromId, -p.amountMinor, 'transfer_out');
    mv(p.toId, p.amountMinor, 'transfer_in');
    const typeOf = (s: DocumentData | undefined) => (s?.type === 'bank' ? 'bank' : 'cash');
    const ft = typeOf(f.data()), tt = typeOf(t2.data());
    if (ft !== tt) {
      tx.set(statsRef, buildSummaryWrite({
        current: statsSnap.data(), companyId: cid,
        cashDelta: ft === 'cash' ? -p.amountMinor : p.amountMinor, bankDelta: ft === 'bank' ? -p.amountMinor : p.amountMinor,
      }), { merge: true });
    }
    tx.set(txRef, { companyId: cid, type: 'account_transfer', createdBy: ctx.uid, createdAt: serverTimestamp(), refs: { fromId: p.fromId, toId: p.toId } });
    tx.set(ref(cid, 'audit_logs', `a_${p.txId}`), {
      companyId: cid, action: 'account.transfer', entityType: 'account', entityId: p.fromId, userId: ctx.uid, at: serverTimestamp(),
      summary: `${formatMinorTry(p.amountMinor)}${p.note.trim() ? ` · ${p.note.trim()}` : ''}`,
    });
  }));
}
