import 'package:flutter/material.dart';
import '../sync/connection_banner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers.dart';

/// Alt menu (docs: mobileNav): Ana Sayfa, Islemler, Projeler, Raporlar, Profil.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);

    return Scaffold(
      body: Column(children: [const ConnectionBanner(), Expanded(child: shell)]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(
          i,
          // Aktif sekmeye tekrar basinca o sekmenin basina don.
          initialLocation: i == shell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(LucideIcons.home),
            label: s('mobileNav.home'),
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.arrowLeftRight),
            label: s('mobileNav.transactions'),
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.briefcase),
            label: s('mobileNav.projects'),
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.barChart3),
            label: s('mobileNav.reports'),
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.user),
            label: s('mobileNav.profile'),
          ),
        ],
      ),
    );
  }
}
