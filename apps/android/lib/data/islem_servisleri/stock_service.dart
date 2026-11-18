import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/date/date_utils.dart';
import '../../core/money/money.dart';
import '../firestore_paths.dart';
import '../invoice_calculator.dart';
import '../models/product.dart';
import '../models/stock_level.dart';
import 'tx_errors.dart';

/// Manuel stok islemleri (docs/04 §7). Hepsi tek `runTransaction`, `txId` ile
/// idempotent, yalniz cevrimiciyken; yetki `stock.write`.
///
/// Sozlesme eslemesi (Ajan 2 varsayimlari, PROGRESS'te kayitli):
/// - Stok Girisi  -> `opening` hareketi (+); ortalama maliyet agirlikli ortalama
///   (stok yoksa `avgCostMinor` = giris maliyeti: "opening + avgCostMinor set").
/// - Stok Cikisi  -> `adjust` hareketi (-), neden zorunlu.
/// - Sayim        -> `adjust` hareketi (sayilan - mevcut), neden zorunlu.
/// - Transfer     -> `transfer_out` + `transfer_in`; ortalama maliyet ve urun toplami degismez.
class StockService {
  StockService({
    required FirebaseFirestore db,
    required FirebaseAuth auth,
    required CompanyPaths paths,
    required UserProfile? Function() profile,
  })  : _db = db,
        _auth = auth,
        _p = paths,
        _profile = profile;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final CompanyPaths _p;
  final UserProfile? Function() _profile;

  String get _cid => _p.cid;

