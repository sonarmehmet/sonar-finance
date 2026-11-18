import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/firestore_paths.dart';

/// docs/05: baglanti durumu (ag + bekleyen yazma + hata).
enum SyncConnection { online, offline, syncing, error }

/// Kuyruktaki (henuz sunucuya gitmemis) bir belge.
class PendingDoc {
  const PendingDoc({
    required this.collection,
    required this.id,
    required this.title,
    required this.data,
    this.savedAt,
  });
  final String collection; // invoices | parties | products | warehouses
  final String id;
  final String title;
  final Json data;
  final DateTime? savedAt;
}

const _watched = ['invoices', 'parties', 'products', 'warehouses'];

final onlineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool up(List<ConnectivityResult> r) => r.any((x) => x != ConnectivityResult.none);
  yield up(await c.checkConnectivity());
  yield* c.onConnectivityChanged.map(up);
});

/// Ana veri ve taslak koleksiyonlarini `includeMetadataChanges` ile dinler;
/// `hasPendingWrites` olan belgeleri toplar. Dinleyici hatasi (ornegin
/// `permission-denied`) [errors] icinde tutulur.
class PendingState {
  const PendingState({this.docs = const [], this.errors = const {}});
  final List<PendingDoc> docs;
  final Map<String, String> errors; // koleksiyon -> hata kodu
}

final pendingProvider = StreamProvider<PendingState>((ref) {
  final paths = ref.watch(companyPathsProvider);
  final ctrl = StreamController<PendingState>();
  final byCol = <String, List<PendingDoc>>{};
  final errors = <String, String>{};

  void emit() => ctrl.add(PendingState(
        docs: [for (final l in byCol.values) ...l],
        errors: Map.of(errors),
      ));

  final subs = [
    for (final name in _watched)
      paths
          .col(name)
          .limit(200)
          .snapshots(includeMetadataChanges: true)
          .listen((snap) {
        errors.remove(name);
        byCol[name] = [
          for (final d in snap.docs.where((d) => d.metadata.hasPendingWrites))
            PendingDoc(
              collection: name,
              id: d.id,
              title: _title(name, d.data()),
              data: d.data(),
              savedAt: asDateTime(d.data()['updatedAt']),
            ),
        ];
        emit();
      }, onError: (Object e) {
        errors[name] = e is FirebaseException ? e.code : 'error';
        emit();
      }),
  ];
  ref.onDispose(() {
    for (final s in subs) {
      s.cancel();
    }
    ctrl.close();
  });
  return ctrl.stream;
});

String _title(String col, Json d) {
  switch (col) {
    case 'invoices':
      final n = asStr(d['number']);
      return n.isEmpty ? asStr(d['partyName']) : n;
    default:
      return asStr(d['name']);
  }
}

final connectionStateProvider = Provider<SyncConnection>((ref) {
  final online = ref.watch(onlineProvider).valueOrNull ?? true;
  final pending = ref.watch(pendingProvider).valueOrNull ?? const PendingState();
  if (!online) return SyncConnection.offline;
  if (pending.errors.values.any((c) => c == 'permission-denied' || c == 'failed-precondition')) {
    return SyncConnection.error;
  }
  if (pending.docs.isNotEmpty) return SyncConnection.syncing;
  return SyncConnection.online;
});
