/** Fatura para hesabı — docs/04-islem-akislari.md §2 ve §3'e BİREBİR (sözleşme v1.0.2+).
 * Android karşılığı: `invoice_calculator.dart`. Referans: shared/reference/invoice_calc.py,
 * doğrulama vektörleri: shared/test-vectors/invoice-calc.json. */
import { mulDiv, roundHalfUp } from '../money.ts';

export interface LineInput {
  qtyMilli: number;
  unitPriceMinor: number;
  discountBp: number;
  vatBp: number;
}

export interface LineAmounts {
  netMinor: number;
  discountMinor: number;
  /** Belgeye yazılmaz; proje istatistiği ve ortalama maliyet için gerekir (= net − discount). */
  taxableMinor: number;
  vatMinor: number;
  totalMinor: number;
}

export interface InvoiceTotals {
  subtotalMinor: number;
  discountMinor: number;
  taxableMinor: number;
  vatMinor: number;
  totalMinor: number;
}

function validate(l: LineInput): void {
  const ints = [l.qtyMilli, l.unitPriceMinor, l.discountBp, l.vatBp];
  if (!ints.every(Number.isInteger)) throw new RangeError('tüm değerler tam sayı olmalı');
  if (l.qtyMilli < 0) throw new RangeError('qtyMilli negatif olamaz');
  if (l.unitPriceMinor < 0) throw new RangeError('unitPriceMinor negatif olamaz');
  if (l.discountBp < 0 || l.discountBp > 10000) throw new RangeError('discountBp 0..10000 olmalı');
  if (l.vatBp < 0) throw new RangeError('vatBp negatif olamaz');
}

/** Tek satırın tutarları (§2). */
export function calculateLine(l: LineInput, priceIncludesVat: boolean): LineAmounts {
  validate(l);
  if (!priceIncludesVat) {
    const net = mulDiv(l.qtyMilli, l.unitPriceMinor, 1000);
    const discount = mulDiv(net, l.discountBp, 10000);
    const taxable = net - discount;
    const vat = mulDiv(taxable, l.vatBp, 10000);
    return { netMinor: net, discountMinor: discount, taxableMinor: taxable, vatMinor: vat, totalMinor: taxable + vat };
  }
  const grossBeforeDisc = mulDiv(l.qtyMilli, l.unitPriceMinor, 1000);
  const discIncl = mulDiv(grossBeforeDisc, l.discountBp, 10000);
  const total = grossBeforeDisc - discIncl;
  const taxable = mulDiv(total, 10000, 10000 + l.vatBp);
  const vat = total - taxable;
  const net = mulDiv(grossBeforeDisc, 10000, 10000 + l.vatBp); // KDV hariç, iskonto öncesi
  const discount = net - taxable; // KDV hariç iskonto
  return { netMinor: net, discountMinor: discount, taxableMinor: taxable, vatMinor: vat, totalMinor: total };
}

/** Başlık toplamları: satırların toplamı (ayrıca yuvarlama yok). */
export function calculateTotals(lines: readonly LineAmounts[]): InvoiceTotals {
  const t: InvoiceTotals = { subtotalMinor: 0, discountMinor: 0, taxableMinor: 0, vatMinor: 0, totalMinor: 0 };
  for (const l of lines) {
    t.subtotalMinor += l.netMinor;
    t.discountMinor += l.discountMinor;
    t.taxableMinor += l.taxableMinor;
    t.vatMinor += l.vatMinor;
    t.totalMinor += l.totalMinor;
  }
  return t;
}

export function calculateInvoice(lines: readonly LineInput[], priceIncludesVat: boolean): { lines: LineAmounts[]; totals: InvoiceTotals } {
  const amounts = lines.map((l) => calculateLine(l, priceIncludesVat));
  return { lines: amounts, totals: calculateTotals(amounts) };
}

// --- §3: alış girişinde ortalama maliyet ------------------------------------

/** KDV hariç birim maliyet = taxable*1000/qtyMilli (yuvarlı). qtyMilli <= 0 ise 0. */
export function unitCostMinorFromTaxable(taxableMinor: number, qtyMilli: number): number {
  if (qtyMilli <= 0) return 0;
  return mulDiv(taxableMinor, 1000, qtyMilli);
}

/** newAvg = roundHalfUp((oldQty*oldAvg + inQty*unitCost) / (oldQty+inQty)).
 * Varsayım (Android ile aynı): oldQtyMilli < 0 ağırlıkta 0 sayılır; toplam <= 0 ise yeni maliyet = unitCostMinor. */
export function weightedAverageCost(p: { oldQtyMilli: number; oldAvgMinor: number; inQtyMilli: number; unitCostMinor: number }): number {
  const oldQty = p.oldQtyMilli < 0 ? 0 : p.oldQtyMilli;
  const total = oldQty + p.inQtyMilli;
  if (total <= 0) return p.unitCostMinor;
  const num = BigInt(oldQty) * BigInt(p.oldAvgMinor) + BigInt(p.inQtyMilli) * BigInt(p.unitCostMinor);
  return Number((2n * num + BigInt(total)) / (2n * BigInt(total)));
}

/** §8: bir cari bakiyesi old→new olunca özet farkı. */
export function summaryDelta(oldBalance: number, newBalance: number): { receivableDelta: number; payableDelta: number } {
  const recv = (b: number) => Math.max(b, 0);
  const pay = (b: number) => Math.max(-b, 0);
  return { receivableDelta: recv(newBalance) - recv(oldBalance), payableDelta: pay(newBalance) - pay(oldBalance) };
}

/** Test/Dart ile ortak yuvarlama erişimi. */
export { roundHalfUp };
