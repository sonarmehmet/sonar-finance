import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/money/money.dart';
import '../firestore_paths.dart';

/// `products/{productId}`.
class Product {
  const Product({
    required this.id,
    required this.companyId,
    required this.code,
    required this.name,
    this.category = '',
    this.unit = 'adet',
    this.vatBp = 2000,
    this.trackStock = true,
    this.buyPriceMinor = 0,
    this.sellPriceMinor = 0,
    this.avgCostMinor = 0,
    this.totalQtyMilli = 0,
    this.minStockMilli = 0,
    this.barcode = '',
    this.active = true,
  });

  final String id;
  final String companyId;
  final String code;
  final String name;
  final String category;
  final String unit;
  final int vatBp;
  final bool trackStock;
  final int buyPriceMinor;
  final int sellPriceMinor;
  final int avgCostMinor;
  final int totalQtyMilli;
  final int minStockMilli;
  final String barcode;
  final bool active;

  /// Kritik: stok takipli, kritik seviye tanimli ve toplam miktar seviyenin altinda/esit.
  bool get isCritical =>
      trackStock && minStockMilli > 0 && totalQtyMilli <= minStockMilli;

  /// Stok degeri (kurus) = miktar * ortalama maliyet / 1000.
  int get stockValueMinor => trackStock
      ? roundHalfUp(totalQtyMilli * avgCostMinor, 1000)
      : 0;

  factory Product.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Product(
      id: doc.id,
      companyId: asStr(d['companyId']),
      code: asStr(d['code']),
      name: asStr(d['name']),
      category: asStr(d['category']),
      unit: asStr(d['unit']).isEmpty ? 'adet' : asStr(d['unit']),
      vatBp: d['vatBp'] == null ? 2000 : asInt(d['vatBp']),
      trackStock: asBool(d['trackStock'], fallback: true),
      buyPriceMinor: asInt(d['buyPriceMinor']),
      sellPriceMinor: asInt(d['sellPriceMinor']),
      avgCostMinor: asInt(d['avgCostMinor']),
      totalQtyMilli: asInt(d['totalQtyMilli']),
      minStockMilli: asInt(d['minStockMilli']),
      barcode: asStr(d['barcode']),
      active: asBool(d['active'], fallback: true),
    );
  }

  /// Ana veri alanlari. `avgCostMinor` ve `totalQtyMilli` BURADA YOK:
  /// bunlar yalniz stok islemleriyle (04) degisir.
  Json masterFields() => {
        'code': code,
        'name': name,
        'category': category,
        'unit': unit,
        'vatBp': vatBp,
        'trackStock': trackStock,
        'buyPriceMinor': buyPriceMinor,
        'sellPriceMinor': sellPriceMinor,
        'minStockMilli': minStockMilli,
        'barcode': barcode,
        'active': active,
      };

  Product copyWith({
    String? code,
    String? name,
    String? category,
    String? unit,
    int? vatBp,
    bool? trackStock,
    int? buyPriceMinor,
    int? sellPriceMinor,
    int? minStockMilli,
    String? barcode,
    bool? active,
  }) =>
      Product(
        id: id,
        companyId: companyId,
        code: code ?? this.code,
        name: name ?? this.name,
        category: category ?? this.category,
        unit: unit ?? this.unit,
        vatBp: vatBp ?? this.vatBp,
        trackStock: trackStock ?? this.trackStock,
        buyPriceMinor: buyPriceMinor ?? this.buyPriceMinor,
        sellPriceMinor: sellPriceMinor ?? this.sellPriceMinor,
        avgCostMinor: avgCostMinor,
        totalQtyMilli: totalQtyMilli,
        minStockMilli: minStockMilli ?? this.minStockMilli,
        barcode: barcode ?? this.barcode,
        active: active ?? this.active,
      );
}
