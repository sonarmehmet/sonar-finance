import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';

class MonthStat {
  const MonthStat({this.income = 0, this.expense = 0, this.inMinor = 0, this.outMinor = 0});
  final int income;
  final int expense;
  final int inMinor;
  final int outMinor;
  int get net => income - expense;
  int get cashNet => inMinor - outMinor;
}

/// `stats/summary` (docs/08 §1).
class Summary {
  const Summary({
    this.receivableMinor = 0,
    this.payableMinor = 0,
    this.cashMinor = 0,
    this.bankMinor = 0,
    this.months = const {},
  });

  final int receivableMinor;
  final int payableMinor;
  final int cashMinor;
  final int bankMinor;
  final Map<String, MonthStat> months;

  /// Net finansal pozisyon (docs/08 §2).
  int get netPosition => cashMinor + bankMinor + receivableMinor - payableMinor;

  MonthStat month(String key) => months[key] ?? const MonthStat();

  factory Summary.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final m = <String, MonthStat>{};
    for (final e in ((d['months'] as Map?) ?? const {}).entries) {
      final v = (e.value as Map).cast<String, dynamic>();
      m[e.key as String] = MonthStat(
        income: asInt(v['incomeMinor']),
        expense: asInt(v['expenseMinor']),
        inMinor: asInt(v['inMinor']),
        outMinor: asInt(v['outMinor']),
      );
    }
    return Summary(
      receivableMinor: asInt(d['receivableMinor']),
      payableMinor: asInt(d['payableMinor']),
      cashMinor: asInt(d['cashMinor']),
      bankMinor: asInt(d['bankMinor']),
      months: m,
    );
  }
}

/// Onceki aya gore degisim, baz puan (1 ondalik icin 10'a yuvarlanir); onceki 0 ise null ("—").
int? changeBp(int current, int previous, int Function(int, int) roundHalfUp) {
  if (previous == 0) return null;
  final bp = roundHalfUp((current - previous) * 10000, previous);
  return roundHalfUp(bp, 10) * 10;
}

/// `ay` anahtarini [delta] ay oteler: ('2026-11', -1) -> '2026-10'.
String shiftMonth(String key, int delta) {
  final y = int.parse(key.substring(0, 4));
  final m = int.parse(key.substring(5, 7));
  final idx = y * 12 + (m - 1) + delta;
  return '${(idx ~/ 12).toString().padLeft(4, '0')}-${(idx % 12 + 1).toString().padLeft(2, '0')}';
}
