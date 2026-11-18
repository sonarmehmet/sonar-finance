import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';

/// `account_movements/{txId}_{accountId}`.
class AccountMovement {
  const AccountMovement({
    required this.id,
    required this.txId,
    required this.accountId,
    required this.deltaMinor,
    required this.kind,
    required this.refType,
    required this.refId,
    required this.date,
    this.createdAt,
  });

  final String id;
  final String txId;
  final String accountId;
  final int deltaMinor;
  final String kind; // in | out | transfer_in | transfer_out | expense
  final String refType; // payment | reversal | transfer | expense | opening
  final String refId;
  final String date;
  final DateTime? createdAt;

  factory AccountMovement.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return AccountMovement(
      id: doc.id,
      txId: asStr(d['txId']),
      accountId: asStr(d['accountId']),
      deltaMinor: asInt(d['deltaMinor']),
      kind: asStr(d['kind']),
      refType: asStr(d['refType']),
      refId: asStr(d['refId']),
      date: asStr(d['date']),
      createdAt: asDateTime(d['createdAt']),
    );
  }
}
