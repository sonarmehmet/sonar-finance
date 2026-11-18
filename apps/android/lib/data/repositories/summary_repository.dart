import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firestore_paths.dart';
import '../models/expense.dart';
import '../models/invoice.dart';
import '../models/payment.dart';
import '../models/summary.dart';

class SummaryRepository {
  SummaryRepository(this._p);
  final CompanyPaths _p;

  Stream<Summary> watchSummary() =>
      _p.doc('stats', 'summary').snapshots().map(Summary.fromDoc);

  /// docs/08 §3: odenmemis/kismi faturalar, vadeye gore (istemcide suzulur).
  Stream<List<Invoice>> watchOpenInvoices() => _p
      .col('invoices')
      .where('paymentStatus', whereIn: ['unpaid', 'partial'])
      .orderBy('dueDate')
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(Invoice.fromDoc).toList());

  Stream<List<Invoice>> watchRecentInvoices() => _p
      .col('invoices')
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .map((s) => s.docs.map(Invoice.fromDoc).where((i) => i.isIssued || i.isCancelled).toList());

  Stream<List<Payment>> watchRecentPayments() => _p
      .col('payments')
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .map((s) => s.docs.map(Payment.fromDoc).toList());

  Stream<List<Expense>> watchRecentExpenses() => _p
      .col('expenses')
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .map((s) => s.docs.map(Expense.fromDoc).toList());
}

final summaryRepositoryProvider = Provider.autoDispose<SummaryRepository>(
  (ref) => SummaryRepository(ref.watch(companyPathsProvider)),
);

final summaryProvider = StreamProvider.autoDispose<Summary>(
  (ref) => ref.watch(summaryRepositoryProvider).watchSummary(),
);

final openInvoicesProvider = StreamProvider.autoDispose<List<Invoice>>(
  (ref) => ref.watch(summaryRepositoryProvider).watchOpenInvoices(),
);

final recentInvoicesProvider = StreamProvider.autoDispose<List<Invoice>>(
  (ref) => ref.watch(summaryRepositoryProvider).watchRecentInvoices(),
);

final recentPaymentsProvider = StreamProvider.autoDispose<List<Payment>>(
  (ref) => ref.watch(summaryRepositoryProvider).watchRecentPayments(),
);

final recentExpensesProvider = StreamProvider.autoDispose<List<Expense>>(
  (ref) => ref.watch(summaryRepositoryProvider).watchRecentExpenses(),
);
