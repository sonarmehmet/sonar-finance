/** Fatura modeli ve işaret kuralları — docs/02 ve docs/04 §3 ile birebir; Android `models/invoice.dart` ile aynı. */
import type { DocumentData, DocumentSnapshot, QueryDocumentSnapshot } from 'firebase/firestore';
import { addDays, parseIsoDate } from '@/core/dates';
import type { LineInput } from '@/core/calc/invoiceCalculator';

export type InvoiceType = 'sales' | 'purchase' | 'sales_return' | 'purchase_return';
export const INVOICE_TYPES: InvoiceType[] = ['sales', 'purchase', 'sales_return', 'purchase_return'];
export type InvoiceStatus = 'draft' | 'issued' | 'cancelled';
export type PaymentStatus = 'none' | 'unpaid' | 'partial' | 'paid' | 'void';

/** Cari bakiyeye etki işareti: sales:+1, purchase:-1, sales_return:-1, purchase_return:+1. */
export function balanceSign(type: InvoiceType): 1 | -1 {
  return type === 'sales' || type === 'purchase_return' ? 1 : -1;
}
/** Stok yönü: sales/purchase_return çıkış (-1), purchase/sales_return giriş (+1). */
export function stockSign(type: InvoiceType): 1 | -1 {
  return type === 'purchase' || type === 'sales_return' ? 1 : -1;
}
export function stockMovementTypeFor(type: InvoiceType): string {
  switch (type) {
    case 'sales': return 'sale_out';
    case 'purchase': return 'purchase_in';
    case 'sales_return': return 'return_in';
    default: return 'return_out';
  }
}
/** Ödeme yönü uyumu: in (tahsilat) <-> sales / purchase_return; out (ödeme) <-> purchase / sales_return. */
export const isReceivableType = (type: InvoiceType): boolean => type === 'sales' || type === 'purchase_return';
/** Hangi cari türü bu fatura türü için uygun. */
export const partyKindFor = (type: InvoiceType): 'customer' | 'supplier' => (type === 'sales' || type === 'sales_return' ? 'customer' : 'supplier');

export const defaultPrefix = (type: InvoiceType): string =>
  ({ sales: 'SF', purchase: 'AF', sales_return: 'SI', purchase_return: 'AI' })[type];

export interface InvoiceLine {
  lineId: string;
  productId?: string;
  description: string;
  qtyMilli: number;
  unit: string;
  unitPriceMinor: number;
  discountBp: number;
  vatBp: number;
  warehouseId?: string;
  // hesaplanan (04 §2) — girdi değil
  netMinor: number;
  discountMinor: number;
  vatMinor: number;
  totalMinor: number;
}

export const lineInput = (l: InvoiceLine): LineInput => ({
  qtyMilli: l.qtyMilli, unitPriceMinor: l.unitPriceMinor, discountBp: l.discountBp, vatBp: l.vatBp,
});

/** Formdaki düzenlenebilir fatura. */
export interface InvoiceDraft {
  id?: string;
  type: InvoiceType;
  partyId: string;
  partyName: string;
  issueDate: string;
  dueDate: string;
  projectId?: string;
  costCategory?: string;
  priceIncludesVat: boolean;
  note: string;
  lines: InvoiceLine[];
  /** Taslağın ekrana yüklendiği andaki rev (çakışma denetimi, docs/05). */
  rev: number;
}

export interface Invoice {
  id: string;
  type: InvoiceType;
  status: InvoiceStatus;
  number?: string;
  partyId: string;
  partyName: string;
  projectId?: string;
  costCategory?: string;
  issueDate: string;
  dueDate: string;
  priceIncludesVat: boolean;
  note: string;
  lines: InvoiceLine[];
  subtotalMinor: number;
  discountMinor: number;
  vatMinor: number;
  totalMinor: number;
  paidMinor: number;
  paymentStatus: PaymentStatus;
  rev: number;
  txId?: string;
  cancelTxId?: string;
  createdAtMs: number;
}

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const optStr = (v: unknown): string | undefined => (typeof v === 'string' && v ? v : undefined);
const int = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? Math.trunc(v) : 0);

