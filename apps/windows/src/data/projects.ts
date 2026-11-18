import type { DocumentData, QueryDocumentSnapshot } from 'firebase/firestore';

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const int = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? Math.trunc(v) : 0);
const intMap = (v: unknown): Record<string, number> => {
  const o: Record<string, number> = {};
  if (v && typeof v === 'object') for (const [k, n] of Object.entries(v as Record<string, unknown>)) o[k] = int(n);
  return o;
};

export type ProjectStatus = 'active' | 'done' | 'paused';
export interface Project {
  id: string; name: string; partyId: string; location: string; startDate: string; endDate: string;
  contractMinor: number; status: ProjectStatus; budgets: Record<string, number>; notes: string;
}
export function projectFromData(id: string, x: DocumentData): Project {
  return {
    id, name: str(x.name), partyId: str(x.partyId), location: str(x.location), startDate: str(x.startDate), endDate: str(x.endDate),
    contractMinor: int(x.contractMinor), status: (['done', 'paused'].includes(str(x.status)) ? str(x.status) : 'active') as ProjectStatus,
    budgets: intMap(x.budgets), notes: str(x.notes),
  };
}
export const projectFromDoc = (d: QueryDocumentSnapshot<DocumentData>): Project => projectFromData(d.id, d.data());

export interface ProjectStats { id: string; revenueMinor: number; costMinor: number; collectedMinor: number; paidOutMinor: number; byDiscipline: Record<string, number> }
export function projectStatsFromData(id: string, x: DocumentData): ProjectStats {
  return { id, revenueMinor: int(x.revenueMinor), costMinor: int(x.costMinor), collectedMinor: int(x.collectedMinor), paidOutMinor: int(x.paidOutMinor), byDiscipline: intMap(x.byDiscipline) };
}
export const projectStatsFromDoc = (d: QueryDocumentSnapshot<DocumentData>): ProjectStats => projectStatsFromData(d.id, d.data());

export interface Expense {
  id: string; categoryId: string; amountMinor: number; vatMinor: number; accountId: string; partyId?: string; projectId?: string;
  discipline?: string; date: string; description: string; status: 'active' | 'cancelled';
}
export function expenseFromDoc(d: QueryDocumentSnapshot<DocumentData>): Expense {
  const x = d.data();
  return {
    id: d.id, categoryId: str(x.categoryId), amountMinor: int(x.amountMinor), vatMinor: int(x.vatMinor), accountId: str(x.accountId),
    partyId: str(x.partyId) || undefined, projectId: str(x.projectId) || undefined, discipline: str(x.discipline) || undefined,
    date: str(x.date), description: str(x.description), status: x.status === 'cancelled' ? 'cancelled' : 'active',
  };
}
