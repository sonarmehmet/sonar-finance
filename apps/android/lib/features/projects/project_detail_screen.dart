import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/money/money.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/models/invoice.dart';
import '../../data/models/project.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/project_repository.dart';

/// Proje detayi (docs/08 §4): ozet, kar, disiplin butcesi, kalan alacak/borc.
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final c = ref.watch(constantsProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final project = ref.watch(projectProvider(projectId));
    final stats = ref.watch(projectStatsProvider(projectId)).valueOrNull ?? const ProjectStats();
    final invoices = ref.watch(projectInvoicesProvider(projectId)).valueOrNull ?? const <Invoice>[];

    // Kalan alacak/borc: kesilmis proje faturalari - tahsilat/odeme (sorguyla, saklanmaz).
    var salesTotal = 0, purchaseTotal = 0;
    for (final i in invoices.where((i) => i.isIssued)) {
      if (i.type == 'sales') salesTotal += i.totalMinor;
      if (i.type == 'sales_return') salesTotal -= i.totalMinor;
      if (i.type == 'purchase') purchaseTotal += i.totalMinor;
      if (i.type == 'purchase_return') purchaseTotal -= i.totalMinor;
    }
    final remRecv = salesTotal - stats.collectedMinor;
    final remPay = purchaseTotal - stats.paidOutMinor;

    return Scaffold(
      appBar: AppBar(
        title: Text(project.valueOrNull?.name ?? ''),
        actions: [
          IconButton(
            tooltip: s('expense.title'),
            icon: const Icon(LucideIcons.receipt),
            onPressed: () => context.push('/expenses?projectId=$projectId'),
          ),
          if ((profile?.can('project.write') ?? false) && project.valueOrNull != null)
            IconButton(
              tooltip: s('project.edit'),
              icon: const Icon(LucideIcons.pencil),
              onPressed: () => context.push('/projects/$projectId/edit'),
            ),
        ],
      ),
      body: AsyncBody<Project?>(
        value: project,
        builder: (p) {
          if (p == null) return EmptyView(message: s('common.empty'));
          final margin = stats.revenueMinor == 0
              ? '—'
              : formatBp(roundHalfUp(stats.profitMinor * 10000, stats.revenueMinor));
          Widget row(String k, Widget v) => Padding(
                padding: EdgeInsets.symmetric(vertical: t.spacing('xs')),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(k), v]),
              );
          final disciplines = <String>{...c.disciplines, ...p.budgets.keys, ...stats.byDiscipline.keys}
              .where((d) => (p.budgets[d] ?? 0) != 0 || (stats.byDiscipline[d] ?? 0) != 0)
              .toList();
          return ListView(padding: EdgeInsets.all(t.screenPadding), children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(t.spacing('lg')),
                child: Column(children: [
                  row(s('project.contract'), MoneyText(p.contractMinor)),
                  row(s('project.estProfit'), MoneyText(p.estimatedProfit, signed: true)),
                  const Divider(),
                  row(s('project.revenue'), MoneyText(stats.revenueMinor)),
                  row(s('project.cost'), MoneyText(stats.costMinor)),
                  row(s('project.actualProfit'), MoneyText(stats.profitMinor, signed: true)),
                  row(s('project.margin'), Text(margin)),
                  const Divider(),
                  row(s('project.collected'), MoneyText(stats.collectedMinor)),
                  row(s('project.remainingReceivable'), MoneyText(remRecv)),
                  row(s('project.remainingPayable'), MoneyText(remPay)),
                ]),
              ),
            ),
            if (disciplines.isNotEmpty) ...[
              SizedBox(height: t.spacing('md')),
              Text(s('project.byDiscipline'), style: TextStyle(fontWeight: t.fontWeight('semibold'))),
              for (final d in disciplines)
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(t.spacing('md')),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s('disciplines.$d'), style: TextStyle(fontWeight: t.fontWeight('medium'))),
                      row(s('project.budget'), MoneyText(p.budgets[d] ?? 0)),
                      row(s('project.actual'), MoneyText(stats.byDiscipline[d] ?? 0)),
                      row(
                        s('project.remainingBudget'),
                        MoneyText((p.budgets[d] ?? 0) - (stats.byDiscipline[d] ?? 0), signed: true),
                      ),
                    ]),
                  ),
                ),
            ],
            if (p.notes.isNotEmpty) ...[
              SizedBox(height: t.spacing('md')),
              Text(p.notes),
            ],
          ]);
        },
      ),
    );
  }
}