  String _uid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const TxException('noPermission');
    return uid;
  }

  void _requirePermission() {
    final p = _profile();
    if (p == null || !p.can('stock.write')) {
      throw const TxException('noPermission');
    }
  }

  void _requireReason(String reason) {
    if (reason.trim().isEmpty) throw const TxException('reasonRequired');
  }

  /// Stok girisi (`opening`). [unitCostMinor]: KDV haric birim maliyet.
  Future<void> stockIn({
    required String txId,
    required String productId,
    required String warehouseId,
    required int qtyMilli,
    required int unitCostMinor,
    String note = '',
  }) {
    if (qtyMilli <= 0) throw const TxException('invalidQty');
    if (unitCostMinor < 0) throw const TxException('invalidAmount');
    return _single(
      txId: txId,
      txType: 'stock_in',
      productId: productId,
      warehouseId: warehouseId,
      movementType: 'opening',
      resolveDelta: (_) => qtyMilli,
      unitCostMinor: unitCostMinor,
      applyAvgCost: true,
      note: note,
    );
  }

  /// Stok cikisi (`adjust`, negatif). Neden zorunlu.
  Future<void> stockOut({
    required String txId,
    required String productId,
    required String warehouseId,
    required int qtyMilli,
    required String reason,
  }) {
    _requireReason(reason);
    if (qtyMilli <= 0) throw const TxException('invalidQty');
    return _single(
      txId: txId,
      txType: 'stock_out',
      productId: productId,
      warehouseId: warehouseId,
      movementType: 'adjust',
      resolveDelta: (_) => -qtyMilli,
      note: reason,
    );
  }

  /// Sayim duzeltme: [countedMilli] sayilan miktar; fark `adjust` olarak yazilir.
  /// Fark 0 ise islem yapilmaz (`noChange`). Neden zorunlu.
  Future<void> stockCount({
    required String txId,
    required String productId,
    required String warehouseId,
    required int countedMilli,
    required String reason,
  }) {
    _requireReason(reason);
    if (countedMilli < 0) throw const TxException('invalidQty');
    return _single(
      txId: txId,
      txType: 'stock_adjust',
      productId: productId,
      warehouseId: warehouseId,
      movementType: 'adjust',
      resolveDelta: (current) {
        final d = countedMilli - current;
        if (d == 0) throw const TxException('noChange');
        return d;
      },
      note: reason,
    );
  }

  /// Ortak tek-seviyeli islem govdesi.
  Future<void> _single({
    required String txId,
    required String txType,
    required String productId,
    required String warehouseId,
    required String movementType,
    required int Function(int currentQtyMilli) resolveDelta,
    int? unitCostMinor,
    bool applyAvgCost = false,
    String note = '',
  }) async {
    _requirePermission();
    final uid = _uid();
    final date = todayIso();

    await _db.runTransaction<void>((tx) async {
      // ======================= OKUMALAR =====================================
      final txRef = _p.doc('txns', txId);
      if ((await tx.get(txRef)).exists) {
        throw const TxException('alreadyProcessed');
      }
      final companySnap = await tx.get(_p.company);
      final allowNegative = asBool(
        ((companySnap.data()?['settings'] as Map?)?['allowNegativeStock']),
      );
      final productRef = _p.doc('products', productId);
      final productSnap = await tx.get(productRef);
      if (!productSnap.exists) {
        throw TxException('productNotFound', {'id': productId});
      }
      final product = Product.fromDoc(productSnap);
      if (!product.trackStock) {
        throw TxException('stockNotTracked', {'product': product.name});
      }
      final whSnap = await tx.get(_p.doc('warehouses', warehouseId));
      if (!whSnap.exists) throw const TxException('warehouseNotFound');

      final levelId = StockLevel.idFor(productId, warehouseId);
      final levelRef = _p.doc('stock_levels', levelId);
      final levelSnap = await tx.get(levelRef);
      final cur = asInt(levelSnap.data()?['qtyMilli']);

      final delta = resolveDelta(cur);
      final newQty = cur + delta;
      if (delta < 0 && newQty < 0 && !allowNegative) {
        throw TxException('insufficientStock', {
          'product': product.name,
          'warehouse': asStr(whSnap.data()?['name']),
          'qty': formatMilli(cur < 0 ? 0 : cur),
        });
      }

      // ============================ YAZMALAR ================================
      if (levelSnap.exists) {
        tx.update(levelRef, {'qtyMilli': newQty, 'lastTxId': txId});
      } else {
        tx.set(levelRef, {
          'companyId': _cid,
          'productId': productId,
          'warehouseId': warehouseId,
          'qtyMilli': newQty,
          'lastTxId': txId,
        });
      }
      final cost = unitCostMinor ?? product.avgCostMinor;
      tx.set(_p.doc('stock_movements', '${txId}_$levelId'), {
        'companyId': _cid,
        'txId': txId,
        'productId': productId,
        'warehouseId': warehouseId,
        'deltaMilli': delta,
        'type': movementType,
        'unitCostMinor': cost,
        'refType': 'manual',
        'refId': '',
        'note': note.trim(),
        'date': date,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final productUpdate = <String, Object?>{
        'totalQtyMilli': product.totalQtyMilli + delta,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (applyAvgCost) {
        productUpdate['avgCostMinor'] = weightedAverageCost(
          oldQtyMilli: product.totalQtyMilli,
          oldAvgMinor: product.avgCostMinor,
          inQtyMilli: delta,
          unitCostMinor: cost,
        );
      }
      tx.update(productRef, productUpdate);

      _writeAudit(tx, txRef, uid, txType, productId, product.name, delta, note);
    });
  }

  /// Depolar arasi transfer: ortalama maliyet ve urun toplami degismez.
  Future<void> transfer({
    required String txId,
    required String productId,
    required String fromWarehouseId,
    required String toWarehouseId,
    required int qtyMilli,
    String note = '',
  }) async {
    _requirePermission();
    final uid = _uid();
    if (qtyMilli <= 0) throw const TxException('invalidQty');
    if (fromWarehouseId == toWarehouseId) {
      throw const TxException('sameWarehouse');
    }
    final date = todayIso();

    await _db.runTransaction<void>((tx) async {
      // ======================= OKUMALAR =====================================
      final txRef = _p.doc('txns', txId);
      if ((await tx.get(txRef)).exists) {
        throw const TxException('alreadyProcessed');
      }
      final companySnap = await tx.get(_p.company);
      final allowNegative = asBool(
        ((companySnap.data()?['settings'] as Map?)?['allowNegativeStock']),
      );
      final productSnap = await tx.get(_p.doc('products', productId));
      if (!productSnap.exists) {
        throw TxException('productNotFound', {'id': productId});
      }
      final product = Product.fromDoc(productSnap);
      if (!product.trackStock) {
        throw TxException('stockNotTracked', {'product': product.name});
      }
      final fromWh = await tx.get(_p.doc('warehouses', fromWarehouseId));
      final toWh = await tx.get(_p.doc('warehouses', toWarehouseId));
      if (!fromWh.exists || !toWh.exists) {
        throw const TxException('warehouseNotFound');
      }
      final fromId = StockLevel.idFor(productId, fromWarehouseId);
      final toId = StockLevel.idFor(productId, toWarehouseId);
      final fromRef = _p.doc('stock_levels', fromId);
      final toRef = _p.doc('stock_levels', toId);
      final fromSnap = await tx.get(fromRef);
      final toSnap = await tx.get(toRef);
      final fromCur = asInt(fromSnap.data()?['qtyMilli']);
      final toCur = asInt(toSnap.data()?['qtyMilli']);

      if (!allowNegative && fromCur - qtyMilli < 0) {
        throw TxException('insufficientStock', {
          'product': product.name,
          'warehouse': asStr(fromWh.data()?['name']),
          'qty': formatMilli(fromCur < 0 ? 0 : fromCur),
        });
      }

      // ============================ YAZMALAR ================================
      void writeLevel(
        DocumentReference<Json> ref,
        DocumentSnapshot<Json> snap,
        String warehouseId,
        int newQty,
      ) {
        if (snap.exists) {
          tx.update(ref, {'qtyMilli': newQty, 'lastTxId': txId});
        } else {
          tx.set(ref, {
            'companyId': _cid,
            'productId': productId,
            'warehouseId': warehouseId,
            'qtyMilli': newQty,
            'lastTxId': txId,
          });
        }
      }

      void writeMovement(String levelId, String warehouseId, int delta, String type) {
        tx.set(_p.doc('stock_movements', '${txId}_$levelId'), {
          'companyId': _cid,
          'txId': txId,
          'productId': productId,
          'warehouseId': warehouseId,
          'deltaMilli': delta,
          'type': type,
          'unitCostMinor': product.avgCostMinor,
          'refType': 'manual',
          'refId': '',
          'note': note.trim(),
          'date': date,
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      writeLevel(fromRef, fromSnap, fromWarehouseId, fromCur - qtyMilli);
      writeLevel(toRef, toSnap, toWarehouseId, toCur + qtyMilli);
      writeMovement(fromId, fromWarehouseId, -qtyMilli, 'transfer_out');
      writeMovement(toId, toWarehouseId, qtyMilli, 'transfer_in');

      _writeAudit(tx, txRef, uid, 'stock_transfer', productId, product.name, qtyMilli, note);
    });
  }

  void _writeAudit(
    Transaction tx,
    DocumentReference<Json> txRef,
    String uid,
    String txType,
    String productId,
    String productName,
    int deltaMilli,
    String note,
  ) {
    tx.set(txRef, {
      'companyId': _cid,
      'type': txType,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'refs': {'productId': productId},
    });
    tx.set(_p.doc('audit_logs', _auditId(txRef.id)), {
      'companyId': _cid,
      'action': 'stock.$txType',
      'entityType': 'product',
      'entityId': productId,
      'userId': uid,
      'at': FieldValue.serverTimestamp(),
      'summary':
          '$productName ${deltaMilli > 0 ? '+' : ''}${formatMilli(deltaMilli)}${note.trim().isEmpty ? '' : ' · ${note.trim()}'}',
    });
  }

  /// Denetim belge kimligi islem kimliginden turetilir: ayni `txId` yeniden
  /// denense bile ayni belge yazilir (tekrarsiz).
  String _auditId(String txId) => 'a_$txId';
}

final stockServiceProvider = Provider.autoDispose<StockService>((ref) {
  return StockService(
    db: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    paths: ref.watch(companyPathsProvider),
    profile: () => ref.read(userProfileProvider).valueOrNull,
  );
});
