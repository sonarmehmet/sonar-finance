import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firestore_paths.dart';
import '../models/invoice.dart';

/// Fatura listesi sekmeleri (tr.json `invoiceTabs`).
enum InvoiceTab { all, sales, purchase, returns, drafts }

/// Sayfalama: `limit` artirilarak "daha fazla yukle" (Spark kotasi icin 25'lik adim).
typedef InvoiceQuery = ({InvoiceTab tab, int limit});

class InvoiceRepository {
  InvoiceRepository(this._p);

  final CompanyPaths _p;

  /// Indexler: `type + issueDate desc`, `status + issueDate desc` (firestore.indexes.json).
  Stream<List<Invoice>> watchList(InvoiceQuery q) {
    var query = _p.col('invoices').orderBy('issueDate', descending: true);
    switch (q.tab) {
      case InvoiceTab.all:
        break;
      case InvoiceTab.sales:
        query = query.where('type', isEqualTo: 'sales');
      case InvoiceTab.purchase:
        query = query.where('type', isEqualTo: 'purchase');
      case InvoiceTab.returns:
        query = query.where('type', whereIn: ['sales_return', 'purchase_return']);
      case InvoiceTab.drafts:
        query = query.where('status', isEqualTo: 'draft');
    }
    return query
        .limit(q.limit)
        .snapshots()
        .map((s) => s.docs.map(Invoice.fromDoc).toList());
  }

  Stream<Invoice?> watch(String id) => _p
      .doc('invoices', id)
      .snapshots()
      .map((s) => s.exists ? Invoice.fromDoc(s) : null);

  /// Bir carinin faturalari (index: partyId + issueDate desc).
  Stream<List<Invoice>> watchForParty(String partyId, {int limit = 50}) => _p
      .col('invoices')
      .where('partyId', isEqualTo: partyId)
      .orderBy('issueDate', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(Invoice.fromDoc).toList());
}

final invoiceRepositoryProvider = Provider.autoDispose<InvoiceRepository>(
  (ref) => InvoiceRepository(ref.watch(companyPathsProvider)),
);

final invoicesProvider =
    StreamProvider.autoDispose.family<List<Invoice>, InvoiceQuery>(
  (ref, q) => ref.watch(invoiceRepositoryProvider).watchList(q),
);

final invoiceProvider = StreamProvider.autoDispose.family<Invoice?, String>(
  (ref, id) => ref.watch(invoiceRepositoryProvider).watch(id),
);

final partyInvoicesProvider =
    StreamProvider.autoDispose.family<List<Invoice>, String>(
  (ref, partyId) => ref.watch(invoiceRepositoryProvider).watchForParty(partyId),
);
