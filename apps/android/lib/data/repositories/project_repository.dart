import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firestore_paths.dart';
import '../models/expense.dart';
import '../write_helpers.dart';
import '../models/project.dart';

class ProjectRepository {
  ProjectRepository(this._p);
  final CompanyPaths _p;

  Stream<List<Project>> watchAll() => _p
      .col('projects')
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(Project.fromDoc).toList());

  Stream<Project?> watch(String id) => _p
      .doc('projects', id)
      .snapshots()
      .map((s) => s.exists ? Project.fromDoc(s) : null);

  Stream<ProjectStats> watchStats(String id) =>
      _p.doc('project_stats', id).snapshots().map(ProjectStats.fromDoc);

  Stream<List<Expense>> watchExpenses({String? projectId, int limit = 50}) {
    var q = _p.col('expenses').orderBy('date', descending: true);
    if (projectId != null) q = q.where('projectId', isEqualTo: projectId);
    return q.limit(limit).snapshots().map((s) => s.docs.map(Expense.fromDoc).toList());
  }

  Stream<Expense?> watchExpense(String id) => _p
      .doc('expenses', id)
      .snapshots()
      .map((s) => s.exists ? Expense.fromDoc(s) : null);

  /// Ana veri yazimi (cevrimdisi kuyruga alinir). Donus: (id, senkron).
  Future<({String id, bool synced})> save(Project p) async {
    final ref = p.id.isEmpty ? _p.col('projects').doc() : _p.doc('projects', p.id);
    final synced = await writeOrQueue(ref.set({
      ...p.toMap(),
      'companyId': _p.cid,
      if (p.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)));
    return (id: ref.id, synced: synced);
  }
}

final projectRepositoryProvider = Provider.autoDispose<ProjectRepository>(
  (ref) => ProjectRepository(ref.watch(companyPathsProvider)),
);

final projectsProvider = StreamProvider.autoDispose<List<Project>>(
  (ref) => ref.watch(projectRepositoryProvider).watchAll(),
);

final projectProvider = StreamProvider.autoDispose.family<Project?, String>(
  (ref, id) => ref.watch(projectRepositoryProvider).watch(id),
);

final projectStatsProvider = StreamProvider.autoDispose.family<ProjectStats, String>(
  (ref, id) => ref.watch(projectRepositoryProvider).watchStats(id),
);

final expensesProvider =
    StreamProvider.autoDispose.family<List<Expense>, String?>(
  (ref, projectId) =>
      ref.watch(projectRepositoryProvider).watchExpenses(projectId: projectId),
);

final expenseProvider = StreamProvider.autoDispose.family<Expense?, String>(
  (ref, id) => ref.watch(projectRepositoryProvider).watchExpense(id),
);
