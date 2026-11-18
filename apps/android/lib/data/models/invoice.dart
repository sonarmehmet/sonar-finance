import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/date/date_utils.dart';
import '../firestore_paths.dart';
import '../invoice_calculator.dart';

const invoiceTypes = ['sales', 'purchase', 'sales_return', 'purchase_return'];

/// Cari bakiyeye etki isareti `s` (docs/04 §3):
/// sales:+1, purchase:-1, sales_return:-1, purchase_return:+1.
int balanceSign(String type) => switch (type) {
      'sales' => 1,
      'purchase' => -1,
      'sales_return' => -1,
      'purchase_return' => 1,
      _ => throw ArgumentError.value(type, 'type', 'gecersiz fatura turu'),
    };

/// Stok yonu (docs/04 §3): sales/purchase_return cikis (-1), purchase/sales_return giris (+1).
int stockSign(String type) => switch (type) {
      'sales' => -1,
      'purchase' => 1,
      'sales_return' => 1,
      'purchase_return' => -1,
      _ => throw ArgumentError.value(type, 'type', 'gecersiz fatura turu'),
    };

/// Hareket tipi (docs/02 stock_movements.type).
String stockMovementTypeFor(String type) => switch (type) {
      'sales' => 'sale_out',
      'purchase' => 'purchase_in',
      'sales_return' => 'return_in',
      'purchase_return' => 'return_out',
      _ => throw ArgumentError.value(type, 'type', 'gecersiz fatura turu'),
    };

/// Odeme yonu ile uyumlu fatura turleri (docs/04 §5):
/// `in` (tahsilat) <-> sales / purchase_return; `out` (odeme) <-> purchase / sales_return.
bool isReceivableType(String type) => type == 'sales' || type == 'purchase_return';

class InvoiceLine {
  const InvoiceLine({
    required this.lineId,
    this.productId,
    required this.description,
    required this.qtyMilli,
    required this.unit,
    required this.unitPriceMinor,
    this.discountBp = 0,
    required this.vatBp,
    this.warehouseId,
    this.netMinor = 0,
    this.discountMinor = 0,
    this.vatMinor = 0,
    this.totalMinor = 0,
  });

  final String lineId;
  final String? productId;
  final String description;
  final int qtyMilli;
  final String unit;
  final int unitPriceMinor;
  final int discountBp;
  final int vatBp;
  final String? warehouseId;

  // Hesaplanan alanlar (docs/04 §2). Girdi olarak degil, hesaplanip yazilir.
  final int netMinor;
  final int discountMinor;
  final int vatMinor;
  final int totalMinor;

  LineInput toInput() => LineInput(
        qtyMilli: qtyMilli,
        unitPriceMinor: unitPriceMinor,
        discountBp: discountBp,
        vatBp: vatBp,
      );

  InvoiceLine withAmounts(LineAmounts a) => InvoiceLine(
        lineId: lineId,
        productId: productId,
        description: description,
        qtyMilli: qtyMilli,
        unit: unit,
        unitPriceMinor: unitPriceMinor,
        discountBp: discountBp,
        vatBp: vatBp,
        warehouseId: warehouseId,
        netMinor: a.netMinor,
        discountMinor: a.discountMinor,
        vatMinor: a.vatMinor,
        totalMinor: a.totalMinor,
      );

  InvoiceLine copyWith({
    String? productId,
    bool clearProduct = false,
    String? description,
    int? qtyMilli,
    String? unit,
    int? unitPriceMinor,
    int? discountBp,
    int? vatBp,
    String? warehouseId,
    bool clearWarehouse = false,
  }) =>
      InvoiceLine(
        lineId: lineId,
        productId: clearProduct ? null : (productId ?? this.productId),
        description: description ?? this.description,
        qtyMilli: qtyMilli ?? this.qtyMilli,
        unit: unit ?? this.unit,
        unitPriceMinor: unitPriceMinor ?? this.unitPriceMinor,
        discountBp: discountBp ?? this.discountBp,
        vatBp: vatBp ?? this.vatBp,
        warehouseId: clearWarehouse ? null : (warehouseId ?? this.warehouseId),
      );

  factory InvoiceLine.fromMap(Map<String, dynamic> m) => InvoiceLine(
        lineId: asStr(m['lineId']),
        productId: asStrOrNull(m['productId']),
        description: asStr(m['description']),
        qtyMilli: asInt(m['qtyMilli']),
        unit: asStr(m['unit']).isEmpty ? 'adet' : asStr(m['unit']),
        unitPriceMinor: asInt(m['unitPriceMinor']),
        discountBp: asInt(m['discountBp']),
        vatBp: asInt(m['vatBp']),
        warehouseId: asStrOrNull(m['warehouseId']),
        netMinor: asInt(m['netMinor']),
        discountMinor: asInt(m['discountMinor']),
        vatMinor: asInt(m['vatMinor']),
        totalMinor: asInt(m['totalMinor']),
      );

  Json toMap() => {
        'lineId': lineId,
        if (productId != null) 'productId': productId,
        'description': description,
        'qtyMilli': qtyMilli,
        'unit': unit,
        'unitPriceMinor': unitPriceMinor,
        'discountBp': discountBp,
        'vatBp': vatBp,
        if (warehouseId != null) 'warehouseId': warehouseId,
        'netMinor': netMinor,
        'discountMinor': discountMinor,
        'vatMinor': vatMinor,
        'totalMinor': totalMinor,
      };
}

