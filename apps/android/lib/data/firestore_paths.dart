import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_providers.dart';

typedef Json = Map<String, dynamic>;

/// `companies/{cid}/...` yollari (docs/02).
class CompanyPaths {
  CompanyPaths(this.db, this.cid);

  final FirebaseFirestore db;
  final String cid;

  DocumentReference<Json> get company => db.doc('companies/$cid');

  CollectionReference<Json> col(String name) =>
      db.collection('companies/$cid/$name');

  DocumentReference<Json> doc(String name, String id) =>
      db.doc('companies/$cid/$name/$id');
}

final companyPathsProvider = Provider.autoDispose<CompanyPaths>((ref) {
  return CompanyPaths(
    ref.watch(firestoreProvider),
    ref.watch(companyIdProvider),
  );
});

// --- Belge alani okuma yardimcilari (num -> int, null guvenli) -------------

int asInt(Object? v) => (v as num?)?.toInt() ?? 0;

String asStr(Object? v) => (v as String?) ?? '';

String? asStrOrNull(Object? v) {
  final s = v as String?;
  return (s == null || s.isEmpty) ? null : s;
}

bool asBool(Object? v, {bool fallback = false}) =>
    v is bool ? v : fallback;

List<String> asStrList(Object? v) =>
    (v as List?)?.map((e) => e as String).toList() ?? const [];

DateTime? asDateTime(Object? v) => v is Timestamp ? v.toDate() : null;
