import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/date/date_utils.dart';
import '../../core/money/money.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/date_field.dart' show addDaysIso;
import '../../data/models/expense.dart';
import '../../data/models/invoice.dart';
import '../../data/models/payment.dart';
import '../../data/models/summary.dart';
import '../../data/repositories/summary_repository.dart';

/// Genel Bakis (docs/08 §2-§3): kartlar, net pozisyon, 12 aylik grafik, listeler.
class DashboardSection extends ConsumerWidget {
  const DashboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final sum = ref.watch(summaryProvider).valueOrNull ?? const Summary();
    final now = monthKey(todayIso());
    final cur = sum.month(now);
    final prev = sum.month(shiftMonth(now, -1));

    Widget card(String label, int minor, {int? change, bool hasChange = false, VoidCallback? onTap}) {
      String? chg;
      if (hasChange) chg = change == null ? '—' : formatBp(change);
      return Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(t.spacing('md')),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: t.fontSize('caption'), color: t.color('textSecondary'))),
              SizedBox(height: t.spacing('xs')),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: MoneyText(minor,
                    style: TextStyle(fontSize: t.fontSize('bodyLg'), fontWeight: t.fontWeight('bold'))),
              ),
              if (chg != null)
                Text(chg,
                    style: TextStyle(
                      fontSize: t.fontSize('caption'),
                      color: change == null
                          ? t.color('textSecondary')
                          : t.color(change >= 0 ? 'positive' : 'negative'),
                    )),
            ]),
          ),
        ),
      );
    }

    int? chgOf(int a, int b) => changeBp(a, b, roundHalfUp);

    final months = [for (var i = 11; i >= 0; i--) shiftMonth(now, -i)];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.1,
        mainAxisSpacing: t.spacing('sm'),
        crossAxisSpacing: t.spacing('sm'),
        children: [
          card(s('dashboard.totalCash'), sum.cashMinor, onTap: () => context.push('/accounts')),
          card(s('dashboard.totalBank'), sum.bankMinor, onTap: () => context.push('/accounts')),
          card(s('dashboard.totalReceivable'), sum.receivableMinor),
          card(s('dashboard.totalPayable'), sum.payableMinor),
          card(s('dashboard.monthIncome'), cur.income,
              hasChange: true, change: chgOf(cur.income, prev.income)),
          card(s('dashboard.monthExpense'), cur.expense,
              hasChange: true, change: chgOf(cur.expense, prev.expense)),
        ],
      ),
      Card(
        child: ListTile(
          title: Text(s('dashboard.netPosition')),
          trailing: MoneyText(sum.netPosition,
              signed: true, style: TextStyle(fontWeight: t.fontWeight('bold'))),
        ),
      ),
      SizedBox(height: t.spacing('sm')),
      Text(s('dashboard.incomeExpenseChart'),
          style: TextStyle(fontWeight: t.fontWeight('semibold'))),
      SizedBox(height: t.spacing('sm')),
      SizedBox(
        height: 150,
        child: CustomPaint(
          painter: _BarsPainter(
            months: months,
            a: [for (final m in months) sum.month(m).income],
            b: [for (final m in months) sum.month(m).expense],
            colorA: t.color('positive'),
            colorB: t.color('negative'),
            labelColor: t.color('textSecondary'),
          ),
          size: Size.infinite,
        ),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _Legend(color: t.color('positive'), label: s('report.income')),
        SizedBox(width: t.spacing('lg')),
        _Legend(color: t.color('negative'), label: s('report.expense')),
      ]),
      SizedBox(height: t.spacing('lg')),
      const _DueLists(),
      SizedBox(height: t.spacing('lg')),
      const _RecentList(),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]);
}

