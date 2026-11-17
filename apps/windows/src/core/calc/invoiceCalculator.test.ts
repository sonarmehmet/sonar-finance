// Çalıştırma: npm test  (Node 22+, bağımlılık gerektirmez)
// Kaynak: shared/test-vectors/invoice-calc.json (Python referansından üretilir: shared/reference/invoice_calc.py)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { roundHalfUp } from '../money.ts';
import {
  calculateInvoice, unitCostMinorFromTaxable, weightedAverageCost, summaryDelta,
} from './invoiceCalculator.ts';

const vectors = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../../../../shared/test-vectors/invoice-calc.json', import.meta.url)), 'utf-8'),
);

test('roundHalfUp', () => {
  for (const v of vectors.roundHalfUp) assert.equal(roundHalfUp(v.a, v.b), v.expected, `${v.a}/${v.b}`);
});

test('fatura hesabı (KDV hariç ve dahil)', () => {
  vectors.invoiceCalc.forEach((v: any, i: number) => {
    const { lines, totals } = calculateInvoice(v.lines, v.priceIncludesVat);
    const e = v.expected;
    assert.deepEqual(
      lines.map((l) => ({ netMinor: l.netMinor, discountMinor: l.discountMinor, vatMinor: l.vatMinor, totalMinor: l.totalMinor })),
      e.lines, `vektör #${i} satırlar`,
    );
    assert.equal(totals.subtotalMinor, e.subtotalMinor, `#${i} subtotal`);
    assert.equal(totals.discountMinor, e.discountMinor, `#${i} discount`);
    assert.equal(totals.vatMinor, e.vatMinor, `#${i} vat`);
    assert.equal(totals.totalMinor, e.totalMinor, `#${i} total`);
    assert.equal(totals.taxableMinor, e.taxableMinor, `#${i} taxable`);
  });
});

test('ortalama maliyet', () => {
  for (const v of vectors.averageCost) {
    assert.equal(
      weightedAverageCost({ oldQtyMilli: v.oldQtyMilli, oldAvgMinor: v.oldAvgMinor, inQtyMilli: v.inQtyMilli, unitCostMinor: v.unitCostMinor }),
      v.expectedAvgMinor,
    );
  }
});

test('satırdan birim maliyet', () => {
  for (const v of vectors.unitCostFromLine) assert.equal(unitCostMinorFromTaxable(v.taxableMinor, v.qtyMilli), v.expectedUnitCostMinor);
});

test('özet delta', () => {
  for (const v of vectors.summaryDelta) {
    assert.deepEqual(summaryDelta(v.oldBalanceMinor, v.newBalanceMinor), {
      receivableDelta: v.receivableDelta, payableDelta: v.payableDelta,
    });
  }
});
