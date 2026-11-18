import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';

class PaymentAllocation {
  const PaymentAllocation({required this.invoiceId, required this.amountMinor});

  final String invoiceId;
  final int amountMinor;

  factory PaymentAllocation.fromMap(Map<String, dynamic> m) => PaymentAllocation(
        invoiceId: asStr(m['invoiceId']),
        amountMinor: asInt(m['amountMinor']),
      );

  Json toMap() => {'invoiceId': invoiceId, 'amountMinor': amountMinor};
}

/// `payments/{paymentId}` (tahsilat `in` / odeme `out`).
class Payment {
  const Payment({
    required this.id,
    required this.companyId,
    required this.txId,
    required this.direction,
    required this.partyId,
    required this.accountId,
    required this.amountMinor,
    required this.date,
    required this.method,
    required this.allocations,
    required this.unallocatedMinor,
    this.partyName = '',
    this.projectId,
    this.note = '',
    this.status = 'active',
    this.cancelTxId,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String txId;
  final String direction; // in | out
  final String partyId;
  final String partyName; // gosterim icin anlik kopya (istege bagli ek alan)
  final String accountId;
  final int amountMinor;
  final String date;
  final String method; // cash | bank_transfer | cheque | card
  final List<PaymentAllocation> allocations;
  final int unallocatedMinor;
  final String? projectId;
  final String note;
  final String status; // active | cancelled
  final String? cancelTxId;
  final DateTime? createdAt;

  bool get isIn => direction == 'in';
  bool get isCancelled => status == 'cancelled';

  factory Payment.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Payment(
      id: doc.id,
      companyId: asStr(d['companyId']),
      txId: asStr(d['txId']),
      direction: asStr(d['direction']),
      partyId: asStr(d['partyId']),
      partyName: asStr(d['partyName']),
      accountId: asStr(d['accountId']),
      amountMinor: asInt(d['amountMinor']),
      date: asStr(d['date']),
      method: asStr(d['method']),
      allocations: [
        for (final a in (d['allocations'] as List?) ?? const [])
          PaymentAllocation.fromMap((a as Map).cast<String, dynamic>()),
      ],
      unallocatedMinor: asInt(d['unallocatedMinor']),
      projectId: asStrOrNull(d['projectId']),
      note: asStr(d['note']),
      status: asStr(d['status']).isEmpty ? 'active' : asStr(d['status']),
      cancelTxId: asStrOrNull(d['cancelTxId']),
      createdAt: asDateTime(d['createdAt']),
    );
  }
}
