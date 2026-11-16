import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firestore_paths.dart';
import '../models/ledger_entry.dart';
import '../models/party.dart';
import '../write_helpers.dart';

/// Cari (`parties`) okuma ve ANA VERI yazimi. Bakiye degisimi burada YAPILMAZ;
/// yalniz islem servisleri (04) hareket belgesiyle birlikte degistirir.
class PartyRepository {
  PartyRepository(this._p);

  final CompanyPaths _p;

  Stream<List<Party>> watchAll() => _p
      .col('parties')
      .orderBy('name')
      .limit(500)
      .snapshots()
      .map((s) => s.docs.map(Party.fromDoc).toList());

  Stream<Party?> watch(String id) => _p
      .doc('parties', id)
      .snapshots()
      .map((s) => s.exists ? Party.fromDoc(s) : null);

  /// Cari ekstre (index: ledger_entries partyId + date).
  Stream<List<LedgerEntry>> watchLedger(String partyId, {int limit = 50}) => _p
      .col('ledger_entries')
      .where('partyId', isEqualTo: partyId)
      .orderBy('date', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(LedgerEntry.fromDoc).toList());

  /// Yeni cari: bakiye 0, `lastTxId` '' (firestore.rules zorunlu kilar).
  Future<({String id, bool synced})> create(Party p) async {
    final id = newId();
    final synced = await writeOrQueue(
      _p.doc('parties', id).set({
        ...p.masterFields(),
        'companyId': _p.cid,
        'balanceMinor': 0,
        'lastTxId': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    return (id: id, synced: synced);
  }

  /// Yalniz ana veri alanlari guncellenir; bakiye alanlarina dokunulmaz.
  Future<bool> update(Party p) => writeOrQueue(
        _p.doc('parties', p.id).update({
          ...p.masterFields(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
}

final partyRepositoryProvider = Provider.autoDispose<PartyRepository>(
  (ref) => PartyRepository(ref.watch(companyPathsProvider)),
);

final partiesProvider = StreamProvider.autoDispose<List<Party>>(
  (ref) => ref.watch(partyRepositoryProvider).watchAll(),
);

final partyProvider = StreamProvider.autoDispose.family<Party?, String>(
  (ref, id) => ref.watch(partyRepositoryProvider).watch(id),
);

final partyLedgerProvider =
    StreamProvider.autoDispose.family<List<LedgerEntry>, String>(
  (ref, partyId) => ref.watch(partyRepositoryProvider).watchLedger(partyId),
);
