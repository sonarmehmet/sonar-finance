import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/models/project.dart';
import '../../data/repositories/project_repository.dart';

/// "Projeler" sekmesi: proje listesi + ozet kart (harcama / tahsilat).
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final canWrite = ref.watch(userProfileProvider).valueOrNull?.can('project.write') ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(s('mobileNav.projects'))),
      floatingActionButton: canWrite
          ? FloatingActionButton(
              onPressed: () => context.push('/projects/new'),
              child: const Icon(LucideIcons.plus),
            )
          : null,
      body: AsyncBody<List<Project>>(
        value: ref.watch(projectsProvider),
        builder: (list) {
          if (list.isEmpty) return EmptyView(message: s('project.empty'));
          return ListView(padding: EdgeInsets.all(t.screenPadding), children: [
            for (final p in list) _ProjectCard(project: p),
          ]);
        },
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final stats = ref.watch(projectStatsProvider(project.id)).valueOrNull ?? const ProjectStats();
    return Card(
      child: InkWell(
        onTap: () => context.push('/projects/${project.id}'),
        child: Padding(
          padding: EdgeInsets.all(t.spacing('lg')),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(project.name,
                    style: TextStyle(fontSize: t.fontSize('bodyLg'), fontWeight: t.fontWeight('semibold'))),
              ),
              StatusChip(
                label: s('project.status.${project.status}'),
                color: t.color(project.status == 'active' ? 'positive' : 'textSecondary'),
              ),
            ]),
            SizedBox(height: t.spacing('sm')),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(s('project.cost')),
              MoneyText(stats.costMinor),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(s('project.collected')),
              MoneyText(stats.collectedMinor),
            ]),
          ]),
        ),
      ),
    );
  }
}
