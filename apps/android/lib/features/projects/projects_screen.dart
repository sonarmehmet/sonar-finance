import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../shell/placeholder_page.dart';

/// "Projeler" sekmesi: F4'te doldurulacak.
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return PlaceholderPage(title: s('mobileNav.projects'));
  }
}
