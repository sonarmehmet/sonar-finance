import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/providers.dart';

/// "Raporlar" sekmesi: rapor listesi (docs/08 §6).
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final items = <(IconData, String)>[
      (LucideIcons.calendarRange, 'yearly'),
      (LucideIcons.calendar, 'monthly'),
      (LucideIcons.scale, 'balances'),
      (LucideIcons.landmark, 'cashbank'),
      (LucideIcons.folderKanban, 'projects'),
      (LucideIcons.fileSpreadsheet, 'ledger'),
      (LucideIcons.percent, 'vat'),
      (LucideIcons.package, 'stock'),
      (LucideIcons.arrowDownLeft, 'collections'),
      (LucideIcons.arrowUpRight, 'payments'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s('mobileNav.reports'))),
      body: ListView(padding: EdgeInsets.all(t.screenPadding), children: [
        Card(
          child: Column(children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              ListTile(
                leading: Icon(items[i].$1),
                title: Text(s('report.${items[i].$2}')),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => context.push('/reports/${items[i].$2}'),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Rapor tablosunu CSV olarak panoya kopyalar (`;` ayiracli, sayilar kurus/100 degil ham metin).
Future<void> copyCsv(List<List<String>> rows) =>
    Clipboard.setData(ClipboardData(text: rows.map((r) => r.map(_csv).join(';')).join('\n')));

String _csv(String v) => v.contains(';') || v.contains('"') || v.contains('\n')
    ? '"${v.replaceAll('"', '""')}"'
    : v;
