/** Gider kaydı ve iptali — docs/04 §7. Hesap azalır; ay `expenseMinor += amount − vat`, `outMinor += amount`;
 * proje varsa `costMinor += amount − vat` + `byDiscipline`. Yetki `finance.write`. */
import { doc, runTransaction, serverTimestamp, type DocumentData, type DocumentReference } from 'firebase/firestore';
import { db } from '@/core/firebase';
import { newId } from '@/core/id';
import { monthKey } from '@/core/dates';
import { formatMinorTry, roundHalfUp, todayIso } from '@/core/money';
import { buildProjectStatsWrite, buildSummaryWrite } from './statsHelpers';
import { TxError } from './txErrors';
import type { FinanceCtx } from './paymentService';

const int = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? Math.trunc(v) : 0);
const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const ref = (cid: string, coll: string, id: string): DocumentReference<DocumentData> => doc(db, 'companies', cid, coll, id);

function guard(ctx: FinanceCtx): void {
  if (!ctx.can('finance.write')) throw new TxError('noPermission');
  if (typeof navigator !== 'undefined' && !navigator.onLine) throw new TxError('offline');
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

/** KDV dahil tutardan KDV tutarı. */
export const vatOfGross = (grossMinor: number, vatBp: number): number => grossMinor - roundHalfUp(grossMinor * 10000, 10000 + vatBp);

export interface ExpenseInput {
  txId: string; categoryId: string; amountMinor: number; vatBp: number; accountId: string; partyId?: string;
  projectId?: string; discipline?: string; date: string; description: string;
}

export async function recordExpense(ctx: FinanceCtx, e: ExpenseInput): Promise<string> {
  guard(ctx);
  if (!e.accountId) throw new TxError('accountRequired');
  if (!e.categoryId) throw new TxError('validation');
  if (!Number.isInteger(e.amountMinor) || e.amountMinor <= 0) throw new TxError('amountRequired');
  const cid = ctx.companyId, id = e.txId, vat = vatOfGross(e.amountMinor, e.vatBp), net = e.amountMinor - vat;
  await withAbortRetry(() => runTransaction(db, async (tx) => {
    const txRef = ref(cid, 'txns', e.txId);
    if ((await tx.get(txRef)).exists()) throw new TxError('alreadyProcessed');
    const accRef = ref(cid, 'accounts', e.accountId);
    const acc = await tx.get(accRef);
    if (!acc.exists()) throw new TxError('accountNotFound');
    const projSnap = e.projectId ? await tx.get(ref(cid, 'project_stats', e.projectId)) : null;
    const statsRef = ref(cid, 'stats', 'summary');
    const stats = await tx.get(statsRef);

    const accType = acc.data()!.type === 'bank' ? 'bank' : 'cash';
    tx.update(accRef, { balanceMinor: int(acc.data()!.balanceMinor) - e.amountMinor, lastTxId: e.txId });
    tx.set(ref(cid, 'account_movements', `${e.txId}_${e.accountId}`), {
      companyId: cid, txId: e.txId, accountId: e.accountId, deltaMinor: -e.amountMinor, kind: 'expense', refType: 'expense', refId: id,
      date: e.date, createdAt: serverTimestamp(),
    });
    if (e.projectId && projSnap) {
      tx.set(ref(cid, 'project_stats', e.projectId), buildProjectStatsWrite({
        current: projSnap.data(), companyId: cid, txId: e.txId, costDelta: net, discipline: e.discipline, disciplineDelta: net,
      }), { merge: true });
    }
    tx.set(statsRef, buildSummaryWrite({
      current: stats.data(), companyId: cid, cashDelta: accType === 'cash' ? -e.amountMinor : 0, bankDelta: accType === 'bank' ? -e.amountMinor : 0,
      monthKey: monthKey(e.date), expenseDelta: net, outDelta: e.amountMinor,
    }), { merge: true });
    tx.set(ref(cid, 'expenses', id), {
      companyId: cid, txId: e.txId, categoryId: e.categoryId, amountMinor: e.amountMinor, vatMinor: vat, accountId: e.accountId,
      ...(e.partyId ? { partyId: e.partyId } : {}), ...(e.projectId ? { projectId: e.projectId } : {}), ...(e.discipline ? { discipline: e.discipline } : {}),
      date: e.date, description: e.description.trim(), status: 'active', createdBy: ctx.uid, createdAt: serverTimestamp(),
    });
    tx.set(txRef, { companyId: cid, type: 'expense', createdBy: ctx.uid, createdAt: serverTimestamp(), refs: { expenseId: id, accountId: e.accountId } });
    tx.set(ref(cid, 'audit_logs', `a_${e.txId}`), {
      companyId: cid, action: 'expense.create', entityType: 'expense', entityId: id, userId: ctx.uid, at: serverTimestamp(), summary: formatMinorTry(e.amountMinor),
    });
  }));
  return id;
}

export async function cancelExpense(ctx: FinanceCtx, expenseId: string, txId: string): Promise<void> {
  guard(ctx);
  const cid = ctx.companyId;
  await withAbortRetry(() => runTransaction(db, async (tx) => {
    const txRef = ref(cid, 'txns', txId);
    if ((await tx.get(txRef)).exists()) throw new TxError('alreadyProcessed');
    const eRef = ref(cid, 'expenses', expenseId);
    const es = await tx.get(eRef);
    if (!es.exists()) throw new TxError('invalidState');
    const x = es.data()!;
    if (x.status !== 'active') throw new TxError('invalidState');
    const amount = int(x.amountMinor), net = amount - int(x.vatMinor);
    const accRef = ref(cid, 'accounts', str(x.accountId));
    const acc = await tx.get(accRef);
    if (!acc.exists()) throw new TxError('accountNotFound');
    const pid = str(x.projectId);
    const projSnap = pid ? await tx.get(ref(cid, 'project_stats', pid)) : null;
    const statsRef = ref(cid, 'stats', 'summary');
    const stats = await tx.get(statsRef);

    const accType = acc.data()!.type === 'bank' ? 'bank' : 'cash';
    tx.update(accRef, { balanceMinor: int(acc.data()!.balanceMinor) + amount, lastTxId: txId });
    tx.set(ref(cid, 'account_movements', `${txId}_${str(x.accountId)}`), {
      companyId: cid, txId, accountId: str(x.accountId), deltaMinor: amount, kind: 'in', refType: 'reversal', refId: expenseId, date: todayIso(), createdAt: serverTimestamp(),
    });
    if (pid && projSnap) {
      tx.set(ref(cid, 'project_stats', pid), buildProjectStatsWrite({
        current: projSnap.data(), companyId: cid, txId, costDelta: -net, discipline: str(x.discipline) || undefined, disciplineDelta: -net,
      }), { merge: true });
    }
    tx.set(statsRef, buildSummaryWrite({
      current: stats.data(), companyId: cid, cashDelta: accType === 'cash' ? amount : 0, bankDelta: accType === 'bank' ? amount : 0,
      monthKey: monthKey(str(x.date)), expenseDelta: -net, outDelta: -amount,
    }), { merge: true });
    tx.update(eRef, { status: 'cancelled', cancelTxId: txId, updatedAt: serverTimestamp() });
    tx.set(txRef, { companyId: cid, type: 'expense_cancel', createdBy: ctx.uid, createdAt: serverTimestamp(), refs: { expenseId } });
    tx.set(ref(cid, 'audit_logs', `a_${txId}`), {
      companyId: cid, action: 'expense.cancel', entityType: 'expense', entityId: expenseId, userId: ctx.uid, at: serverTimestamp(), summary: formatMinorTry(amount),
    });
  }));
}

export const newTxId = newId;
