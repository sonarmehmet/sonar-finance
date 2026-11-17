import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/providers.dart';

/// "Islemler" sekmesi: modullere giden merkez.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final items = <(IconData, String, String)>[
      (LucideIcons.fileText, s('menu.invoices'), '/invoices'),
      (LucideIcons.users, s('menu.parties'), '/parties'),
      (LucideIcons.landmark, s('menu.cashBank'), '/accounts'),
      (LucideIcons.banknote, s('payment.list'), '/payments'),
      (LucideIcons.package, s('menu.stock'), '/products'),
      (LucideIcons.warehouse, s('stock.warehouses'), '/warehouses'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s('mobileNav.transactions'))),
      body: ListView(
        padding: EdgeInsets.all(t.screenPadding),
        children: [
          Card(
            child: Column(children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  leading: Icon(items[i].$1),
                  title: Text(items[i].$2),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => context.push(items[i].$3),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}
