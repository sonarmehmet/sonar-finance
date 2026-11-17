/** docs/02-firestore-modeli.md ile birebir; Android modelleriyle aynı varsayılanlar. */
import type { DocumentData, QueryDocumentSnapshot } from 'firebase/firestore';

const str = (v: unknown): string => (typeof v === 'string' ? v : '');
const int = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? Math.trunc(v) : 0);
const bool = (v: unknown, fallback: boolean): boolean => (typeof v === 'boolean' ? v : fallback);
const strList = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : []);

export type PartyKind = 'customer' | 'supplier';

export interface Party {
  id: string;
  companyId: string;
  kinds: PartyKind[];
  name: string;
  taxOffice: string;
  taxNo: string;
  phone: string;
  email: string;
  address: string;
  notes: string;
  /** >0 alacak (bize borçlu), <0 borç (biz borçluyuz). */
  balanceMinor: number;
  lastTxId: string;
  active: boolean;
}

export function partyFromDoc(d: QueryDocumentSnapshot<DocumentData>): Party {
  const x = d.data();
  return {
    id: d.id, companyId: str(x.companyId),
    kinds: strList(x.kinds).filter((k): k is PartyKind => k === 'customer' || k === 'supplier'),
    name: str(x.name), taxOffice: str(x.taxOffice), taxNo: str(x.taxNo), phone: str(x.phone),
    email: str(x.email), address: str(x.address), notes: str(x.notes),
    balanceMinor: int(x.balanceMinor), lastTxId: str(x.lastTxId), active: bool(x.active, true),
  };
}

/** Ana veri alanları. Bakiye/lastTxId YOK: kurallar yalnız hareket belgesiyle değişmesine izin verir. */
export type PartyMaster = Pick<Party, 'kinds' | 'name' | 'taxOffice' | 'taxNo' | 'phone' | 'email' | 'address' | 'notes' | 'active'>;

export interface Product {
  id: string;
  companyId: string;
  code: string;
  name: string;
  category: string;
  unit: string;
  vatBp: number;
  trackStock: boolean;
  buyPriceMinor: number;
  sellPriceMinor: number;
  avgCostMinor: number;
  totalQtyMilli: number;
  minStockMilli: number;
  barcode: string;
  active: boolean;
}

export function productFromDoc(d: QueryDocumentSnapshot<DocumentData>): Product {
  const x = d.data();
  return {
    id: d.id, companyId: str(x.companyId), code: str(x.code), name: str(x.name), category: str(x.category),
    unit: str(x.unit) || 'adet', vatBp: x.vatBp == null ? 2000 : int(x.vatBp), trackStock: bool(x.trackStock, true),
    buyPriceMinor: int(x.buyPriceMinor), sellPriceMinor: int(x.sellPriceMinor), avgCostMinor: int(x.avgCostMinor),
    totalQtyMilli: int(x.totalQtyMilli), minStockMilli: int(x.minStockMilli), barcode: str(x.barcode), active: bool(x.active, true),
  };
}

/** avgCostMinor ve totalQtyMilli YOK: yalnız stok işlemleriyle (04) değişir. */
export type ProductMaster = Pick<Product,
  'code' | 'name' | 'category' | 'unit' | 'vatBp' | 'trackStock' | 'buyPriceMinor' | 'sellPriceMinor' | 'minStockMilli' | 'barcode' | 'active'>;

export interface Warehouse {
  id: string;
  companyId: string;
  name: string;
  location: string;
  isDefault: boolean;
  active: boolean;
}

export function warehouseFromDoc(d: QueryDocumentSnapshot<DocumentData>): Warehouse {
  const x = d.data();
  return { id: d.id, companyId: str(x.companyId), name: str(x.name), location: str(x.location), isDefault: bool(x.isDefault, false), active: bool(x.active, true) };
}

export type WarehouseMaster = Pick<Warehouse, 'name' | 'location' | 'isDefault' | 'active'>;

export interface StockLevel {
  id: string;
  productId: string;
  warehouseId: string;
  qtyMilli: number;
}

export function stockLevelFromDoc(d: QueryDocumentSnapshot<DocumentData>): StockLevel {
  const x = d.data();
  return { id: d.id, productId: str(x.productId), warehouseId: str(x.warehouseId), qtyMilli: int(x.qtyMilli) };
}

export interface LedgerEntry {
  id: string;
  txId: string;
  partyId: string;
  deltaMinor: number;
  refType: string;
  refId: string;
  description: string;
  date: string;
  createdAtMs: number;
}

export function ledgerFromDoc(d: QueryDocumentSnapshot<DocumentData>): LedgerEntry {
  const x = d.data();
  const ts = x.createdAt as { toMillis?: () => number } | undefined;
  return {
    id: d.id, txId: str(x.txId), partyId: str(x.partyId), deltaMinor: int(x.deltaMinor), refType: str(x.refType),
    refId: str(x.refId), description: str(x.description), date: str(x.date), createdAtMs: ts?.toMillis ? ts.toMillis() : 0,
  };
}

/** Kritik: stok takipli, kritik seviye tanımlı ve toplam miktar seviyenin altında/eşit. */
export const isCritical = (p: Product): boolean => p.trackStock && p.minStockMilli > 0 && p.totalQtyMilli <= p.minStockMilli;

export interface StockMovement {
  id: string;
  txId: string;
  productId: string;
  warehouseId: string;
  deltaMilli: number;
  type: string;
  unitCostMinor: number;
  refType: string;
  note: string;
  date: string;
  createdAtMs: number;
}

export function stockMovementFromDoc(d: QueryDocumentSnapshot<DocumentData>): StockMovement {
  const x = d.data();
  const ts = x.createdAt as { toMillis?: () => number } | undefined;
  return {
    id: d.id, txId: str(x.txId), productId: str(x.productId), warehouseId: str(x.warehouseId), deltaMilli: int(x.deltaMilli),
    type: str(x.type), unitCostMinor: int(x.unitCostMinor), refType: str(x.refType), note: str(x.note), date: str(x.date),
    createdAtMs: ts?.toMillis ? ts.toMillis() : 0,
  };
}
