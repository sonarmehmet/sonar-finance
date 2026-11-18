import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/date/date_utils.dart';
import '../../core/money/money.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/models/account.dart';
import '../../data/models/expense.dart';
import '../../data/models/invoice.dart';
import '../../data/models/ledger_entry.dart';
import '../../data/models/payment.dart';
import '../../data/models/product.dart';
import '../../data/models/stock_level.dart';
import '../../data/models/warehouse.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/warehouse_repository.dart';
import '../../data/models/party.dart';
import '../../data/models/project.dart';
import '../../data/models/summary.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/party_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/summary_repository.dart';
import 'reports_screen.dart' show copyCsv;

/// Tek rapor ekrani; [kind]: yearly | monthly | balances | cashbank | projects.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, required this.kind});
  final String kind;
  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late int _year = int.parse(todayIso().substring(0, 4));
  late String _month = monthKey(todayIso());
  String? _accountId;
  String? _partyId;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    Widget body;
    switch (widget.kind) {
      case 'yearly':
        body = _yearly();
      case 'monthly':
        body = _monthly();
      case 'balances':
        body = _balances();
      case 'cashbank':
        body = _cashbank();
      case 'vat':
        body = _vat();
      case 'stock':
        body = _stock();
      case 'collections':
        body = _payments('in');
      case 'payments':
        body = _payments('out');
      case 'ledger':
        body = _ledger();
      default:
        body = _projects();
    }
    return Scaffold(appBar: AppBar(title: Text(s('report.${widget.kind}'))), body: body);
  }

  // -- ortak tablo --------------------------------------------------------
  Widget _table(List<String> headers, List<List<String>> rows, {List<String>? total, Widget? top}) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final all = [headers, ...rows, if (total != null) total];
    return ListView(padding: EdgeInsets.all(t.screenPadding), children: [
      if (top != null) top,
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [for (var i = 0; i < headers.length; i++) DataColumn(label: Text(headers[i]), numeric: i > 0)],
          rows: [
            for (final r in rows) DataRow(cells: [for (final c in r) DataCell(Text(c))]),
            if (total != null)
              DataRow(cells: [
                for (final c in total) DataCell(Text(c, style: const TextStyle(fontWeight: FontWeight.w700))),
              ]),
          ],
        ),
      ),
      SizedBox(height: t.spacing('md')),
      OutlinedButton.icon(
        icon: const Icon(LucideIcons.copy),
        label: Text(s('report.copyCsv')),
        onPressed: () async {
          await copyCsv(all);
          if (mounted) showSuccess(context, ref, s('report.copied'));
        },
      ),
    ]);
  }

  // -- yillik -------------------------------------------------------------
  Widget _yearly() {
    final s = ref.watch(stringsProvider);
    final sum = ref.watch(summaryProvider).valueOrNull ?? const Summary();
    var inc = 0, exp = 0;
    final rows = <List<String>>[];
    for (var m = 1; m <= 12; m++) {
      final k = '$_year-${m.toString().padLeft(2, '0')}';
      final v = sum.month(k);
      inc += v.income;
      exp += v.expense;
      rows.add([k, formatMinor(v.income), formatMinor(v.expense), formatMinor(v.net)]);
    }
    return _table(
      [s('report.month'), s('report.income'), s('report.expense'), s('report.net')],
      rows,
      total: [s('report.total'), formatMinor(inc), formatMinor(exp), formatMinor(inc - exp)],
      top: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(LucideIcons.chevronLeft), onPressed: () => setState(() => _year--)),
        Text('$_year', style: const TextStyle(fontWeight: FontWeight.w700)),
        IconButton(icon: const Icon(LucideIcons.chevronRight), onPressed: () => setState(() => _year++)),
      ]),
    );
  }

  // -- aylik + karsilastirma ---------------------------------------------
  Widget _monthly() {
    final s = ref.watch(stringsProvider);
    final sum = ref.watch(summaryProvider).valueOrNull ?? const Summary();
    final a = sum.month(_month);
    final prevKey = shiftMonth(_month, -1);
    final b = sum.month(prevKey);
    String chg(int x, int y) {
      final c = changeBp(x, y, roundHalfUp);
      return c == null ? '—' : formatBp(c);
    }

    return _table(
      ['', _month, prevKey, s('report.change')],
      [
        [s('report.income'), formatMinor(a.income), formatMinor(b.income), chg(a.income, b.income)],
        [s('report.expense'), formatMinor(a.expense), formatMinor(b.expense), chg(a.expense, b.expense)],
        [s('report.net'), formatMinor(a.net), formatMinor(b.net), chg(a.net, b.net)],
      ],
      top: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: () => setState(() => _month = shiftMonth(_month, -1))),
        Text(_month, style: const TextStyle(fontWeight: FontWeight.w700)),
        IconButton(
            icon: const Icon(LucideIcons.chevronRight),
            onPressed: () => setState(() => _month = shiftMonth(_month, 1))),
      ]),
    );
  }

  // -- borc / alacak ------------------------------------------------------
  Widget _balances() {
    final s = ref.watch(stringsProvider);
    return AsyncBody<List<Party>>(
      value: ref.watch(partiesProvider),
      builder: (list) {
        var recv = 0, pay = 0;
        final rows = <List<String>>[];
        for (final p in list.where((p) => p.balanceMinor != 0)) {
          final r = p.balanceMinor > 0 ? p.balanceMinor : 0;
          final d = p.balanceMinor < 0 ? -p.balanceMinor : 0;
          recv += r;
          pay += d;
          rows.add([p.name, formatMinor(r), formatMinor(d), formatMinor(p.balanceMinor)]);
        }
        return _table(
          [s('report.party'), s('report.receivable'), s('report.payable'), s('report.net')],
          rows,
          total: [s('report.total'), formatMinor(recv), formatMinor(pay), formatMinor(recv - pay)],
        );
      },
    );
  }

  // -- kasa / banka -------------------------------------------------------
  Widget _cashbank() {
    final s = ref.watch(stringsProvider);
    final t = ref.watch(tokensProvider);
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
    if (accounts.isEmpty) return EmptyView(message: s('common.empty'));
    final acc = accounts.firstWhere((a) => a.id == _accountId, orElse: () => accounts.first);
    final moves = ref.watch(accountMovementsProvider(acc.id));
    final picker = Padding(
      padding: EdgeInsets.only(bottom: t.spacing('md')),
      child: DropdownButtonFormField<String>(
        value: acc.id,
        items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
        onChanged: (v) => setState(() => _accountId = v),
      ),
    );
    return moves.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (list) {
        // Liste yeniden eskiye; kapanis = guncel bakiye, geriye dogru bakiye yurutulur.
        var bal = acc.balanceMinor;
        final rows = <List<String>>[];
        for (final m in list) {
          final label = m.refType == 'payment' || m.refType == 'reversal' || m.refType == 'opening'
              ? s('move.${m.refType}')
              : s('move.${m.kind}');
          rows.add([
            m.date,
            label,
            m.deltaMinor > 0 ? formatMinor(m.deltaMinor) : '',
            m.deltaMinor < 0 ? formatMinor(-m.deltaMinor) : '',
            formatMinor(bal),
          ]);
          bal -= m.deltaMinor;
        }
        return _table(
          [s('report.date'), s('report.description'), s('report.in'), s('report.out'), s('report.balance')],
          rows,
          total: [s('report.closing'), '', '', '', formatMinor(acc.balanceMinor)],
          top: picker,
        );
      },
    );
  }

  // -- proje karliligi ----------------------------------------------------
  Widget _projects() {
    final s = ref.watch(stringsProvider);
    return AsyncBody<List<Project>>(
      value: ref.watch(projectsProvider),
      builder: (list) {
        final rows = <List<String>>[];
        for (final p in list) {
          final st = ref.watch(projectStatsProvider(p.id)).valueOrNull ?? const ProjectStats();
          final margin = st.revenueMinor == 0
              ? '—'
              : formatBp(roundHalfUp(st.profitMinor * 10000, st.revenueMinor));
          rows.add([
            p.name,
            formatMinor(p.contractMinor),
            formatMinor(st.revenueMinor),
            formatMinor(st.costMinor),
            formatMinor(p.estimatedProfit),
            formatMinor(st.profitMinor),
            margin,
          ]);
        }
        return _table(
          [
            s('report.project'),
            s('project.contract'),
            s('project.revenue'),
            s('project.cost'),
            s('project.estProfit'),
            s('project.actualProfit'),
            s('project.margin'),
          ],
          rows,
        );
      },
    );
  }

  Widget _monthPicker() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: () => setState(() => _month = shiftMonth(_month, -1))),
        Text(_month, style: const TextStyle(fontWeight: FontWeight.w700)),
        IconButton(
            icon: const Icon(LucideIcons.chevronRight),
            onPressed: () => setState(() => _month = shiftMonth(_month, 1))),
      ]);

  DateRange get _range => (from: '$_month-01', to: '$_month-31');

  // -- KDV ozeti (08 §6): hesaplanan - indirilecek, oran kirilimi ----------
  Widget _vat() {
    final s = ref.watch(stringsProvider);
    final inv = ref.watch(invoicesBetweenProvider(_range)).valueOrNull ?? const <Invoice>[];
    final exp = ref.watch(expensesBetweenProvider(_range)).valueOrNull ?? const <Expense>[];
    // oran (bp) -> [hesaplanan, indirilecek]
    final byRate = <int, List<int>>{};
    void add(int bp, int calc, int deduct) {
      final r = byRate.putIfAbsent(bp, () => [0, 0]);
      r[0] += calc;
      r[1] += deduct;
    }

    for (final i in inv.where((i) => i.isIssued)) {
      final sign = (i.type == 'sales' || i.type == 'purchase') ? 1 : -1;
      final sales = i.type == 'sales' || i.type == 'sales_return';
      for (final l in i.lines) {
        add(l.vatBp, sales ? sign * l.vatMinor : 0, sales ? 0 : sign * l.vatMinor);
      }
    }
    for (final e in exp.where((e) => !e.isCancelled)) {
      add(-1, 0, e.vatMinor); // gider KDV'si oran bilgisi tasimaz
    }
    var calc = 0, ded = 0;
    final rows = <List<String>>[];
    for (final k in byRate.keys.toList()..sort()) {
      final v = byRate[k]!;
      calc += v[0];
      ded += v[1];
      rows.add([k < 0 ? s('report.expense') : formatBp(k), formatMinor(v[0]), formatMinor(v[1])]);
    }
    return _table(
      [s('report.rate'), s('report.vatCalculated'), s('report.vatDeductible')],
      rows,
      total: [s('report.total'), formatMinor(calc), formatMinor(ded)],
      top: Column(children: [
        _monthPicker(),
        ListTile(
          title: Text(calc - ded >= 0 ? s('report.vatPayable') : s('report.vatCarry')),
          trailing: Text(formatMinor((calc - ded).abs()),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  // -- Stok deger: miktar x ortalama maliyet / 1000 (yuvarli) --------------
  Widget _stock() {
    final s = ref.watch(stringsProvider);
    final products = ref.watch(productsProvider).valueOrNull ?? const <Product>[];
    final levels = ref.watch(allStockLevelsProvider).valueOrNull ?? const <StockLevel>[];
    final whs = ref.watch(warehousesProvider).valueOrNull ?? const <Warehouse>[];
    final pById = {for (final p in products) p.id: p};
    final wById = {for (final w in whs) w.id: w.name};
    var total = 0;
    final rows = <List<String>>[];
    for (final l in levels.where((l) => l.qtyMilli != 0)) {
      final p = pById[l.productId];
      if (p == null) continue;
      final value = roundHalfUp(l.qtyMilli * p.avgCostMinor, 1000);
      total += value;
      rows.add([
        '${p.name} · ${wById[l.warehouseId] ?? ''}',
        formatMilli(l.qtyMilli),
        formatMinor(p.avgCostMinor),
        formatMinor(value),
      ]);
    }
    return _table(
      [s('report.product'), s('report.qty'), s('report.avgCost'), s('report.value')],
      rows,
      total: [s('report.total'), '', '', formatMinor(total)],
    );
  }

  // -- Tahsilat / Odeme raporu ---------------------------------------------
  Widget _payments(String direction) {
    final s = ref.watch(stringsProvider);
    final list = (ref.watch(paymentsBetweenProvider(_range)).valueOrNull ?? const <Payment>[])
        .where((p) => p.direction == direction && !p.isCancelled)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    var total = 0;
    final rows = [
      for (final p in list)
        () {
          total += p.amountMinor;
          return [
            p.date,
            p.partyName,
            s('paymentMethod.${p.method}'),
            formatMinor(p.amountMinor),
          ];
        }(),
    ];
    return _table(
      [s('report.date'), s('report.party'), s('payment.method'), s('payment.amount')],
      rows,
      total: [s('report.total'), '', '', formatMinor(total)],
      top: _monthPicker(),
    );
  }

  // -- Cari ekstre (08 §5): borc / alacak / yuruyen bakiye -------------------
  Widget _ledger() {
    final s = ref.watch(stringsProvider);
    final t = ref.watch(tokensProvider);
    final parties = ref.watch(partiesProvider).valueOrNull ?? const <Party>[];
    if (parties.isEmpty) return EmptyView(message: s('common.empty'));
    final party = parties.firstWhere((p) => p.id == _partyId, orElse: () => parties.first);
    final entries = ref.watch(partyLedgerProvider(party.id)).valueOrNull ?? const <LedgerEntry>[];
    // Liste yeniden eskiye gelir; kapanis = guncel bakiye, geriye dogru yuruyen bakiye.
    var bal = party.balanceMinor;
    final rows = <List<String>>[];
    for (final e in entries) {
      rows.add([
        e.date,
        e.description.isEmpty ? e.refType : e.description,
        e.deltaMinor > 0 ? formatMinor(e.deltaMinor) : '',
        e.deltaMinor < 0 ? formatMinor(-e.deltaMinor) : '',
        formatMinor(bal),
      ]);
      bal -= e.deltaMinor;
    }
    return _table(
      [s('report.date'), s('report.description'), s('report.debit'), s('report.credit'), s('report.balance')],
      rows,
      total: [s('report.closing'), '', '', '', formatMinor(party.balanceMinor)],
      top: Padding(
        padding: EdgeInsets.only(bottom: t.spacing('md')),
        child: DropdownButtonFormField<String>(
          value: party.id,
          items: [for (final p in parties) DropdownMenuItem(value: p.id, child: Text(p.name))],
          onChanged: (v) => setState(() => _partyId = v),
        ),
      ),
    );
  }
}
