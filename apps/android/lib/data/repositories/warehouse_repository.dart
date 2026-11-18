import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firestore_paths.dart';
import '../models/warehouse.dart';
import '../write_helpers.dart';

class WarehouseRepository {
  WarehouseRepository(this._p);

  final CompanyPaths _p;

  Stream<List<Warehouse>> watchAll() => _p
      .col('warehouses')
      .orderBy('name')
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(Warehouse.fromDoc).toList());

  /// [existing]: mevcut depolar; ilk depo otomatik varsayilan olur ve
  /// varsayilan secilirse digerlerinin bayragi tek batch'te kaldirilir.
  Future<({String id, bool synced})> create(
    Warehouse w,
    List<Warehouse> existing,
  ) async {
    final id = newId();
    final makeDefault = w.isDefault || existing.every((e) => !e.isDefault);
    final batch = _p.db.batch();
    if (makeDefault) {
      for (final e in existing.where((e) => e.isDefault)) {
        batch.update(_p.doc('warehouses', e.id), {'isDefault': false});
      }
    }
    batch.set(_p.doc('warehouses', id), {
      ...w.copyWith(isDefault: makeDefault).masterFields(),
      'companyId': _p.cid,
    });
    final synced = await writeOrQueue(batch.commit());
    return (id: id, synced: synced);
  }

  Future<bool> update(Warehouse w, List<Warehouse> existing) {
    final batch = _p.db.batch();
    if (w.isDefault) {
      for (final e in existing.where((e) => e.isDefault && e.id != w.id)) {
        batch.update(_p.doc('warehouses', e.id), {'isDefault': false});
      }
    }
    batch.update(_p.doc('warehouses', w.id), w.masterFields());
    return writeOrQueue(batch.commit());
  }
}

final warehouseRepositoryProvider = Provider.autoDispose<WarehouseRepository>(
  (ref) => WarehouseRepository(ref.watch(companyPathsProvider)),
);

final warehousesProvider = StreamProvider.autoDispose<List<Warehouse>>(
  (ref) => ref.watch(warehouseRepositoryProvider).watchAll(),
);