export function lineFromMap(m: Record<string, unknown>): InvoiceLine {
  return {
    lineId: str(m.lineId), productId: optStr(m.productId), description: str(m.description), qtyMilli: int(m.qtyMilli),
    unit: str(m.unit) || 'adet', unitPriceMinor: int(m.unitPriceMinor), discountBp: int(m.discountBp), vatBp: int(m.vatBp),
    warehouseId: optStr(m.warehouseId), netMinor: int(m.netMinor), discountMinor: int(m.discountMinor),
    vatMinor: int(m.vatMinor), totalMinor: int(m.totalMinor),
  };
}

/** Firestore'a yazılacak satır haritası (undefined alan yazılmaz). */
export function lineToMap(l: InvoiceLine): Record<string, unknown> {
  const o: Record<string, unknown> = {
    lineId: l.lineId, description: l.description, qtyMilli: l.qtyMilli, unit: l.unit, unitPriceMinor: l.unitPriceMinor,
    discountBp: l.discountBp, vatBp: l.vatBp, netMinor: l.netMinor, discountMinor: l.discountMinor, vatMinor: l.vatMinor, totalMinor: l.totalMinor,
  };
  if (l.productId) o.productId = l.productId;
  if (l.warehouseId) o.warehouseId = l.warehouseId;
  return o;
}

export function invoiceFromData(id: string, x: DocumentData): Invoice {
  const ts = x.createdAt as { toMillis?: () => number } | undefined;
  return {
    id, type: (INVOICE_TYPES.includes(x.type) ? x.type : 'sales') as InvoiceType,
    status: (['draft', 'issued', 'cancelled'].includes(x.status) ? x.status : 'draft') as InvoiceStatus,
    number: optStr(x.number), partyId: str(x.partyId), partyName: str(x.partyName), projectId: optStr(x.projectId),
    costCategory: optStr(x.costCategory), issueDate: str(x.issueDate), dueDate: str(x.dueDate),
    priceIncludesVat: x.priceIncludesVat === true, note: str(x.note),
    lines: Array.isArray(x.lines) ? x.lines.map((l: Record<string, unknown>) => lineFromMap(l)) : [],
    subtotalMinor: int(x.subtotalMinor), discountMinor: int(x.discountMinor), vatMinor: int(x.vatMinor), totalMinor: int(x.totalMinor),
    paidMinor: int(x.paidMinor), paymentStatus: (str(x.paymentStatus) || 'none') as PaymentStatus, rev: int(x.rev),
    txId: optStr(x.txId), cancelTxId: optStr(x.cancelTxId), createdAtMs: ts?.toMillis ? ts.toMillis() : 0,
  };
}

export const invoiceFromDoc = (d: QueryDocumentSnapshot<DocumentData>): Invoice => invoiceFromData(d.id, d.data());
export const invoiceFromSnap = (d: DocumentSnapshot<DocumentData>): Invoice | null => (d.exists() ? invoiceFromData(d.id, d.data()) : null);

export function toDraft(inv: Invoice): InvoiceDraft {
  return {
    id: inv.id, type: inv.type, partyId: inv.partyId, partyName: inv.partyName, issueDate: inv.issueDate, dueDate: inv.dueDate,
    projectId: inv.projectId, costCategory: inv.costCategory, priceIncludesVat: inv.priceIncludesVat, note: inv.note,
    lines: inv.lines, rev: inv.rev,
  };
}

export const remainingMinor = (inv: Invoice): number => inv.totalMinor - inv.paidMinor;

export type DisplayStatus = 'paid' | 'partial' | 'pending' | 'overdue' | 'draft' | 'cancelled';

/** docs/08 §3: gösterim durumu. `today` = YYYY-MM-DD. */
export function displayStatus(inv: Invoice, today: string): DisplayStatus {
  if (inv.status === 'draft') return 'draft';
  if (inv.status === 'cancelled' || inv.paymentStatus === 'void') return 'cancelled';
  if (inv.paymentStatus === 'paid') return 'paid';
  const overdue = !!parseIsoDate(inv.dueDate) && inv.dueDate < today;
  if (overdue) return 'overdue';
  return inv.paymentStatus === 'partial' ? 'partial' : 'pending';
}

/** Vade varsayılanı: fatura tarihi + 30 gün. */
export const defaultDueDate = (issueDate: string): string => addDays(issueDate, 30);
