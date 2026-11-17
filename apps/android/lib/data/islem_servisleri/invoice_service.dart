import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/date/date_utils.dart';
import '../../core/money/money.dart';
import '../firestore_paths.dart';
import '../invoice_calculator.dart';
import '../models/invoice.dart';
import '../models/product.dart';
import '../write_helpers.dart';
import 'stats_helpers.dart';
import 'stock_plan.dart';
import 'tx_errors.dart';

/// Hesaplanmis fatura: satir tutarlari ve baslik toplamlari (docs/04 §2).
class ComputedInvoice {
  const ComputedInvoice(this.lines, this.amounts, this.totals);

  final List<InvoiceLine> lines; // tutarlari doldurulmus
  final List<LineAmounts> amounts;
  final InvoiceTotals totals;
}

/// Girdiyi dogrular ve tutarlari yeniden hesaplar. Istemci degeri degil
/// HESAPLANAN yazilir (docs/04 §3).
ComputedInvoice computeInvoice(InvoiceDraft d, {required bool requireLines}) {
  if (d.partyId.isEmpty) throw const TxException('partyRequired');
  if (parseIsoDate(d.issueDate) == null ||
      parseIsoDate(d.dueDate) == null ||
      d.dueDate.compareTo(d.issueDate) < 0) {
    throw const TxException('invalidDates');
  }
  if (requireLines && d.lines.isEmpty) throw const TxException('noLines');

  final amounts = <LineAmounts>[];
  final lines = <InvoiceLine>[];
  for (final l in d.lines) {
    if (l.description.trim().isEmpty ||
        l.qtyMilli <= 0 ||
        l.unitPriceMinor < 0 ||
        l.discountBp < 0 ||
        l.discountBp > 10000 ||
        l.vatBp < 0) {
      throw const TxException('invalidLine');
    }
    final a = calculateLine(l.toInput(), priceIncludesVat: d.priceIncludesVat);
    amounts.add(a);
    lines.add(l.withAmounts(a));
  }
  return ComputedInvoice(lines, amounts, calculateTotals(amounts));
}

class IssueResult {
  const IssueResult({required this.invoiceId, required this.number});

  final String invoiceId;
  final String number;
}

/// Fatura islemleri. UI dogrudan Firestore'a yazmaz (docs/01).
/// Kes/iptal: TEK `runTransaction`, once tum okumalar sonra yazmalar (docs/04).
/// Cevrimdisiyken kesinlestirme yapilmaz: `runTransaction` hata verir, UI
/// "cevrimdisi" mesaji gosterir; yalniz taslak kaydedilir (CONTRACTS kural 5).
class InvoiceService {
  InvoiceService({
    required FirebaseFirestore db,
    required FirebaseAuth auth,
    required CompanyPaths paths,
    required UserProfile? Function() profile,
  })  : _db = db,
        _auth = auth,
        _p = paths,
        _profile = profile;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final CompanyPaths _p;
  final UserProfile? Function() _profile;

  String get _cid => _p.cid;

