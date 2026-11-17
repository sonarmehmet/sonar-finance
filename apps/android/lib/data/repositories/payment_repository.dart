import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firestore_paths.dart';
import '../models/payment.dart';

class PaymentRepository {
  PaymentRepository(this._p);

  final CompanyPaths _p;

  /// Tum tahsilat/odemeler, yeniden eskiye (tek alan sirasi: otomatik index).
  Stream<List<Payment>> watchAll({int limit = 50}) => _p
      .col('payments')
      .orderBy('date', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(Payment.fromDoc).toList());

  /// Bir carinin odemeleri (index: partyId + date desc).
  Stream<List<Payment>> watchForParty(String partyId, {int limit = 50}) => _p
      .col('payments')
      .where('partyId', isEqualTo: partyId)
      .orderBy('date', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(Payment.fromDoc).toList());

  Stream<Payment?> watch(String id) => _p
      .doc('payments', id)
      .snapshots()
      .map((s) => s.exists ? Payment.fromDoc(s) : null);
}

final paymentRepositoryProvider = Provider.autoDispose<PaymentRepository>(
  (ref) => PaymentRepository(ref.watch(companyPathsProvider)),
);

final paymentsProvider =
    StreamProvider.autoDispose.family<List<Payment>, int>(
  (ref, limit) => ref.watch(paymentRepositoryProvider).watchAll(limit: limit),
);

final partyPaymentsProvider =
    StreamProvider.autoDispose.family<List<Payment>, String>(
  (ref, partyId) => ref.watch(paymentRepositoryProvider).watchForParty(partyId),
);

final paymentProvider = StreamProvider.autoDispose.family<Payment?, String>(
  (ref, id) => ref.watch(paymentRepositoryProvider).watch(id),
);
