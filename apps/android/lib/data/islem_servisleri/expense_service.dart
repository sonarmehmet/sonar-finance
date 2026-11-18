import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/date/date_utils.dart';
import '../../core/money/money.dart';
import '../firestore_paths.dart';
import '../models/account.dart';
import '../models/expense.dart';
import '../write_helpers.dart';
import 'payment_service.dart' show PaymentResult;
import 'stats_helpers.dart';
import 'tx_errors.dart';

/// docs/04 §7 Gider: `expenses` + hesap azalir + ozet (expense=net, out=brut)
/// + proje maliyeti (net) ve disiplin kirilimi. Tek transaction, cevrimdisi reddedilir.
class ExpenseService {
  ExpenseService({
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

  String _uid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const TxException('noPermission');
    return uid;
  }

  void _requirePermission() {
    final p = _profile();
    if (p == null || !p.can('finance.write')) throw const TxException('noPermission');
  }

  Future<PaymentResult> recordExpense({
    required String txId,
    required String categoryId,
    required int amountMinor,
    required int vatMinor,
    required String accountId,
    required String date,
    String? partyId,
    String? projectId,
    String? discipline,
    String description = '',
  }) async {
    _requirePermission();
    final uid = _uid();
    if (amountMinor <= 0) throw const TxException('invalidAmount');
    if (vatMinor < 0 || vatMinor > amountMinor) throw const TxException('invalidAmount');
    if (parseIsoDate(date) == null) throw const TxException('invalidDates');
    if (accountId.isEmpty) throw const TxException('accountRequired');
    final pid = (projectId ?? '').isEmpty ? null : projectId;
    final disc = pid == null || (discipline ?? '').isEmpty ? null : discipline;
    final expenseId = newId();
    final net = amountMinor - vatMinor;

    return withAbortRetry(() => _db.runTransaction<PaymentResult>((tx) async {
          // ===================== OKUMALAR ===================================
          final txRef = _p.doc('txns', txId);
          if ((await tx.get(txRef)).exists) throw const TxException('alreadyProcessed');
          final accRef = _p.doc('accounts', accountId);
          final accSnap = await tx.get(accRef);
          if (!accSnap.exists) throw const TxException('accountNotFound');
          final acc = Account.fromDoc(accSnap);
          if (!acc.active) throw const TxException('accountInactive');
          DocumentSnapshot<Json>? projSnap;
          if (pid != null) projSnap = await tx.get(_p.doc('project_stats', pid));
          final statsRef = _p.doc('stats', 'summary');
          final statsSnap = await tx.get(statsRef);

          // ===================== YAZMALAR ===================================
          tx.set(_p.doc('expenses', expenseId), {
            'companyId': _p.cid,
            'txId': txId,
            'categoryId': categoryId,
            'amountMinor': amountMinor,
            'vatMinor': vatMinor,
            'accountId': accountId,
            if (partyId != null && partyId.isNotEmpty) 'partyId': partyId,
            if (pid != null) 'projectId': pid,
            if (disc != null) 'discipline': disc,
            'date': date,
            'description': description.trim(),
            'status': 'active',
            'createdBy': uid,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.update(accRef, {
            'balanceMinor': acc.balanceMinor - amountMinor,
            'lastTxId': txId,
          });
          tx.set(_p.doc('account_movements', '${txId}_$accountId'), {
            'companyId': _p.cid,
            'txId': txId,
            'accountId': accountId,
            'deltaMinor': -amountMinor,
            'kind': 'expense',
            'refType': 'expense',
            'refId': expenseId,
            'date': date,
            'createdAt': FieldValue.serverTimestamp(),
          });
          if (pid != null) {
            tx.set(
              _p.doc('project_stats', pid),
              buildProjectStatsWrite(
                current: projSnap!.data(),
                companyId: _p.cid,
                txId: txId,
                costDelta: net,
                discipline: disc,
                disciplineDelta: net,
              ),
              SetOptions(merge: true),
            );
          }
          tx.set(
            statsRef,
            buildSummaryWrite(
              current: statsSnap.data(),
              companyId: _p.cid,
              cashDelta: acc.isCash ? -amountMinor : 0,
              bankDelta: acc.isBank ? -amountMinor : 0,
              monthKey: monthKey(date),
              expenseDelta: net,
              outDelta: amountMinor,
            ),
            SetOptions(merge: true),
          );
          tx.set(txRef, {
            'companyId': _p.cid,
            'type': 'expense_record',
            'createdBy': uid,
            'createdAt': FieldValue.serverTimestamp(),
            'refs': {'expenseId': expenseId, 'accountId': accountId},
          });
          tx.set(_p.doc('audit_logs', 'a_$txId'), {
            'companyId': _p.cid,
            'action': 'expense.create',
            'entityType': 'expense',
            'entityId': expenseId,
            'userId': uid,
            'at': FieldValue.serverTimestamp(),
            'summary': formatMinorTry(amountMinor),
          });
          return PaymentResult(
            id: expenseId,
            accountNegative: acc.balanceMinor - amountMinor < 0,
          );
        }));
  }

  /// Gider iptali: kaydin tersi (hesap artar, ozet/proje geri alinir).
  Future<PaymentResult> cancelExpense(String expenseId, String txId) async {
    _requirePermission();
    final uid = _uid();
    return withAbortRetry(() => _db.runTransaction<PaymentResult>((tx) async {
          final txRef = _p.doc('txns', txId);
          if ((await tx.get(txRef)).exists) throw const TxException('alreadyProcessed');
          final expRef = _p.doc('expenses', expenseId);
          final expSnap = await tx.get(expRef);
          if (!expSnap.exists) throw const TxException('expenseNotFound');
          final e = Expense.fromDoc(expSnap);
          if (e.isCancelled) throw const TxException('invalidState');
          final accRef = _p.doc('accounts', e.accountId);
          final accSnap = await tx.get(accRef);
          if (!accSnap.exists) throw const TxException('accountNotFound');
          final acc = Account.fromDoc(accSnap);
          final pid = e.projectId;
          DocumentSnapshot<Json>? projSnap;
          if (pid != null) projSnap = await tx.get(_p.doc('project_stats', pid));
          final statsRef = _p.doc('stats', 'summary');
          final statsSnap = await tx.get(statsRef);

          tx.update(expRef, {
            'status': 'cancelled',
            'cancelTxId': txId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.update(accRef, {
            'balanceMinor': acc.balanceMinor + e.amountMinor,
            'lastTxId': txId,
          });
          tx.set(_p.doc('account_movements', '${txId}_${e.accountId}'), {
            'companyId': _p.cid,
            'txId': txId,
            'accountId': e.accountId,
            'deltaMinor': e.amountMinor,
            'kind': 'in',
            'refType': 'reversal',
            'refId': expenseId,
            'date': todayIso(),
            'createdAt': FieldValue.serverTimestamp(),
          });
          if (pid != null) {
            tx.set(
              _p.doc('project_stats', pid),
              buildProjectStatsWrite(
                current: projSnap!.data(),
                companyId: _p.cid,
                txId: txId,
                costDelta: -e.netMinor,
                discipline: e.discipline,
                disciplineDelta: -e.netMinor,
              ),
              SetOptions(merge: true),
            );
          }
          tx.set(
            statsRef,
            buildSummaryWrite(
              current: statsSnap.data(),
              companyId: _p.cid,
              cashDelta: acc.isCash ? e.amountMinor : 0,
              bankDelta: acc.isBank ? e.amountMinor : 0,
              monthKey: monthKey(e.date),
              expenseDelta: -e.netMinor,
              outDelta: -e.amountMinor,
            ),
            SetOptions(merge: true),
          );
          tx.set(txRef, {
            'companyId': _p.cid,
            'type': 'expense_cancel',
            'createdBy': uid,
            'createdAt': FieldValue.serverTimestamp(),
            'refs': {'expenseId': expenseId},
          });
          tx.set(_p.doc('audit_logs', 'a_$txId'), {
            'companyId': _p.cid,
            'action': 'expense.cancel',
            'entityType': 'expense',
            'entityId': expenseId,
            'userId': uid,
            'at': FieldValue.serverTimestamp(),
            'summary': formatMinorTry(e.amountMinor),
          });
          return PaymentResult(id: expenseId);
        }));
  }
}

final expenseServiceProvider = Provider.autoDispose<ExpenseService>((ref) {
  return ExpenseService(
    db: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    paths: ref.watch(companyPathsProvider),
    profile: () => ref.read(userProfileProvider).valueOrNull,
  );
});
