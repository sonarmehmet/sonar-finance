/// Fatura para hesabı — docs/04-islem-akislari.md §2 ve §3'e BİREBİR.
/// Windows karşılığı: `invoiceCalculator.ts` (aynı sonuçları üretmek zorunda).
library;

import '../core/money/money.dart';

/// Satır girdisi (kullanıcının girdiği değerler).
class LineInput {
  const LineInput({
    required this.qtyMilli,
    required this.unitPriceMinor,
    this.discountBp = 0,
    required this.vatBp,
  });

  final int qtyMilli;
  final int unitPriceMinor;
  final int discountBp;
  final int vatBp;
}

/// Hesaplanan satır tutarları. Fatura belgesindeki satır alanlarına karşılık gelir:
/// `netMinor, discountMinor, vatMinor, totalMinor`. [taxableMinor] belgeye yazılmaz;
/// proje istatistiği ve ortalama maliyet için gerekir (net - iskonto).
class LineAmounts {
  const LineAmounts({
    required this.netMinor,
    required this.discountMinor,
    required this.taxableMinor,
    required this.vatMinor,
    required this.totalMinor,
  });

  final int netMinor;
  final int discountMinor;
  final int taxableMinor;
  final int vatMinor;
  final int totalMinor;

  @override
  bool operator ==(Object other) =>
      other is LineAmounts &&
      other.netMinor == netMinor &&
      other.discountMinor == discountMinor &&
      other.taxableMinor == taxableMinor &&
      other.vatMinor == vatMinor &&
      other.totalMinor == totalMinor;

  @override
  int get hashCode =>
      Object.hash(netMinor, discountMinor, taxableMinor, vatMinor, totalMinor);

  @override
  String toString() =>
      'LineAmounts(net=$netMinor, discount=$discountMinor, taxable=$taxableMinor, '
      'vat=$vatMinor, total=$totalMinor)';
}

/// Başlık toplamları: satırların toplamı (ayrıca yuvarlama yok).
class InvoiceTotals {
  const InvoiceTotals({
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxableMinor,
    required this.vatMinor,
    required this.totalMinor,
  });

  final int subtotalMinor;
  final int discountMinor;
  final int taxableMinor;
  final int vatMinor;
  final int totalMinor;

  @override
  bool operator ==(Object other) =>
      other is InvoiceTotals &&
      other.subtotalMinor == subtotalMinor &&
      other.discountMinor == discountMinor &&
      other.taxableMinor == taxableMinor &&
      other.vatMinor == vatMinor &&
      other.totalMinor == totalMinor;

  @override
  int get hashCode => Object.hash(
        subtotalMinor,
        discountMinor,
        taxableMinor,
        vatMinor,
        totalMinor,
      );

  @override
  String toString() =>
      'InvoiceTotals(subtotal=$subtotalMinor, discount=$discountMinor, '
      'taxable=$taxableMinor, vat=$vatMinor, total=$totalMinor)';
}

void _validate(LineInput l) {
  if (l.qtyMilli < 0) {
    throw ArgumentError.value(l.qtyMilli, 'qtyMilli', 'negatif olamaz');
  }
  if (l.unitPriceMinor < 0) {
    throw ArgumentError.value(l.unitPriceMinor, 'unitPriceMinor', 'negatif olamaz');
  }
  if (l.discountBp < 0 || l.discountBp > 10000) {
    throw ArgumentError.value(l.discountBp, 'discountBp', '0..10000 olmalı');
  }
  if (l.vatBp < 0) {
    throw ArgumentError.value(l.vatBp, 'vatBp', 'negatif olamaz');
  }
}

/// Tek satırın tutarları (§2).
LineAmounts calculateLine(LineInput l, {required bool priceIncludesVat}) {
  _validate(l);

  if (!priceIncludesVat) {
    final net = roundHalfUp(l.qtyMilli * l.unitPriceMinor, 1000);
    final discount = roundHalfUp(net * l.discountBp, 10000);
    final taxable = net - discount;
    final vat = roundHalfUp(taxable * l.vatBp, 10000);
    return LineAmounts(
      netMinor: net,
      discountMinor: discount,
      taxableMinor: taxable,
      vatMinor: vat,
      totalMinor: taxable + vat,
    );
  }

  final grossBeforeDisc = roundHalfUp(l.qtyMilli * l.unitPriceMinor, 1000);
  final discount = roundHalfUp(grossBeforeDisc * l.discountBp, 10000);
  final total = grossBeforeDisc - discount;
  final taxable = roundHalfUp(total * 10000, 10000 + l.vatBp);
  final vat = total - taxable;
  return LineAmounts(
    // Satır kayıtlarında net = iskonto öncesi KDV hariç.
    netMinor: taxable + discount,
    discountMinor: discount,
    taxableMinor: taxable,
    vatMinor: vat,
    totalMinor: total,
  );
}

/// Başlık toplamları (§2): Σ net, Σ discount, Σ vat, Σ total.
InvoiceTotals calculateTotals(Iterable<LineAmounts> lines) {
  var subtotal = 0, discount = 0, taxable = 0, vat = 0, total = 0;
  for (final l in lines) {
    subtotal += l.netMinor;
    discount += l.discountMinor;
    taxable += l.taxableMinor;
    vat += l.vatMinor;
    total += l.totalMinor;
  }
  return InvoiceTotals(
    subtotalMinor: subtotal,
    discountMinor: discount,
    taxableMinor: taxable,
    vatMinor: vat,
    totalMinor: total,
  );
}

/// Satır listesinden doğrudan toplam (UI ve `issueInvoice` aynı yolu kullanır).
InvoiceTotals calculateInvoice(
  Iterable<LineInput> lines, {
  required bool priceIncludesVat,
}) =>
    calculateTotals(
      lines.map((l) => calculateLine(l, priceIncludesVat: priceIncludesVat)),
    );

// --- §3: alış girişinde ortalama maliyet -----------------------------------

/// KDV hariç birim maliyet = `taxable*1000/qtyMilli` (yuvarlı).
/// [qtyMilli] 0 ise 0 döner (stok hareketi oluşmaz).
int unitCostMinorFromTaxable(int taxableMinor, int qtyMilli) {
  if (qtyMilli <= 0) return 0;
  return roundHalfUp(taxableMinor * 1000, qtyMilli);
}

/// `newAvg = roundHalfUp((oldQty*oldAvg + inQty*unitCost) / (oldQty+inQty))`.
///
/// Varsayım (PROGRESS.md'de kayıtlı): `oldQtyMilli < 0` (negatif stok) ağırlıkta
/// 0 sayılır; toplam miktar <= 0 ise yeni maliyet = [unitCostMinor].
int weightedAverageCost({
  required int oldQtyMilli,
  required int oldAvgMinor,
  required int inQtyMilli,
  required int unitCostMinor,
}) {
  final oldQty = oldQtyMilli < 0 ? 0 : oldQtyMilli;
  final totalQty = oldQty + inQtyMilli;
  if (totalQty <= 0) return unitCostMinor;
  // oldQty*oldAvg birimi: milli*kuruş; bölen milli -> kuruş.
  return roundHalfUp(oldQty * oldAvgMinor + inQtyMilli * unitCostMinor, totalQty);
}
