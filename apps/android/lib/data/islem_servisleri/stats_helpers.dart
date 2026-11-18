import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';

int _recv(int b) => b > 0 ? b : 0;
int _pay(int b) => b < 0 ? -b : 0;

/// Cari bakiyesi `old -> new` olunca ozete katki (docs/04 §8):
/// `receivableMinor += recv(new)-recv(old)`, `payableMinor += pay(new)-pay(old)`.
({int receivable, int payable}) partyContribution(int oldBalance, int newBalance) => (
      receivable: _recv(newBalance) - _recv(oldBalance),
      payable: _pay(newBalance) - _pay(oldBalance),
    );

/// `stats/summary` icin `set(merge: true)` govdesi.
/// [current]: transaction icinde okunan mevcut belge verisi (yoksa `null`).
/// Ay haritasi yalniz [monthKey] verilirse yazilir.
Json buildSummaryWrite({
  required Json? current,
  required String companyId,
  int receivableDelta = 0,
  int payableDelta = 0,
  int cashDelta = 0,
  int bankDelta = 0,
  String? monthKey,
  int incomeDelta = 0,
  int expenseDelta = 0,
  int inDelta = 0,
  int outDelta = 0,
}) {
  final cur = current ?? const <String, dynamic>{};
  final out = <String, dynamic>{
    'companyId': companyId,
    'receivableMinor': asInt(cur['receivableMinor']) + receivableDelta,
    'payableMinor': asInt(cur['payableMinor']) + payableDelta,
    'cashMinor': asInt(cur['cashMinor']) + cashDelta,
    'bankMinor': asInt(cur['bankMinor']) + bankDelta,
    'updatedAt': FieldValue.serverTimestamp(),
  };
  if (monthKey != null &&
      (incomeDelta != 0 || expenseDelta != 0 || inDelta != 0 || outDelta != 0)) {
    final months = (cur['months'] as Map?)?.cast<String, dynamic>() ?? const {};
    final m = (months[monthKey] as Map?)?.cast<String, dynamic>() ?? const {};
    out['months'] = {
      monthKey: {
        'incomeMinor': asInt(m['incomeMinor']) + incomeDelta,
        'expenseMinor': asInt(m['expenseMinor']) + expenseDelta,
        'inMinor': asInt(m['inMinor']) + inDelta,
        'outMinor': asInt(m['outMinor']) + outDelta,
      },
    };
  }
  return out;
}

/// `project_stats/{projectId}` icin `set(merge: true)` govdesi (docs/04 §3, §5).
Json buildProjectStatsWrite({
  required Json? current,
  required String companyId,
  required String txId,
  int revenueDelta = 0,
  int costDelta = 0,
  int collectedDelta = 0,
  int paidOutDelta = 0,
  String? discipline,
  int disciplineDelta = 0,
}) {
  final cur = current ?? const <String, dynamic>{};
  final out = <String, dynamic>{
    'companyId': companyId,
    'revenueMinor': asInt(cur['revenueMinor']) + revenueDelta,
    'costMinor': asInt(cur['costMinor']) + costDelta,
    'collectedMinor': asInt(cur['collectedMinor']) + collectedDelta,
    'paidOutMinor': asInt(cur['paidOutMinor']) + paidOutDelta,
    'lastTxId': txId,
  };
  if (discipline != null && disciplineDelta != 0) {
    final by = (cur['byDiscipline'] as Map?)?.cast<String, dynamic>() ?? const {};
    out['byDiscipline'] = {discipline: asInt(by[discipline]) + disciplineDelta};
  }
  return out;
}
