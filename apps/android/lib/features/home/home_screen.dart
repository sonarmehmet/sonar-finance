import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/providers.dart';
import '../invoices/invoice_widgets.dart';

/// Ana Sayfa. Ozet kartlari (stats/summary) F5'te eklenecek;
/// simdilik hizli islem kisayollari.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final pad = t.screenPadding;

    void soon() {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s('common.comingSoon'))));
    }

    final canInvoice = profile?.can('invoice.write') ?? false;
    final actions = <(IconData, String, VoidCallback)>[
      (
        LucideIcons.fileText,
        s('quickActions.invoice'),
        canInvoice ? () => showNewInvoiceTypeSheet(context, ref) : soon,
      ),
      (
        LucideIcons.banknote,
        s('quickActions.collection'),
        (profile?.can('finance.write') ?? false)
            ? () => context.push('/payments/new?direction=in')
            : soon,
      ),
      (LucideIcons.receipt, s('quickActions.expense'), soon),
      (LucideIcons.folderPlus, s('quickActions.project'), soon),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(s('mobileNav.home'))),
      body: ListView(
        padding: EdgeInsets.all(pad),
        children: [
          if (profile != null && profile.displayName.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: t.spacing('lg')),
              child: Text(
                profile.displayName,
                style: TextStyle(
                  fontSize: t.fontSize('bodyLg'),
                  color: t.color('textSecondary'),
                ),
              ),
            ),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: t.spacing('md'),
            crossAxisSpacing: t.spacing('md'),
            childAspectRatio: 0.82,
            children: [
              for (final a in actions)
                _QuickAction(icon: a.$1, label: a.$2, onTap: a.$3),
            ],
          ),
          SizedBox(height: t.spacing('xl')),
          Text(
            s('common.modules'),
            style: TextStyle(
              fontSize: t.fontSize('bodyLg'),
              fontWeight: t.fontWeight('semibold'),
            ),
          ),
          SizedBox(height: t.spacing('md')),
          Card(
            child: Column(
              children: [
                _ModuleTile(
                  icon: LucideIcons.users,
                  label: s('menu.parties'),
                  onTap: () => context.push('/parties'),
                ),
                const Divider(),
                _ModuleTile(
                  icon: LucideIcons.package,
                  label: s('menu.stock'),
                  onTap: () => context.push('/products'),
                ),
                const Divider(),
                _ModuleTile(
                  icon: LucideIcons.landmark,
                  label: s('menu.cashBank'),
                  onTap: () => context.push('/accounts'),
                ),
                const Divider(),
                _ModuleTile(
                  icon: LucideIcons.warehouse,
                  label: s('stock.warehouses'),
                  onTap: () => context.push('/warehouses'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleTile extends ConsumerWidget {
  const _ModuleTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    return ListTile(
      leading: Icon(icon, color: t.color('accent')),
      title: Text(label),
      trailing: Icon(
        LucideIcons.chevronRight,
        size: 18,
        color: t.color('textSecondary'),
      ),
      onTap: onTap,
    );
  }
}

class _QuickAction extends ConsumerWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radius('card')),
      child: Ink(
        decoration: BoxDecoration(
          color: t.color('card'),
          borderRadius: BorderRadius.circular(t.radius('card')),
          border: Border.all(color: t.color('border')),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: t.color('accent'), size: 26),
            SizedBox(height: t.spacing('sm')),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: t.fontSize('caption')),
            ),
          ],
        ),
      ),
    );
  }
}
