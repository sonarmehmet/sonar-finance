import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firestore_paths.dart';
import '../models/product.dart';
import '../models/stock_level.dart';
import '../write_helpers.dart';

/// Urun (`products`) okuma ve ANA VERI yazimi. `avgCostMinor` / `totalQtyMilli`
/// yalniz stok islemleriyle (04) degisir; burada yazilmaz.
class ProductRepository {
  ProductRepository(this._p);

  final CompanyPaths _p;

  Stream<List<Product>> watchAll() => _p
      .col('products')
      .orderBy('name')
      .limit(1000)
      .snapshots()
      .map((s) => s.docs.map(Product.fromDoc).toList());

  Stream<Product?> watch(String id) => _p
      .doc('products', id)
      .snapshots()
      .map((s) => s.exists ? Product.fromDoc(s) : null);

  /// Bir urunun depo bazli stoklari.
  Stream<List<StockLevel>> watchLevels(String productId) => _p
      .col('stock_levels')
      .where('productId', isEqualTo: productId)
      .snapshots()
      .map((s) => s.docs.map(StockLevel.fromDoc).toList());

  /// Tum depo stoklari (stok listesi/rapor icin).
  Stream<List<StockLevel>> watchAllLevels() => _p
      .col('stock_levels')
      .limit(5000)
      .snapshots()
      .map((s) => s.docs.map(StockLevel.fromDoc).toList());

  Future<({String id, bool synced})> create(Product p) async {
    final id = newId();
    final synced = await writeOrQueue(
      _p.doc('products', id).set({
        ...p.masterFields(),
        'companyId': _p.cid,
        'avgCostMinor': 0,
        'totalQtyMilli': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    return (id: id, synced: synced);
  }

  Future<bool> update(Product p) => writeOrQueue(
        _p.doc('products', p.id).update({
          ...p.masterFields(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
}

final productRepositoryProvider = Provider.autoDispose<ProductRepository>(
  (ref) => ProductRepository(ref.watch(companyPathsProvider)),
);

final productsProvider = StreamProvider.autoDispose<List<Product>>(
  (ref) => ref.watch(productRepositoryProvider).watchAll(),
);

final productProvider = StreamProvider.autoDispose.family<Product?, String>(
  (ref, id) => ref.watch(productRepositoryProvider).watch(id),
);

final productLevelsProvider =
    StreamProvider.autoDispose.family<List<StockLevel>, String>(
  (ref, productId) =>
      ref.watch(productRepositoryProvider).watchLevels(productId),
);

final allStockLevelsProvider = StreamProvider.autoDispose<List<StockLevel>>(
  (ref) => ref.watch(productRepositoryProvider).watchAllLevels(),
);
