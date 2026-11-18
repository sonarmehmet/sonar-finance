import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/date/date_utils.dart';
import '../../core/money/money.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/date_field.dart';
import '../../data/islem_servisleri/expense_service.dart';
import '../../data/islem_servisleri/tx_errors.dart';
import '../../data/models/account.dart';
import '../../data/models/project.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/write_helpers.dart';

/// Yeni gider (docs/04 §7). Proje secilirse maliyet disiplini de secilir.
class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, this.projectId});
  final String? projectId;
  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  String _category = 'general';
  String? _accountId;
  String? _projectId;
  String? _discipline;
  String _date = todayIso();
  final _amount = TextEditingController();
  final _vat = TextEditingController();
  final _desc = TextEditingController();
  final _txId = newId();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _projectId = widget.projectId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _vat.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    setState(() => _busy = true);
    try {
      final res = await ref.read(expenseServiceProvider).recordExpense(
            txId: _txId,
            categoryId: _category,
            amountMinor: parseMinor(_amount.text) ?? 0,
            vatMinor: parseMinor(_vat.text) ?? 0,
            accountId: _accountId ?? '',
            date: _date,
            projectId: _projectId,
            discipline: _discipline,
            description: _desc.text,
          );
      if (!mounted) return;
      showSuccess(context, ref, s('expense.saved'));
      if (res.accountNegative) showWarning(context, ref, s('account.negativeWarn'));
      context.pop();
    } catch (e) {
      if (mounted) showError(context, ref, describeTxError(e, s));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final c = ref.watch(constantsProvider);
    final accounts = (ref.watch(accountsProvider).valueOrNull ?? const <Account>[])
        .where((a) => a.active)
        .toList();
    final projects = (ref.watch(projectsProvider).valueOrNull ?? const <Project>[])
        .where((p) => p.status != 'done')
        .toList();
    final gap = SizedBox(height: t.spacing('md'));
    return Scaffold(
      appBar: AppBar(title: Text(s('expense.new'))),
      body: ListView(padding: EdgeInsets.all(t.screenPadding), children: [
        DropdownButtonFormField<String>(
          value: _category,
          items: [
            for (final k in c.expenseCategories)
              DropdownMenuItem(value: k, child: Text(s('expenseCategory.$k'))),
          ],
          decoration: InputDecoration(labelText: s('expense.category')),
          onChanged: (v) => setState(() => _category = v ?? 'general'),
        ),
        gap,
        TextField(
          controller: _amount,
          keyboardType: moneyKeyboard,
          inputFormatters: moneyInputFormatters,
          decoration: InputDecoration(labelText: s('expense.amount')),
        ),
        gap,
        TextField(
          controller: _vat,
          keyboardType: moneyKeyboard,
          inputFormatters: moneyInputFormatters,
          decoration: InputDecoration(labelText: s('expense.vat')),
        ),
        gap,
        DropdownButtonFormField<String>(
          value: _accountId,
          items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
          decoration: InputDecoration(labelText: s('payment.account')),
          onChanged: (v) => setState(() => _accountId = v),
        ),
        gap,
        DateField(label: s('payment.date'), value: _date, onChanged: (v) => setState(() => _date = v)),
        gap,
        DropdownButtonFormField<String?>(
          value: _projectId,
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(s('expense.none'))),
            for (final p in projects) DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
          ],
          decoration: InputDecoration(labelText: s('expense.project')),
          onChanged: (v) => setState(() {
            _projectId = v;
            if (v == null) _discipline = null;
          }),
        ),
        if (_projectId != null) ...[
          gap,
          DropdownButtonFormField<String>(
            value: _discipline,
            items: [
              for (final d in c.disciplines)
                DropdownMenuItem(value: d, child: Text(s('disciplines.$d'))),
            ],
            decoration: InputDecoration(labelText: s('expense.discipline')),
            onChanged: (v) => setState(() => _discipline = v),
          ),
        ],
        gap,
        TextField(controller: _desc, decoration: InputDecoration(labelText: s('expense.description'))),
        SizedBox(height: t.spacing('lg')),
        FilledButton(
          onPressed: _busy ? null : _save,
          style: FilledButton.styleFrom(minimumSize: Size.fromHeight(t.minTouchTarget)),
          child: Text(s('common.save')),
        ),
      ]),
    );
  }
}
