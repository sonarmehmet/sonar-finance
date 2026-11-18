import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/islem_servisleri/expense_service.dart';
import '../../data/islem_servisleri/tx_errors.dart';
import '../../data/models/expense.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/write_helpers.dart';

/// Gider listesi (tum giderler veya bir projenin giderleri); iptal desteklenir.
class ExpensesListScreen extends ConsumerStatefulWidget {
  const ExpensesListScreen({super.key, this.projectId});
  final String? projectId;
  @override
  ConsumerState<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends ConsumerState<ExpensesListScreen> {
  final Map<String, String> _cancelTx = {};

  Future<void> _cancel(Expense e) async {
    final s = ref.read(stringsProvider);
    final ok = await confirmDialog(context, ref, message: s('expense.confirmCancel'));
    if (!ok || !mounted) return;
    final txId = _cancelTx.putIfAbsent(e.id, newId);
    try {
      await ref.read(expenseServiceProvider).cancelExpense(e.id, txId);
      _cancelTx.remove(e.id);
      if (mounted) showSuccess(context, ref, s('expense.cancelled'));
    } catch (err) {
      if (mounted) showError(context, ref, describeTxError(err, s));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final canWrite = ref.watch(userProfileProvider).valueOrNull?.can('finance.write') ?? false;
    final list = ref.watch(expensesProvider(widget.projectId));
    return Scaffold(
      appBar: AppBar(title: Text(s('expense.title'))),
      floatingActionButton: canWrite
          ? FloatingActionButton(
              onPressed: () => context.push(widget.projectId == null
                  ? '/expenses/new'
                  : '/expenses/new?projectId=${widget.projectId}'),
              child: const Icon(LucideIcons.plus),
            )
          : null,
      body: AsyncBody<List<Expense>>(
        value: list,
        builder: (items) {
          if (items.isEmpty) return EmptyView(message: s('expense.empty'));
          return ListView(padding: EdgeInsets.all(t.screenPadding), children: [
            for (final e in items)
              Card(
                child: ListTile(
                  leading: const Icon(LucideIcons.receipt),
                  title: Text(s('expenseCategory.${e.categoryId}')),
                  subtitle: Text([e.date, if (e.description.isNotEmpty) e.description].join(' · ')),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    MoneyText(e.amountMinor,
                        style: TextStyle(decoration: e.isCancelled ? TextDecoration.lineThrough : null)),
                    if (e.isCancelled)
                      StatusChip(label: s('status.cancelled'), color: t.color('textSecondary')),
                  ]),
                  onLongPress: canWrite && !e.isCancelled ? () => _cancel(e) : null,
                  onTap: canWrite && !e.isCancelled ? () => _cancel(e) : null,
                ),
              ),
          ]);
        },
      ),
    );
  }
}
