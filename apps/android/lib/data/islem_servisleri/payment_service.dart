import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/date/date_utils.dart';
import '../../core/money/money.dart';
import '../firestore_paths.dart';
import '../models/account.dart';
import '../models/invoice.dart';
import '../models/payment.dart';
import '../write_helpers.dart';
import 'stats_helpers.dart';
import 'tx_errors.dart';

/// Islem sonucu: kullaniciya uyari gosterilecek durumlar (docs/04 §6).
class PaymentResult {
  const PaymentResult({required this.id, this.accountNegative = false});

  final String id;

  /// Hesap bakiyesi eksiye dustu (reddedilmez, uyari gosterilir).
  final bool accountNegative;
}

String paymentStatusFor(int paidMinor, int totalMinor) {
  if (paidMinor <= 0) return 'unpaid';
  return paidMinor >= totalMinor ? 'paid' : 'partial';
}

/// Tahsilat/odeme, iptal, hesap transferi ve hesap acilisi (docs/04 §5-§7).
/// Hepsi tek `runTransaction`; yetki `finance.write`; yalniz cevrimiciyken.
class PaymentService {
  PaymentService({
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
    if (p == null || !p.can('finance.write')) {
      throw const TxException('noPermission');
    }
  }

  // ------------------------------------------------------- tahsilat / odeme

  /// docs/04 §5. [direction]: `in` tahsilat, `out` odeme.
  Future<PaymentResult> recordPayment({
    required String txId,
    required String direction,
    required String partyId,
    required String accountId,
    required int amountMinor,
    required String date,
    required String method,
    required List<PaymentAllocation> allocations,
    String note = '',
  }) async {
    _requirePermission();
    final uid = _uid();
    if (direction != 'in' && direction != 'out') {
      throw const TxException('invalidState');
    }
    if (amountMinor <= 0) throw const TxException('invalidAmount');
    if (parseIsoDate(date) == null) throw const TxException('invalidDates');
    if (partyId.isEmpty) throw const TxException('partyRequired');
    if (accountId.isEmpty) throw const TxException('accountRequired');
    final ids = <String>{};
    var allocated = 0;
    for (final a in allocations) {
      if (a.amountMinor <= 0 || !ids.add(a.invoiceId)) {
        throw const TxException('invalidAllocation');
      }
      allocated += a.amountMinor;
    }
    if (allocated > amountMinor) throw const TxException('overAllocated');

    final isIn = direction == 'in';
    final paymentId = newId();

    return withAbortRetry(() => _db.runTransaction<PaymentResult>((tx) async {
          // ===================== OKUMALAR ===================================
          final txRef = _p.doc('txns', txId);
          if ((await tx.get(txRef)).exists) {
            throw const TxException('alreadyProcessed');
          }
          final accRef = _p.doc('accounts', accountId);
          final accSnap = await tx.get(accRef);
          if (!accSnap.exists) throw const TxException('accountNotFound');
          final acc = Account.fromDoc(accSnap);
          if (!acc.active) throw const TxException('accountInactive');

          final partyRef = _p.doc('parties', partyId);
          final partySnap = await tx.get(partyRef);
          if (!partySnap.exists) throw const TxException('partyNotFound');
          final oldBal = asInt(partySnap.data()!['balanceMinor']);

          final invoices = <String, Invoice>{};
          for (final a in allocations) {
            final snap = await tx.get(_p.doc('invoices', a.invoiceId));
            if (!snap.exists) throw const TxException('invoiceNotFound');
            final inv = Invoice.fromDoc(snap);
            if (!inv.isIssued) throw const TxException('invalidState');
            if (inv.partyId != partyId) throw const TxException('partyMismatch');
            if (isReceivableType(inv.type) != isIn) {
              throw const TxException('directionMismatch');
            }
            if (a.amountMinor > inv.remainingMinor) {
              throw TxException('overAllocated', {'number': inv.number ?? ''});
            }
            invoices[inv.id] = inv;
          }

          // Proje bazinda dagitim toplami
          final byProject = <String, int>{};
          for (final a in allocations) {
            final pid = invoices[a.invoiceId]!.projectId;
            if (pid != null && pid.isNotEmpty) {
              byProject[pid] = (byProject[pid] ?? 0) + a.amountMinor;
            }
          }
          final projSnaps = <String, DocumentSnapshot<Json>>{};
          for (final pid in byProject.keys) {
            projSnaps[pid] = await tx.get(_p.doc('project_stats', pid));
          }

          final statsRef = _p.doc('stats', 'summary');
          final statsSnap = await tx.get(statsRef);

          // ===================== YAZMALAR ===================================
          tx.set(_p.doc('payments', paymentId), {
            'companyId': _cid,
            'txId': txId,
            'direction': direction,
            'partyId': partyId,
            'accountId': accountId,
            'amountMinor': amountMinor,
            'date': date,
            'method': method,
            'allocations': [for (final a in allocations) a.toMap()],
            'unallocatedMinor': amountMinor - allocated,
            'note': note.trim(),
            'status': 'active',
            'createdBy': uid,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Hesap
          final accDelta = isIn ? amountMinor : -amountMinor;
          tx.update(accRef, {
            'balanceMinor': acc.balanceMinor + accDelta,
            'lastTxId': txId,
          });
          tx.set(_p.doc('account_movements', '${txId}_$accountId'), {
            'companyId': _cid,
            'txId': txId,
            'accountId': accountId,
            'deltaMinor': accDelta,
            'kind': isIn ? 'in' : 'out',
            'refType': 'payment',
            'refId': paymentId,
            'date': date,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Cari + ledger
          final partyDelta = isIn ? -amountMinor : amountMinor;
          final newBal = oldBal + partyDelta;
          tx.update(partyRef, {
            'balanceMinor': newBal,
            'lastTxId': txId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.set(_p.doc('ledger_entries', '${txId}_$partyId'), {
            'companyId': _cid,
            'txId': txId,
            'partyId': partyId,
            'deltaMinor': partyDelta,
            'refType': 'payment',
            'refId': paymentId,
            'description': note.trim(),
            'date': date,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Faturalar
          for (final a in allocations) {
            final inv = invoices[a.invoiceId]!;
            final paid = inv.paidMinor + a.amountMinor;
            tx.update(_p.doc('invoices', inv.id), {
              'paidMinor': paid,
              'paymentStatus': paymentStatusFor(paid, inv.totalMinor),
              'lastTxId': txId,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          // Proje
          for (final e in byProject.entries) {
            tx.set(
              _p.doc('project_stats', e.key),
              buildProjectStatsWrite(
                current: projSnaps[e.key]!.data(),
                companyId: _cid,
                txId: txId,
                collectedDelta: isIn ? e.value : 0,
                paidOutDelta: isIn ? 0 : e.value,
              ),
              SetOptions(merge: true),
            );
          }

          // Ozet
          final contrib = partyContribution(oldBal, newBal);
          tx.set(
            statsRef,
            buildSummaryWrite(
              current: statsSnap.data(),
              companyId: _cid,
              receivableDelta: contrib.receivable,
              payableDelta: contrib.payable,
              cashDelta: acc.isCash ? accDelta : 0,
              bankDelta: acc.isBank ? accDelta : 0,
              monthKey: monthKey(date),
              inDelta: isIn ? amountMinor : 0,
              outDelta: isIn ? 0 : amountMinor,
            ),
            SetOptions(merge: true),
          );

          tx.set(txRef, {
            'companyId': _cid,
            'type': 'payment_record',
            'createdBy': uid,
            'createdAt': FieldValue.serverTimestamp(),
            'refs': {'paymentId': paymentId, 'partyId': partyId, 'accountId': accountId},
          });
          tx.set(_p.doc('audit_logs', 'a_$txId'), {
            'companyId': _cid,
            'action': isIn ? 'payment.in' : 'payment.out',
            'entityType': 'payment',
            'entityId': paymentId,
            'userId': uid,
            'at': FieldValue.serverTimestamp(),
            'summary': formatMinorTry(amountMinor),
          });

          return PaymentResult(
            id: paymentId,
            accountNegative: acc.balanceMinor + accDelta < 0,
          );
        }));
  }

  /// docs/04 §6: kayit isleminin tersi; hesap eksiye dusebilir (uyari doner).
  Future<PaymentResult> cancelPayment(String paymentId, String txId) async {
    _requirePermission();
    final uid = _uid();

    return withAbortRetry(() => _db.runTransaction<PaymentResult>((tx) async {
          // ===================== OKUMALAR ===================================
          final txRef = _p.doc('txns', txId);
          if ((await tx.get(txRef)).exists) {
            throw const TxException('alreadyProcessed');
          }
          final payRef = _p.doc('payments', paymentId);
          final paySnap = await tx.get(payRef);
          if (!paySnap.exists) throw const TxException('paymentNotFound');
          final pay = Payment.fromDoc(paySnap);
          if (pay.isCancelled) throw const TxException('invalidState');
          final isIn = pay.isIn;

          final accRef = _p.doc('accounts', pay.accountId);
          final accSnap = await tx.get(accRef);
          if (!accSnap.exists) throw const TxException('accountNotFound');
          final acc = Account.fromDoc(accSnap);

          final partyRef = _p.doc('parties', pay.partyId);
          final partySnap = await tx.get(partyRef);
          if (!partySnap.exists) throw const TxException('partyNotFound');
          final oldBal = asInt(partySnap.data()!['balanceMinor']);

          final invoices = <String, Invoice>{};
          for (final a in pay.allocations) {
            final snap = await tx.get(_p.doc('invoices', a.invoiceId));
            if (snap.exists) invoices[a.invoiceId] = Invoice.fromDoc(snap);
          }
          final byProject = <String, int>{};
          for (final a in pay.allocations) {
            final pid = invoices[a.invoiceId]?.projectId;
            if (pid != null && pid.isNotEmpty) {
              byProject[pid] = (byProject[pid] ?? 0) + a.amountMinor;
            }
          }
          final projSnaps = <String, DocumentSnapshot<Json>>{};
          for (final pid in byProject.keys) {
            projSnaps[pid] = await tx.get(_p.doc('project_stats', pid));
          }
          final statsRef = _p.doc('stats', 'summary');
          final statsSnap = await tx.get(statsRef);

          // ===================== YAZMALAR ===================================
          final today = todayIso();
          tx.update(payRef, {
            'status': 'cancelled',
            'cancelTxId': txId,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final accDelta = isIn ? -pay.amountMinor : pay.amountMinor;
          tx.update(accRef, {
            'balanceMinor': acc.balanceMinor + accDelta,
            'lastTxId': txId,
          });
          tx.set(_p.doc('account_movements', '${txId}_${pay.accountId}'), {
            'companyId': _cid,
            'txId': txId,
            'accountId': pay.accountId,
            'deltaMinor': accDelta,
            'kind': isIn ? 'out' : 'in',
            'refType': 'reversal',
            'refId': paymentId,
            'date': today,
            'createdAt': FieldValue.serverTimestamp(),
          });

          final partyDelta = isIn ? pay.amountMinor : -pay.amountMinor;
          final newBal = oldBal + partyDelta;
          tx.update(partyRef, {
            'balanceMinor': newBal,
            'lastTxId': txId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.set(_p.doc('ledger_entries', '${txId}_${pay.partyId}'), {
            'companyId': _cid,
            'txId': txId,
            'partyId': pay.partyId,
            'deltaMinor': partyDelta,
            'refType': 'reversal',
            'refId': paymentId,
            'description': pay.note,
            'date': today,
            'createdAt': FieldValue.serverTimestamp(),
          });

          for (final a in pay.allocations) {
            final inv = invoices[a.invoiceId];
            if (inv == null || !inv.isIssued) continue;
            final paid = inv.paidMinor - a.amountMinor;
            tx.update(_p.doc('invoices', inv.id), {
              'paidMinor': paid < 0 ? 0 : paid,
              'paymentStatus': paymentStatusFor(paid, inv.totalMinor),
              'lastTxId': txId,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          for (final e in byProject.entries) {
            tx.set(
              _p.doc('project_stats', e.key),
              buildProjectStatsWrite(
                current: projSnaps[e.key]!.data(),
                companyId: _cid,
                txId: txId,
                collectedDelta: isIn ? -e.value : 0,
                paidOutDelta: isIn ? 0 : -e.value,
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
              cashDelta: acc.isCash ? accDelta : 0,
              bankDelta: acc.isBank ? accDelta : 0,
              // Ters kayit ORIJINAL odemenin ayina yazilir (docs/08 §1).
              monthKey: monthKey(pay.date),
              inDelta: isIn ? -pay.amountMinor : 0,
              outDelta: isIn ? 0 : -pay.amountMinor,
            ),
            SetOptions(merge: true),
          );

          tx.set(txRef, {
            'companyId': _cid,
            'type': 'payment_cancel',
            'createdBy': uid,
            'createdAt': FieldValue.serverTimestamp(),
            'refs': {'paymentId': paymentId, 'partyId': pay.partyId},
          });
          tx.set(_p.doc('audit_logs', 'a_$txId'), {
            'companyId': _cid,
            'action': 'payment.cancel',
            'entityType': 'payment',
            'entityId': paymentId,
            'userId': uid,
            'at': FieldValue.serverTimestamp(),
            'summary': formatMinorTry(pay.amountMinor),
          });

          return PaymentResult(
            id: paymentId,
            accountNegative: acc.balanceMinor + accDelta < 0,
          );
        }));
  }

  // ---------------------------------------------------- hesaplar arasi transfer

  /// docs/04 §7: gelir/gider DEGIL; yalniz iki hesap bakiyesi ve kasa/banka toplami.
  Future<PaymentResult> transfer({
    required String txId,
    required String fromAccountId,
    required String toAccountId,
    required int amountMinor,
    required String date,
    String note = '',
  }) async {
    _requirePermission();
    final uid = _uid();
    if (amountMinor <= 0) throw const TxException('invalidAmount');
    if (fromAccountId == toAccountId) throw const TxException('sameAccount');
    if (parseIsoDate(date) == null) throw const TxException('invalidDates');

    return withAbortRetry(() => _db.runTransaction<PaymentResult>((tx) async {
          final txRef = _p.doc('txns', txId);
          if ((await tx.get(txRef)).exists) {
            throw const TxException('alreadyProcessed');
          }
          final fromRef = _p.doc('accounts', fromAccountId);
          final toRef = _p.doc('accounts', toAccountId);
          final fromSnap = await tx.get(fromRef);
          final toSnap = await tx.get(toRef);
          if (!fromSnap.exists || !toSnap.exists) {
            throw const TxException('accountNotFound');
          }
          final from = Account.fromDoc(fromSnap);
          final to = Account.fromDoc(toSnap);
          if (!from.active || !to.active) throw const TxException('accountInactive');
          final statsRef = _p.doc('stats', 'summary');
          final statsSnap = await tx.get(statsRef);

          tx.update(fromRef, {
            'balanceMinor': from.balanceMinor - amountMinor,
            'lastTxId': txId,
          });
          tx.update(toRef, {
            'balanceMinor': to.balanceMinor + amountMinor,
            'lastTxId': txId,
          });
          Json movement(String accountId, int delta, String kind) => {
                'companyId': _cid,
                'txId': txId,
                'accountId': accountId,
                'deltaMinor': delta,
                'kind': kind,
                'refType': 'transfer',
                'refId': '',
                'date': date,
                'createdAt': FieldValue.serverTimestamp(),
              };
          tx.set(
            _p.doc('account_movements', '${txId}_$fromAccountId'),
            movement(fromAccountId, -amountMinor, 'transfer_out'),
          );
          tx.set(
            _p.doc('account_movements', '${txId}_$toAccountId'),
            movement(toAccountId, amountMinor, 'transfer_in'),
          );

          // Kasa/banka toplami: ayni tur arasinda net 0; farkli turde kayar.
          var cash = 0, bank = 0;
          if (from.isCash) cash -= amountMinor; else bank -= amountMinor;
          if (to.isCash) cash += amountMinor; else bank += amountMinor;
          tx.set(
            statsRef,
            buildSummaryWrite(
              current: statsSnap.data(),
              companyId: _cid,
              cashDelta: cash,
              bankDelta: bank,
            ),
            SetOptions(merge: true),
          );

          tx.set(txRef, {
            'companyId': _cid,
            'type': 'account_transfer',
            'createdBy': uid,
            'createdAt': FieldValue.serverTimestamp(),
            'refs': {'fromAccountId': fromAccountId, 'toAccountId': toAccountId},
          });
          tx.set(_p.doc('audit_logs', 'a_$txId'), {
            'companyId': _cid,
            'action': 'account.transfer',
            'entityType': 'account',
            'entityId': fromAccountId,
            'userId': uid,
            'at': FieldValue.serverTimestamp(),
            'summary':
                '${from.name} → ${to.name} ${formatMinorTry(amountMinor)}${note.trim().isEmpty ? '' : ' · ${note.trim()}'}',
          });

          return PaymentResult(
            id: txId,
            accountNegative: from.balanceMinor - amountMinor < 0,
          );
        }));
  }

  // ------------------------------------------------------------- hesap acilisi

  /// Yeni hesap. [openingMinor] > 0 ise acilis bakiyesi hareketle (`refType='opening'`)
  /// birlikte, tek islemde yazilir; 0 ise duz kayit (cevrimdisi da kuyruga alinir).
  Future<({String id, bool synced})> createAccount(
    Account a, {
    int openingMinor = 0,
    required String txId,
  }) async {
    _requirePermission();
    final uid = _uid();
    if (openingMinor < 0) throw const TxException('invalidAmount');
    final id = newId();
    final ref = _p.doc('accounts', id);

    if (openingMinor == 0) {
      final synced = await writeOrQueue(ref.set({
        ...a.masterFields(),
        'companyId': _cid,
        'balanceMinor': 0,
        'lastTxId': '',
        'createdAt': FieldValue.serverTimestamp(),
      }));
      return (id: id, synced: synced);
    }

    final date = todayIso();
    await withAbortRetry(() => _db.runTransaction<void>((tx) async {
          final txRef = _p.doc('txns', txId);
          if ((await tx.get(txRef)).exists) {
            throw const TxException('alreadyProcessed');
          }
          final statsRef = _p.doc('stats', 'summary');
          final statsSnap = await tx.get(statsRef);

          tx.set(ref, {
            ...a.masterFields(),
            'companyId': _cid,
            'balanceMinor': openingMinor,
            'lastTxId': txId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.set(_p.doc('account_movements', '${txId}_$id'), {
            'companyId': _cid,
            'txId': txId,
            'accountId': id,
            'deltaMinor': openingMinor,
            'kind': 'in',
            'refType': 'opening',
            'refId': '',
            'date': date,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.set(
            statsRef,
            buildSummaryWrite(
              current: statsSnap.data(),
              companyId: _cid,
              cashDelta: a.isCash ? openingMinor : 0,
              bankDelta: a.isBank ? openingMinor : 0,
            ),
            SetOptions(merge: true),
          );
          tx.set(txRef, {
            'companyId': _cid,
            'type': 'account_opening',
            'createdBy': uid,
            'createdAt': FieldValue.serverTimestamp(),
            'refs': {'accountId': id},
          });
          tx.set(_p.doc('audit_logs', 'a_$txId'), {
            'companyId': _cid,
            'action': 'account.open',
            'entityType': 'account',
            'entityId': id,
            'userId': uid,
            'at': FieldValue.serverTimestamp(),
            'summary': '${a.name} ${formatMinorTry(openingMinor)}',
          });
        }));
    return (id: id, synced: true);
  }

  /// Ana veri guncelleme (bakiye/`lastTxId` degismez).
  Future<bool> updateAccount(Account a) {
    _requirePermission();
    return writeOrQueue(_p.doc('accounts', a.id).update({
      ...a.masterFields(),
      'updatedAt': FieldValue.serverTimestamp(),
    }));
  }
}

final paymentServiceProvider = Provider.autoDispose<PaymentService>((ref) {
  return PaymentService(
    db: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    paths: ref.watch(companyPathsProvider),
    profile: () => ref.read(userProfileProvider).valueOrNull,
  );
});
