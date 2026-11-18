import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';

/// `expenses/{id}`: tutar KDV dahil; `vatMinor` KDV payi.
class Expense {
  const Expense({
    required this.id,
    required this.txId,
    required this.categoryId,
    required this.amountMinor,
    required this.vatMinor,
    required this.accountId,
    required this.date,
    this.partyId,
    this.projectId,
    this.discipline,
    this.description = '',
    this.status = 'active',
    this.cancelTxId,
  });

  final String id;
  final String txId;
  final String categoryId;
  final int amountMinor;
  final int vatMinor;
  final String accountId;
  final String date;
  final String? partyId;
  final String? projectId;
  final String? discipline;
  final String description;
  final String status;
  final String? cancelTxId;

  bool get isCancelled => status == 'cancelled';
  int get netMinor => amountMinor - vatMinor;

  factory Expense.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Expense(
      id: doc.id,
      txId: asStr(d['txId']),
      categoryId: asStr(d['categoryId']),
      amountMinor: asInt(d['amountMinor']),
      vatMinor: asInt(d['vatMinor']),
      accountId: asStr(d['accountId']),
      date: asStr(d['date']),
      partyId: asStrOrNull(d['partyId']),
      projectId: asStrOrNull(d['projectId']),
      discipline: asStrOrNull(d['discipline']),
      description: asStr(d['description']),
      status: asStr(d['status']).isEmpty ? 'active' : asStr(d['status']),
      cancelTxId: asStrOrNull(d['cancelTxId']),
    );
  }
}
