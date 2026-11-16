import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/providers.dart';

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

    final actions = <(IconData, String)>[
      (LucideIcons.fileText, s('quickActions.invoice')),
      (LucideIcons.banknote, s('quickActions.collection')),
      (LucideIcons.receipt, s('quickActions.expense')),
      (LucideIcons.folderPlus, s('quickActions.project')),
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
                _QuickAction(icon: a.$1, label: a.$2, onTap: soon),
            ],
          ),
        ],
      ),
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
