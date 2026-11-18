import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonar_finance/core/money/money.dart';
import 'package:sonar_finance/data/invoice_calculator.dart';

/// Resmi test vektorleri (shared/test-vectors/invoice-calc.json), `flutter test`
/// paket kokunden calisir. Windows (TS) ayni dosyayi kullanir.
Map<String, dynamic> _vectors() => jsonDecode(
      File('../../shared/test-vectors/invoice-calc.json').readAsStringSync(),
    ) as Map<String, dynamic>;

void main() {
  final v = _vectors();

  test('roundHalfUp vektorleri', () {
    for (final c in (v['roundHalfUp'] as List).cast<Map<String, dynamic>>()) {
      expect(roundHalfUp(c['a'] as int, c['b'] as int), c['expected'], reason: '$c');
    }
  });

  test('invoiceCalc vektorleri', () {
    for (final c in (v['invoiceCalc'] as List).cast<Map<String, dynamic>>()) {
      final lines = [
        for (final l in (c['lines'] as List).cast<Map<String, dynamic>>())
          LineInput(
            qtyMilli: l['qtyMilli'] as int,
            unitPriceMinor: l['unitPriceMinor'] as int,
            discountBp: l['discountBp'] as int,
            vatBp: l['vatBp'] as int,
          ),
      ];
      final incl = c['priceIncludesVat'] as bool;
      final e = c['expected'] as Map<String, dynamic>;
      final amounts = [for (final l in lines) calculateLine(l, priceIncludesVat: incl)];
      final el = (e['lines'] as List).cast<Map<String, dynamic>>();
      for (var i = 0; i < amounts.length; i++) {
        expect(amounts[i].netMinor, el[i]['netMinor'], reason: 'net $c');
        expect(amounts[i].discountMinor, el[i]['discountMinor'], reason: 'discount $c');
        expect(amounts[i].vatMinor, el[i]['vatMinor'], reason: 'vat $c');
        expect(amounts[i].totalMinor, el[i]['totalMinor'], reason: 'total $c');
      }
      final t = calculateInvoice(lines, priceIncludesVat: incl);
      expect(t.subtotalMinor, e['subtotalMinor'], reason: 'subtotal $c');
      expect(t.discountMinor, e['discountMinor'], reason: 'disc $c');
      expect(t.vatMinor, e['vatMinor'], reason: 'vat $c');
      expect(t.totalMinor, e['totalMinor'], reason: 'total $c');
      expect(t.taxableMinor, e['taxableMinor'], reason: 'taxable $c');
    }
  });

  test('averageCost vektorleri', () {
    for (final c in (v['averageCost'] as List).cast<Map<String, dynamic>>()) {
      expect(
        weightedAverageCost(
          oldQtyMilli: c['oldQtyMilli'] as int,
          oldAvgMinor: c['oldAvgMinor'] as int,
          inQtyMilli: c['inQtyMilli'] as int,
          unitCostMinor: c['unitCostMinor'] as int,
        ),
        c['expectedAvgMinor'],
        reason: '$c',
      );
    }
  });

  test('unitCostFromLine vektorleri', () {
    for (final c in (v['unitCostFromLine'] as List).cast<Map<String, dynamic>>()) {
      expect(
        unitCostMinorFromTaxable(c['taxableMinor'] as int, c['qtyMilli'] as int),
        c['expectedUnitCostMinor'],
        reason: '$c',
      );
    }
  });
}