/// Yan yana sutunlar; en buyuk degere gore olceklenir (negatif degerler 0'a kirpilir).
class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.months,
    required this.a,
    required this.b,
    required this.colorA,
    required this.colorB,
    required this.labelColor,
  });
  final List<String> months;
  final List<int> a;
  final List<int> b;
  final Color colorA;
  final Color colorB;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = [...a, ...b].fold<int>(1, (p, v) => v > p ? v : p);
    const labelH = 16.0;
    final h = size.height - labelH;
    final slot = size.width / months.length;
    final bw = slot * 0.32;
    for (var i = 0; i < months.length; i++) {
      final x = i * slot + slot / 2;
      void bar(int v, double dx, Color c) {
        final bh = v <= 0 ? 0.0 : h * v / maxV;
        canvas.drawRect(Rect.fromLTWH(x + dx, h - bh, bw, bh), Paint()..color = c);
      }

      bar(a[i], -bw, colorA);
      bar(b[i], 0, colorB);
      final tp = TextPainter(
        text: TextSpan(
          text: months[i].substring(5),
          style: TextStyle(fontSize: 10, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, h + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => old.a != a || old.b != b || old.months != months;
}

/// Yaklasan odemeler / tahsilatlar (30 gun) ve gecikmis satis faturalari.
class _DueLists extends ConsumerWidget {
  const _DueLists();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final open = ref.watch(openInvoicesProvider).valueOrNull ?? const <Invoice>[];
    final today = todayIso();
    final limit = addDaysIso(today, 30);
    bool upcoming(Invoice i) => i.dueDate.compareTo(today) >= 0 && i.dueDate.compareTo(limit) <= 0;
    bool late(Invoice i) => i.dueDate.compareTo(today) < 0;
    final base = open.where((i) => i.isIssued && (i.type == 'sales' || i.type == 'purchase'));
    final payables = base.where((i) => i.type == 'purchase' && (upcoming(i) || late(i))).toList();
    final collects = base.where((i) => i.type == 'sales' && upcoming(i)).toList();
    final overdue = base.where((i) => i.type == 'sales' && late(i)).toList();

    Widget section(String title, List<Invoice> list) {
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: EdgeInsets.only(top: t.spacing('md'), bottom: t.spacing('xs')),
          child: Text(title, style: TextStyle(fontWeight: t.fontWeight('semibold'))),
        ),
        for (final i in list)
          Card(
            child: ListTile(
              dense: true,
              title: Text('${i.partyName} · ${i.number ?? ''}'),
              subtitle: Text(i.dueDate),
              trailing: MoneyText(i.remainingMinor,
                  style: TextStyle(color: late(i) ? t.color('negative') : null)),
              onTap: () => context.push('/invoices/${i.id}'),
            ),
          ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      section(s('dashboard.upcoming'), payables),
      section(s('dashboard.upcomingCollections'), collects),
      section(s('dashboard.overdue'), overdue),
    ]);
  }
}

class _RecentList extends ConsumerWidget {
  const _RecentList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final inv = ref.watch(recentInvoicesProvider).valueOrNull ?? const <Invoice>[];
    final pay = ref.watch(recentPaymentsProvider).valueOrNull ?? const <Payment>[];
    final exp = ref.watch(recentExpensesProvider).valueOrNull ?? const <Expense>[];
    final rows = <({DateTime at, String label, String sub, int minor, String route})>[
      for (final i in inv)
        (
          at: i.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          label: s('invoiceType.${i.type}'),
          sub: i.partyName,
          minor: i.totalMinor,
          route: '/invoices/${i.id}',
        ),
      for (final p in pay)
        (
          at: p.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          label: s(p.isIn ? 'payment.in' : 'payment.out'),
          sub: p.partyName,
          minor: p.amountMinor,
          route: '/payments/${p.id}',
        ),
      for (final e in exp)
        (
          at: e.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          label: s('quickActions.expense'),
          sub: s('expenseCategory.${e.categoryId}'),
          minor: e.amountMinor,
          route: '/expenses',
        ),
    ]..sort((x, y) => y.at.compareTo(x.at));
    final top = rows.take(10).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s('dashboard.recent'), style: TextStyle(fontWeight: t.fontWeight('semibold'))),
      SizedBox(height: t.spacing('xs')),
      for (final r in top)
        Card(
          child: ListTile(
            dense: true,
            title: Text(r.label),
            subtitle: Text(r.sub),
            trailing: MoneyText(r.minor),
            onTap: () => context.push(r.route),
          ),
        ),
    ]);
  }
}