  String _uid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const TxException('noPermission');
    return uid;
  }

  void _requirePermission() {
    final p = _profile();
    if (p == null || !p.can('invoice.write')) {
      throw const TxException('noPermission');
    }
  }

  // ---------------------------------------------------------------- taslak

  /// Taslak kaydet (cevrimdisi da calisir: yazma yerel kuyruga alinir).
  Future<({String id, bool synced})> saveDraft(InvoiceDraft d) async {
    _requirePermission();
    final uid = _uid();
    final c = computeInvoice(d, requireLines: false);
    final id = d.id ?? newId();
    final ref = _p.doc('invoices', id);

    final data = <String, dynamic>{
      'companyId': _cid,
      'type': d.type,
      'status': 'draft',
      'partyId': d.partyId,
      'partyName': d.partyName,
      'issueDate': d.issueDate,
      'dueDate': d.dueDate,
      'currency': 'TRY',
      'priceIncludesVat': d.priceIncludesVat,
      'note': d.note,
      'lines': [for (final l in c.lines) l.toMap()],
      'subtotalMinor': c.totals.subtotalMinor,
      'discountMinor': c.totals.discountMinor,
      'vatMinor': c.totals.vatMinor,
      'totalMinor': c.totals.totalMinor,
      'paidMinor': 0,
      'paymentStatus': 'none',
      'lastTxId': '',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final Future<void> write;
    if (d.id == null) {
      write = ref.set({
        ...data,
        if (d.projectId != null) 'projectId': d.projectId,
        if (d.costCategory != null) 'costCategory': d.costCategory,
        'rev': 1,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      write = ref.update({
        ...data,
        'rev': FieldValue.increment(1),
        'projectId': d.projectId ?? FieldValue.delete(),
        'costCategory': d.costCategory ?? FieldValue.delete(),
      });
    }
    final synced = await writeOrQueue(write);
    return (id: id, synced: synced);
  }

  /// Yalniz taslak silinebilir (firestore.rules).
  Future<bool> deleteDraft(String invoiceId) {
    _requirePermission();
    return writeOrQueue(_p.doc('invoices', invoiceId).delete());
  }

  // ------------------------------------------------------------- faturayi kes

  /// docs/04 §3. [txId] form acilinca uretilir; ayni form yeniden gonderilirse
  /// AYNI txId kullanilir (cift kayit olmaz).
  /// [force]: "Benimkini koru (uzerine yaz)" secimi; `rev` denetimini atlar.
  Future<IssueResult> issueInvoice(
    InvoiceDraft draft,
    String txId, {
    bool force = false,
  }) async {
    _requirePermission();
    final uid = _uid();
    final c = computeInvoice(draft, requireLines: true);
    final type = draft.type;
    final invoiceId = draft.id ?? newId();
    final totals = c.totals;

    return withAbortRetry(() => _db.runTransaction<IssueResult>((tx) async {
      // ======================= OKUMALAR (yazmadan once) =====================
      final txRef = _p.doc('txns', txId);
      if ((await tx.get(txRef)).exists) {
        throw const TxException('alreadyProcessed');
      }

      final companySnap = await tx.get(_p.company);
      final settings =
          (companySnap.data()?['settings'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      final allowNegative = asBool(settings['allowNegativeStock']);
      final prefixes =
          (settings['invoicePrefix'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};

      final invRef = _p.doc('invoices', invoiceId);
      final invSnap = await tx.get(invRef);
      if (invSnap.exists && asStr(invSnap.data()!['status']) != 'draft') {
        throw const TxException('invalidState');
      }
      // Taslak cakismasi (docs/05): ekrandaki rev sunucudakiyle ayni olmali.
      final serverRev = asInt(invSnap.data()?['rev']);
      if (invSnap.exists && !force && serverRev != draft.rev) {
        throw const TxException('draftChanged');
      }

      final partyRef = _p.doc('parties', draft.partyId);
      final partySnap = await tx.get(partyRef);
      if (!partySnap.exists) throw const TxException('partyNotFound');
      final partyData = partySnap.data()!;

      final counterRef = _p.doc('counters', 'invoice_$type');
      final counterSnap = await tx.get(counterRef);

      // Urunler (satirlardaki productId'ler)
      final products = <String, Product>{};
      for (final id in {
        for (final l in c.lines)
          if (l.productId != null) l.productId!,
      }) {
        final snap = await tx.get(_p.doc('products', id));
        if (!snap.exists) throw TxException('productNotFound', {'id': id});
        products[id] = Product.fromDoc(snap);
      }

      // Stok takipli satirlar -> plan (ayni urun+depo tek harekette birlesir)
      final stockLines = <({InvoiceLine line, int taxableMinor})>[];
      for (var i = 0; i < c.lines.length; i++) {
        final l = c.lines[i];
        final prod = l.productId == null ? null : products[l.productId];
        if (prod == null || !prod.trackStock) continue;
        if (l.warehouseId == null || l.warehouseId!.isEmpty) {
          throw TxException('warehouseRequired', {'product': prod.name});
        }
        stockLines.add((line: l, taxableMinor: c.amounts[i].taxableMinor));
      }
      final plan = planStock(stockLines, stockSign(type));

      final levelSnaps = <String, DocumentSnapshot<Json>>{};
      for (final lp in plan.levels) {
        levelSnaps[lp.levelId] = await tx.get(_p.doc('stock_levels', lp.levelId));
      }

      // Stok yeterliligi (allowNegativeStock=false iken cikis stogu asmamali)
      if (!allowNegative) {
        for (final lp in plan.levels.where((e) => e.deltaMilli < 0)) {
          final cur = asInt(levelSnaps[lp.levelId]!.data()?['qtyMilli']);
          if (cur + lp.deltaMilli < 0) {
            final whSnap = await tx.get(_p.doc('warehouses', lp.warehouseId));
            throw TxException('insufficientStock', {
              'product': products[lp.productId]!.name,
              'warehouse': asStr(whSnap.data()?['name']),
              'qty': formatMilli(cur < 0 ? 0 : cur),
            });
          }
        }
      }

      final statsRef = _p.doc('stats', 'summary');
      final statsSnap = await tx.get(statsRef);

      final projectId = draft.projectId;
      DocumentReference<Json>? projRef;
      DocumentSnapshot<Json>? projSnap;
      if (projectId != null && projectId.isNotEmpty) {
        projRef = _p.doc('project_stats', projectId);
        projSnap = await tx.get(projRef);
      }

      // ============================ YAZMALAR ================================
      // Numara: counters.last += 1 -> "{prefix}-{yil}-{last 6 hane}"
      final last = asInt(counterSnap.data()?['last']) + 1;
      final prefix = asStrOrNull(prefixes[type]) ?? _defaultPrefix(type);
      final number =
          '$prefix-${yearOf(draft.issueDate)}-${last.toString().padLeft(6, '0')}';
      if (counterSnap.exists) {
        tx.update(counterRef, {'last': last});
      } else {
        tx.set(counterRef, {'last': last});
      }

      // Cari bakiye + ledger
      final sBal = balanceSign(type);
      final deltaBal = sBal * totals.totalMinor;
      final oldBal = asInt(partyData['balanceMinor']);
      final newBal = oldBal + deltaBal;
      tx.update(partyRef, {
        'balanceMinor': newBal,
        'lastTxId': txId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(_p.doc('ledger_entries', '${txId}_${draft.partyId}'), {
        'companyId': _cid,
        'txId': txId,
        'partyId': draft.partyId,
        'deltaMinor': deltaBal,
        'refType': 'invoice',
        'refId': invoiceId,
        'description': number,
        'date': draft.issueDate,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Stok seviyeleri + hareketler + urun toplamlari
      final moveType = stockMovementTypeFor(type);
      for (final lp in plan.levels) {
        final snap = levelSnaps[lp.levelId]!;
        final cur = asInt(snap.data()?['qtyMilli']);
        final newQty = cur + lp.deltaMilli;
        final levelRef = _p.doc('stock_levels', lp.levelId);
        if (snap.exists) {
          tx.update(levelRef, {'qtyMilli': newQty, 'lastTxId': txId});
        } else {
          tx.set(levelRef, {
            'companyId': _cid,
            'productId': lp.productId,
            'warehouseId': lp.warehouseId,
            'qtyMilli': newQty,
            'lastTxId': txId,
          });
        }
        // Alista birim maliyet satir tutarindan; satista/iadede ortalama maliyet.
        final unitCost = type == 'purchase'
            ? unitCostMinorFromTaxable(lp.taxableMinor, lp.absQtyMilli)
            : products[lp.productId]!.avgCostMinor;
        tx.set(_p.doc('stock_movements', '${txId}_${lp.levelId}'), {
          'companyId': _cid,
          'txId': txId,
          'productId': lp.productId,
          'warehouseId': lp.warehouseId,
          'deltaMilli': lp.deltaMilli,
          'type': moveType,
          'unitCostMinor': unitCost,
          'refType': 'invoice',
          'refId': invoiceId,
          'date': draft.issueDate,
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      for (final pp in plan.products.values) {
        final prod = products[pp.productId]!;
        final upd = <String, Object?>{
          'totalQtyMilli': prod.totalQtyMilli + pp.deltaMilli,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (type == 'purchase') {
          upd['avgCostMinor'] = newAverageCostForPurchase(
            oldQtyMilli: prod.totalQtyMilli,
            oldAvgMinor: prod.avgCostMinor,
            plan: pp,
          );
        }
        tx.update(_p.doc('products', pp.productId), upd);
      }

      // Proje istatistigi
      final taxable = totals.taxableMinor;
      final rev = _revenueDelta(type, taxable);
      final cost = _costDelta(type, taxable);
      if (projRef != null) {
        tx.set(
          projRef,
          buildProjectStatsWrite(
            current: projSnap!.data(),
            companyId: _cid,
            txId: txId,
            revenueDelta: rev,
            costDelta: cost,
            discipline: draft.costCategory,
            disciplineDelta: cost,
          ),
          SetOptions(merge: true),
        );
      }

      // Ozet istatistik
      final contrib = partyContribution(oldBal, newBal);
      tx.set(
        statsRef,
        buildSummaryWrite(
          current: statsSnap.data(),
          companyId: _cid,
          receivableDelta: contrib.receivable,
          payableDelta: contrib.payable,
          monthKey: monthKey(draft.issueDate),
          incomeDelta: rev,
          expenseDelta: cost,
        ),
        SetOptions(merge: true),
      );

      // Fatura belgesi
      final invData = <String, dynamic>{
        'companyId': _cid,
        'type': type,
        'status': 'issued',
        'number': number,
        'partyId': draft.partyId,
        'partyName': asStr(partyData['name']),
        'issueDate': draft.issueDate,
        'dueDate': draft.dueDate,
        'currency': 'TRY',
        'priceIncludesVat': draft.priceIncludesVat,
        'note': draft.note,
        'lines': [for (final l in c.lines) l.toMap()],
        'subtotalMinor': totals.subtotalMinor,
        'discountMinor': totals.discountMinor,
        'vatMinor': totals.vatMinor,
        'totalMinor': totals.totalMinor,
        'paidMinor': 0,
        'paymentStatus': 'unpaid',
        'rev': serverRev + 1,
        'txId': txId,
        'lastTxId': txId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (invSnap.exists) {
        tx.update(invRef, {
          ...invData,
          'projectId': draft.projectId ?? FieldValue.delete(),
          'costCategory': draft.costCategory ?? FieldValue.delete(),
        });
      } else {
        tx.set(invRef, {
          ...invData,
          if (draft.projectId != null) 'projectId': draft.projectId,
          if (draft.costCategory != null) 'costCategory': draft.costCategory,
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Denetim capasi + audit
      tx.set(txRef, {
        'companyId': _cid,
        'type': 'invoice_issue',
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'refs': {'invoiceId': invoiceId, 'partyId': draft.partyId},
      });
      tx.set(_p.doc('audit_logs', newId()), {
        'companyId': _cid,
        'action': 'invoice.issue',
        'entityType': 'invoice',
        'entityId': invoiceId,
        'userId': uid,
        'at': FieldValue.serverTimestamp(),
        'summary': '$number ${formatMinorTry(totals.totalMinor)}',
      });

      return IssueResult(invoiceId: invoiceId, number: number);
    }));
  }

  // ------------------------------------------------------------ faturayi iptal

  /// docs/04 §4: kes isleminin TAM tersi. Sart: `issued` ve `paidMinor == 0`.
  Future<void> cancelInvoice(String invoiceId, String txId) async {
    _requirePermission();
    final uid = _uid();

    await withAbortRetry(() => _db.runTransaction<void>((tx) async {
      // ======================= OKUMALAR =====================================
      final txRef = _p.doc('txns', txId);
      if ((await tx.get(txRef)).exists) {
        throw const TxException('alreadyProcessed');
      }

      final invRef = _p.doc('invoices', invoiceId);
      final invSnap = await tx.get(invRef);
      if (!invSnap.exists) throw const TxException('invoiceNotFound');
      final inv = Invoice.fromDoc(invSnap);
      if (!inv.isIssued) throw const TxException('invalidState');
      if (inv.paidMinor != 0) throw const TxException('cannotCancelPaid');

      final companySnap = await tx.get(_p.company);
      final allowNegative = asBool(
        ((companySnap.data()?['settings'] as Map?)?['allowNegativeStock']),
      );

      final partyRef = _p.doc('parties', inv.partyId);
      final partySnap = await tx.get(partyRef);
      if (!partySnap.exists) throw const TxException('partyNotFound');
      final oldBal = asInt(partySnap.data()!['balanceMinor']);

      // Asil stok hareketleri: kesme isleminin `{txId}_{levelId}` belgeleri.
      // Hareket belgesi varsa o seviyede stok etkisi olmustur; tersi alinir.
      final origTx = inv.txId ?? '';
      final candidates = <String, ({String productId, String warehouseId})>{};
      for (final l in inv.lines) {
        if (l.productId != null && (l.warehouseId ?? '').isNotEmpty) {
          candidates['${l.productId}_${l.warehouseId}'] =
              (productId: l.productId!, warehouseId: l.warehouseId!);
        }
      }
      final reversals = <String, ({String productId, String warehouseId, int delta, int unitCost})>{};
      if (origTx.isNotEmpty) {
        for (final e in candidates.entries) {
          final mv = await tx.get(_p.doc('stock_movements', '${origTx}_${e.key}'));
          if (mv.exists) {
            reversals[e.key] = (
              productId: e.value.productId,
              warehouseId: e.value.warehouseId,
              delta: -asInt(mv.data()!['deltaMilli']),
              unitCost: asInt(mv.data()!['unitCostMinor']),
            );
          }
        }
      }

      final products = <String, Product>{};
      for (final id in {for (final r in reversals.values) r.productId}) {
        final snap = await tx.get(_p.doc('products', id));
        if (snap.exists) products[id] = Product.fromDoc(snap);
      }
      final levelSnaps = <String, DocumentSnapshot<Json>>{};
      for (final key in reversals.keys) {
        levelSnaps[key] = await tx.get(_p.doc('stock_levels', key));
      }

      // Stok geri alimi yeterliligi (kesilmis alis iptali cikis yaratir)
      if (!allowNegative) {
        for (final e in reversals.entries.where((e) => e.value.delta < 0)) {
          final cur = asInt(levelSnaps[e.key]!.data()?['qtyMilli']);
          if (cur + e.value.delta < 0) {
            final whSnap =
                await tx.get(_p.doc('warehouses', e.value.warehouseId));
            throw TxException('insufficientStock', {
              'product': products[e.value.productId]?.name ?? e.value.productId,
              'warehouse': asStr(whSnap.data()?['name']),
              'qty': formatMilli(cur < 0 ? 0 : cur),
            });
          }
        }
      }

      final statsRef = _p.doc('stats', 'summary');
      final statsSnap = await tx.get(statsRef);

      final projectId = inv.projectId;
      DocumentReference<Json>? projRef;
      DocumentSnapshot<Json>? projSnap;
      if (projectId != null && projectId.isNotEmpty) {
        projRef = _p.doc('project_stats', projectId);
        projSnap = await tx.get(projRef);
      }

      // ============================ YAZMALAR ================================
      final sBal = balanceSign(inv.type);
      final deltaBal = -sBal * inv.totalMinor;
      final newBal = oldBal + deltaBal;
      tx.update(partyRef, {
        'balanceMinor': newBal,
        'lastTxId': txId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(_p.doc('ledger_entries', '${txId}_${inv.partyId}'), {
        'companyId': _cid,
        'txId': txId,
        'partyId': inv.partyId,
        'deltaMinor': deltaBal,
        'refType': 'reversal',
        'refId': invoiceId,
        'description': inv.number ?? '',
        'date': todayIso(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Ters stok hareketleri (ortalama maliyet degismez — bkz. PROGRESS varsayim)
      final productDelta = <String, int>{};
      for (final e in reversals.entries) {
        final r = e.value;
        final cur = asInt(levelSnaps[e.key]!.data()?['qtyMilli']);
        tx.update(_p.doc('stock_levels', e.key), {
          'qtyMilli': cur + r.delta,
          'lastTxId': txId,
        });
        tx.set(_p.doc('stock_movements', '${txId}_${e.key}'), {
          'companyId': _cid,
          'txId': txId,
          'productId': r.productId,
          'warehouseId': r.warehouseId,
          'deltaMilli': r.delta,
          'type': r.delta > 0 ? 'return_in' : 'return_out',
          'unitCostMinor': r.unitCost,
          'refType': 'invoice_cancel',
          'refId': invoiceId,
          'date': todayIso(),
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        productDelta[r.productId] = (productDelta[r.productId] ?? 0) + r.delta;
      }
      for (final e in productDelta.entries) {
        final prod = products[e.key];
        if (prod == null) continue;
        tx.update(_p.doc('products', e.key), {
          'totalQtyMilli': prod.totalQtyMilli + e.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Proje + ozet istatistik: kesmenin tersi
      final taxable = inv.subtotalMinor - inv.discountMinor;
      final rev = -_revenueDelta(inv.type, taxable);
      final cost = -_costDelta(inv.type, taxable);
      if (projRef != null) {
        tx.set(
          projRef,
          buildProjectStatsWrite(
            current: projSnap!.data(),
            companyId: _cid,
            txId: txId,
            revenueDelta: rev,
            costDelta: cost,
            discipline: inv.costCategory,
            disciplineDelta: cost,
          ),
          SetOptions(merge: true),
        );
      }
      final contrib = partyContribution(oldBal, newBal);
      tx.set(
        statsRef,
        buildSummaryWrite(
          current: statsSnap.data(),
          companyId: _cid,
          receivableDelta: contrib.receivable,
          payableDelta: contrib.payable,
          monthKey: monthKey(inv.issueDate),
          incomeDelta: rev,
          expenseDelta: cost,
        ),
        SetOptions(merge: true),
      );

      // Fatura: yalniz izinli alanlar (firestore.rules changedOnly)
      tx.update(invRef, {
        'status': 'cancelled',
        'paymentStatus': 'void',
        'cancelTxId': txId,
        'lastTxId': txId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(txRef, {
        'companyId': _cid,
        'type': 'invoice_cancel',
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'refs': {'invoiceId': invoiceId, 'partyId': inv.partyId},
      });
      tx.set(_p.doc('audit_logs', newId()), {
        'companyId': _cid,
        'action': 'invoice.cancel',
        'entityType': 'invoice',
        'entityId': invoiceId,
        'userId': uid,
        'at': FieldValue.serverTimestamp(),
        'summary': '${inv.number ?? invoiceId} ${formatMinorTry(inv.totalMinor)}',
      });
    }));
  }

  // ------------------------------------------------------------- yardimcilar

  /// Aylik gelir / proje geliri katkisi: sales +, sales_return - (KDV haric).
  static int _revenueDelta(String type, int taxable) => switch (type) {
        'sales' => taxable,
        'sales_return' => -taxable,
        _ => 0,
      };

  /// Aylik gider / proje maliyeti katkisi: purchase +, purchase_return -.
  static int _costDelta(String type, int taxable) => switch (type) {
        'purchase' => taxable,
        'purchase_return' => -taxable,
        _ => 0,
      };
}

final invoiceServiceProvider = Provider.autoDispose<InvoiceService>((ref) {
  return InvoiceService(
    db: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    paths: ref.watch(companyPathsProvider),
    profile: () => ref.read(userProfileProvider).valueOrNull,
  );
});
