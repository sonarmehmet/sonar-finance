import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';

/// `stock_movements/{txId}_{levelId}` (docs/02). `note` alani sozlesmeye
/// eklenmesi istenen istege bagli alandir (manuel islem nedeni; PROGRESS "Talepler").
class StockMovement {
  const StockMovement({
    required this.id,
    required this.txId,
    required this.productId,
    required this.warehouseId,
    required this.deltaMilli,
    required this.type,
    required this.unitCostMinor,
    required this.refType,
    required this.refId,
    required this.date,
    this.note = '',
  });

  final String id;
  final String txId;
  final String productId;
  final String warehouseId;
  final int deltaMilli;
  final String type; // opening|purchase_in|sale_out|return_in|return_out|adjust|transfer_in|transfer_out
  final int unitCostMinor;
  final String refType;
  final String refId;
  final String date;
  final String note;

  factory StockMovement.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return StockMovement(
      id: doc.id,
      txId: asStr(d['txId']),
      productId: asStr(d['productId']),
      warehouseId: asStr(d['warehouseId']),
      deltaMilli: asInt(d['deltaMilli']),
      type: asStr(d['type']),
      unitCostMinor: asInt(d['unitCostMinor']),
      refType: asStr(d['refType']),
      refId: asStr(d['refId']),
      date: asStr(d['date']),
      note: asStr(d['note']),
    );
  }
}
