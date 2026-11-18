/** `stats/summary` ve `project_stats` için `set(merge)` gövdeleri (docs/04 §3, §5, §8; docs/08 §1). */
import { serverTimestamp } from 'firebase/firestore';
import { summaryDelta } from '@/core/calc/invoiceCalculator';

type Json = Record<string, unknown>;
const int = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? Math.trunc(v) : 0);

/** Cari bakiyesi old→new olunca özete katkı. */
export const partyContribution = (oldBalance: number, newBalance: number) => {
  const d = summaryDelta(oldBalance, newBalance);
  return { receivable: d.receivableDelta, payable: d.payableDelta };
};

export function buildSummaryWrite(p: {
  current: Json | undefined; companyId: string;
  receivableDelta?: number; payableDelta?: number; cashDelta?: number; bankDelta?: number;
  monthKey?: string; incomeDelta?: number; expenseDelta?: number; inDelta?: number; outDelta?: number;
}): Json {
  const cur = p.current ?? {};
  const out: Json = {
    companyId: p.companyId,
    receivableMinor: int(cur.receivableMinor) + (p.receivableDelta ?? 0),
    payableMinor: int(cur.payableMinor) + (p.payableDelta ?? 0),
    cashMinor: int(cur.cashMinor) + (p.cashDelta ?? 0),
    bankMinor: int(cur.bankMinor) + (p.bankDelta ?? 0),
    updatedAt: serverTimestamp(),
  };
  const inc = p.incomeDelta ?? 0, exp = p.expenseDelta ?? 0, inn = p.inDelta ?? 0, outt = p.outDelta ?? 0;
  if (p.monthKey && (inc !== 0 || exp !== 0 || inn !== 0 || outt !== 0)) {
    const months = (cur.months as Record<string, Json> | undefined) ?? {};
    const m = months[p.monthKey] ?? {};
    out.months = {
      [p.monthKey]: {
        incomeMinor: int(m.incomeMinor) + inc, expenseMinor: int(m.expenseMinor) + exp,
        inMinor: int(m.inMinor) + inn, outMinor: int(m.outMinor) + outt,
      },
    };
  }
  return out;
}

export function buildProjectStatsWrite(p: {
  current: Json | undefined; companyId: string; txId: string;
  revenueDelta?: number; costDelta?: number; collectedDelta?: number; paidOutDelta?: number;
  discipline?: string; disciplineDelta?: number;
}): Json {
  const cur = p.current ?? {};
  const out: Json = {
    companyId: p.companyId,
    revenueMinor: int(cur.revenueMinor) + (p.revenueDelta ?? 0),
    costMinor: int(cur.costMinor) + (p.costDelta ?? 0),
    collectedMinor: int(cur.collectedMinor) + (p.collectedDelta ?? 0),
    paidOutMinor: int(cur.paidOutMinor) + (p.paidOutDelta ?? 0),
    lastTxId: p.txId,
  };
  if (p.discipline && (p.disciplineDelta ?? 0) !== 0) {
    const by = (cur.byDiscipline as Record<string, unknown> | undefined) ?? {};
    out.byDiscipline = { [p.discipline]: int(by[p.discipline]) + (p.disciplineDelta ?? 0) };
  }
  return out;
}
