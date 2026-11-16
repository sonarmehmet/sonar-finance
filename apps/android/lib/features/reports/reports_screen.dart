import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../shell/placeholder_page.dart';

/// "Raporlar" sekmesi: F5'te doldurulacak.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return PlaceholderPage(title: s('mobileNav.reports'));
  }
}
