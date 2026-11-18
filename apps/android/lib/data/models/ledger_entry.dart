import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';

/// `ledger_entries/{txId}_{partyId}` (cari hareket).
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.txId,
    required this.partyId,
    required this.deltaMinor,
    required this.refType,
    required this.refId,
    required this.description,
    required this.date,
  });

  final String id;
  final String txId;
  final String partyId;
  final int deltaMinor;
  final String refType; // 'invoice' | 'payment' | 'reversal' | 'opening'
  final String refId;
  final String description;
  final String date; // YYYY-MM-DD

  factory LedgerEntry.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return LedgerEntry(
      id: doc.id,
      txId: asStr(d['txId']),
      partyId: asStr(d['partyId']),
      deltaMinor: asInt(d['deltaMinor']),
      refType: asStr(d['refType']),
      refId: asStr(d['refId']),
      description: asStr(d['description']),
      date: asStr(d['date']),
    );
  }
}