/// `invoices/{invoiceId}` (docs/02).
class Invoice {
  const Invoice({
    required this.id,
    required this.companyId,
    required this.type,
    required this.status,
    this.number,
    required this.partyId,
    required this.partyName,
    this.projectId,
    this.costCategory,
    required this.issueDate,
    required this.dueDate,
    this.priceIncludesVat = false,
    this.note = '',
    required this.lines,
    this.subtotalMinor = 0,
    this.discountMinor = 0,
    this.vatMinor = 0,
    this.totalMinor = 0,
    this.paidMinor = 0,
    this.paymentStatus = 'unpaid',
    this.rev = 0,
    this.txId,
    this.cancelTxId,
    this.lastTxId = '',
    this.createdBy = '',
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String type;
  final String status; // draft | issued | cancelled
  final String? number;
  final String partyId;
  final String partyName;
  final String? projectId;
  final String? costCategory;
  final String issueDate;
  final String dueDate;
  final bool priceIncludesVat;
  final String note;
  final List<InvoiceLine> lines;
  final int subtotalMinor;
  final int discountMinor;
  final int vatMinor;
  final int totalMinor;
  final int paidMinor;
  final String paymentStatus; // none (taslak) | unpaid | partial | paid | void (iptal)
  final int rev; // taslak duzenleme sayaci (docs/05)
  final String? txId;
  final String? cancelTxId;
  final String lastTxId;
  final String createdBy;
  final DateTime? createdAt;

  bool get isDraft => status == 'draft';
  bool get isIssued => status == 'issued';
  bool get isCancelled => status == 'cancelled';

  int get remainingMinor => totalMinor - paidMinor;

  /// Gosterim durumu (docs/02): draft, cancelled, paid, partial, overdue, pending.
  /// Anahtarlar `design-tokens.json` `status` ve `tr.json` `status` ile ayni.
  String displayStatus({String? today}) {
    if (isDraft) return 'draft';
    if (isCancelled || paymentStatus == 'void') return 'cancelled';
    if (paymentStatus == 'paid') return 'paid';
    final late = isOverdue(dueDate, today: today);
    if (paymentStatus == 'partial') return late ? 'overdue' : 'partial';
    return late ? 'overdue' : 'pending';
  }

  factory Invoice.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final rawLines = (d['lines'] as List?) ?? const [];
    return Invoice(
      id: doc.id,
      companyId: asStr(d['companyId']),
      type: asStr(d['type']),
      status: asStr(d['status']),
      number: asStrOrNull(d['number']),
      partyId: asStr(d['partyId']),
      partyName: asStr(d['partyName']),
      projectId: asStrOrNull(d['projectId']),
      costCategory: asStrOrNull(d['costCategory']),
      issueDate: asStr(d['issueDate']),
      dueDate: asStr(d['dueDate']),
      priceIncludesVat: asBool(d['priceIncludesVat']),
      note: asStr(d['note']),
      lines: [
        for (final l in rawLines)
          InvoiceLine.fromMap((l as Map).cast<String, dynamic>()),
      ],
      subtotalMinor: asInt(d['subtotalMinor']),
      discountMinor: asInt(d['discountMinor']),
      vatMinor: asInt(d['vatMinor']),
      totalMinor: asInt(d['totalMinor']),
      paidMinor: asInt(d['paidMinor']),
      paymentStatus:
          asStr(d['paymentStatus']).isEmpty ? 'unpaid' : asStr(d['paymentStatus']),
      rev: asInt(d['rev']),
      txId: asStrOrNull(d['txId']),
      cancelTxId: asStrOrNull(d['cancelTxId']),
      lastTxId: asStr(d['lastTxId']),
      createdBy: asStr(d['createdBy']),
      createdAt: asDateTime(d['createdAt']),
    );
  }

  InvoiceDraft toDraft() => InvoiceDraft(
        id: id,
        type: type,
        partyId: partyId,
        partyName: partyName,
        issueDate: issueDate,
        dueDate: dueDate,
        priceIncludesVat: priceIncludesVat,
        note: note,
        projectId: projectId,
        costCategory: costCategory,
        lines: lines,
        rev: rev,
      );
}

/// Formun urettigi, henuz kesilmemis fatura girdisi. Tutarlar servis tarafinda
/// docs/04 §2'ye gore yeniden hesaplanir (istemci degeri degil hesaplanan yazilir).
class InvoiceDraft {
  const InvoiceDraft({
    this.id,
    required this.type,
    required this.partyId,
    required this.partyName,
    required this.issueDate,
    required this.dueDate,
    this.priceIncludesVat = false,
    this.note = '',
    this.projectId,
    this.costCategory,
    required this.lines,
    this.rev = 0,
  });

  /// Ekrandaki taslagin `rev`'i; kesmede sunucudakiyle karsilastirilir (docs/05).
  final int rev;

  /// `null` ise yeni fatura; doluysa mevcut taslak.
  final String? id;
  final String type;
  final String partyId;
  final String partyName;
  final String issueDate;
  final String dueDate;
  final bool priceIncludesVat;
  final String note;
  final String? projectId;
  final String? costCategory;
  final List<InvoiceLine> lines;
}
