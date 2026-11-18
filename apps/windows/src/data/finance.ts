import type { DocumentData, QueryDocumentSnapshot } from 'firebase/firestore';

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const int = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? Math.trunc(v) : 0);
const ms = (v: unknown): number => ((v as { toMillis?: () => number } | undefined)?.toMillis?.() ?? 0);

export type AccountType = 'cash' | 'bank';
export interface Account { id: string; type: AccountType; name: string; bankName: string; iban: string; balanceMinor: number; active: boolean }
export function accountFromDoc(d: QueryDocumentSnapshot<DocumentData>): Account {
  const x = d.data();
  return { id: d.id, type: x.type === 'bank' ? 'bank' : 'cash', name: str(x.name), bankName: str(x.bankName), iban: str(x.iban), balanceMinor: int(x.balanceMinor), active: x.active !== false };
}

export interface AccountMovement { id: string; txId: string; accountId: string; deltaMinor: number; kind: string; refType: string; date: string; createdAtMs: number }
export function accountMovementFromDoc(d: QueryDocumentSnapshot<DocumentData>): AccountMovement {
  const x = d.data();
  return { id: d.id, txId: str(x.txId), accountId: str(x.accountId), deltaMinor: int(x.deltaMinor), kind: str(x.kind), refType: str(x.refType), date: str(x.date), createdAtMs: ms(x.createdAt) };
}

export type PaymentDirection = 'in' | 'out';
export type PaymentMethod = 'cash' | 'bank_transfer' | 'cheque' | 'card';
export interface Allocation { invoiceId: string; amountMinor: number }
export interface Payment {
  id: string; txId: string; direction: PaymentDirection; partyId: string; accountId: string; amountMinor: number; date: string;
  method: PaymentMethod; allocations: Allocation[]; unallocatedMinor: number; projectId?: string; note: string; status: 'active' | 'cancelled';
}
export function paymentFromData(id: string, x: DocumentData): Payment {
  const al = Array.isArray(x.allocations) ? (x.allocations as DocumentData[]).map((a) => ({ invoiceId: str(a.invoiceId), amountMinor: int(a.amountMinor) })) : [];
  return {
    id, txId: str(x.txId), direction: x.direction === 'out' ? 'out' : 'in', partyId: str(x.partyId), accountId: str(x.accountId),
    amountMinor: int(x.amountMinor), date: str(x.date), method: (str(x.method) || 'cash') as PaymentMethod, allocations: al,
    unallocatedMinor: int(x.unallocatedMinor), projectId: str(x.projectId) || undefined, note: str(x.note), status: x.status === 'cancelled' ? 'cancelled' : 'active',
  };
}
export const paymentFromDoc = (d: QueryDocumentSnapshot<DocumentData>): Payment => paymentFromData(d.id, d.data());
