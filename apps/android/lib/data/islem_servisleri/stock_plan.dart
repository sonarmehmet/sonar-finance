import '../../core/money/money.dart';
import '../invoice_calculator.dart';
import '../models/invoice.dart';

/// Bir faturanin stok etkisi: ayni urun+depo birden cok satirda ise TEK harekette
/// birlestirilir (docs/04 §3).
class LevelPlan {
  LevelPlan({required this.productId, required this.warehouseId});

  final String productId;
  final String warehouseId;

  /// Isaretli toplam miktar (giris +, cikis -).
  int deltaMilli = 0;

  /// Mutlak miktar ve KDV hariç tutar toplamlari (alis giriş maliyeti için).
  int absQtyMilli = 0;
  int taxableMinor = 0;

  String get levelId => '${productId}_$warehouseId';
}

class ProductPlan {
  ProductPlan(this.productId);

  final String productId;
  int deltaMilli = 0;
  int absQtyMilli = 0;
  int taxableMinor = 0;
}

class StockPlan {
  StockPlan(this.levels, this.products);

  final List<LevelPlan> levels;
  final Map<String, ProductPlan> products;
}

/// [stockLines]: yalnız stok takipli urun satirlari (productId + warehouseId dolu).
/// [sign]: +1 giris, -1 cikis. [taxableOf]: satirin KDV haric tutari (iskonto sonrasi).
StockPlan planStock(
  Iterable<({InvoiceLine line, int taxableMinor})> stockLines,
  int sign,
) {
  final levels = <String, LevelPlan>{};
  final products = <String, ProductPlan>{};
  for (final e in stockLines) {
    final l = e.line;
    final pid = l.productId!;
    final wid = l.warehouseId!;
    final lp = levels.putIfAbsent('${pid}_$wid', () => LevelPlan(productId: pid, warehouseId: wid));
    lp.deltaMilli += sign * l.qtyMilli;
    lp.absQtyMilli += l.qtyMilli;
    lp.taxableMinor += e.taxableMinor;
    final pp = products.putIfAbsent(pid, () => ProductPlan(pid));
    pp.deltaMilli += sign * l.qtyMilli;
    pp.absQtyMilli += l.qtyMilli;
    pp.taxableMinor += e.taxableMinor;
  }
  return StockPlan(levels.values.toList(), products);
}

/// Alis girisinde yeni ortalama maliyet (docs/04 §3). Urun bazinda toplanmis
/// miktar ve KDV haric tutardan birim maliyet turetilir:
/// `unitCost = roundHalfUp(sumTaxable*1000 / sumQty)`.
int newAverageCostForPurchase({
  required int oldQtyMilli,
  required int oldAvgMinor,
  required ProductPlan plan,
}) {
  final unitCost = unitCostMinorFromTaxable(plan.taxableMinor, plan.absQtyMilli);
  return weightedAverageCost(
    oldQtyMilli: oldQtyMilli,
    oldAvgMinor: oldAvgMinor,
    inQtyMilli: plan.absQtyMilli,
    unitCostMinor: unitCost,
  );
}

/// Kalan miktar metni icin yardimci (hata mesajlari).
String qtyText(int milli, String unitLabel) => '${formatMilli(milli)} $unitLabel';
