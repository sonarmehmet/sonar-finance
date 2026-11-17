import type { InvoiceLine } from '@/data/invoice';
import { unitCostMinorFromTaxable, weightedAverageCost } from '@/core/calc/invoiceCalculator';

/** Bir faturanın stok etkisi: aynı ürün+depo birden çok satırda ise TEK harekette birleştirilir (docs/04 §3). */
export interface LevelPlan {
  productId: string;
  warehouseId: string;
  levelId: string;
  /** İşaretli toplam miktar (giriş +, çıkış −). */
  deltaMilli: number;
  absQtyMilli: number;
  taxableMinor: number;
}

export interface ProductPlan {
  productId: string;
  deltaMilli: number;
  absQtyMilli: number;
  taxableMinor: number;
}

export interface StockPlan {
  levels: LevelPlan[];
  products: Map<string, ProductPlan>;
}

/** `stockLines`: yalnız stok takipli ürün satırları (productId + warehouseId dolu). */
export function planStock(stockLines: { line: InvoiceLine; taxableMinor: number }[], sign: 1 | -1): StockPlan {
  const levels = new Map<string, LevelPlan>();
  const products = new Map<string, ProductPlan>();
  for (const { line: l, taxableMinor } of stockLines) {
    const pid = l.productId!;
    const wid = l.warehouseId!;
    const key = `${pid}_${wid}`;
    const lp = levels.get(key) ?? { productId: pid, warehouseId: wid, levelId: key, deltaMilli: 0, absQtyMilli: 0, taxableMinor: 0 };
    lp.deltaMilli += sign * l.qtyMilli; lp.absQtyMilli += l.qtyMilli; lp.taxableMinor += taxableMinor;
    levels.set(key, lp);
    const pp = products.get(pid) ?? { productId: pid, deltaMilli: 0, absQtyMilli: 0, taxableMinor: 0 };
    pp.deltaMilli += sign * l.qtyMilli; pp.absQtyMilli += l.qtyMilli; pp.taxableMinor += taxableMinor;
    products.set(pid, pp);
  }
  return { levels: [...levels.values()], products };
}

/** Alış girişinde yeni ortalama maliyet: ürün bazında toplanmış miktar ve KDV hariç tutardan birim maliyet türetilir. */
export function newAverageCostForPurchase(p: { oldQtyMilli: number; oldAvgMinor: number; plan: ProductPlan }): number {
  const unitCost = unitCostMinorFromTaxable(p.plan.taxableMinor, p.plan.absQtyMilli);
  return weightedAverageCost({ oldQtyMilli: p.oldQtyMilli, oldAvgMinor: p.oldAvgMinor, inQtyMilli: p.plan.absQtyMilli, unitCostMinor: unitCost });
}
