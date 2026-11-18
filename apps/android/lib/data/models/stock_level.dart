import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';

/// `stock_levels/{productId}_{whId}`.
class StockLevel {
  const StockLevel({
    required this.id,
    required this.productId,
    required this.warehouseId,
    required this.qtyMilli,
    this.lastTxId = '',
  });

  final String id;
  final String productId;
  final String warehouseId;
  final int qtyMilli;
  final String lastTxId;

  /// Belge kimligi: `{productId}_{whId}` (docs/02).
  static String idFor(String productId, String warehouseId) =>
      '${productId}_$warehouseId';

  factory StockLevel.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return StockLevel(
      id: doc.id,
      productId: asStr(d['productId']),
      warehouseId: asStr(d['warehouseId']),
      qtyMilli: asInt(d['qtyMilli']),
      lastTxId: asStr(d['lastTxId']),
    );
  }
}
