import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';

/// `projects/{id}`: sozlesme ve butceler KDV haric (docs/08 §4).
class Project {
  const Project({
    required this.id,
    required this.name,
    this.partyId = '',
    this.location = '',
    this.startDate = '',
    this.endDate = '',
    this.contractMinor = 0,
    this.status = 'active',
    this.budgets = const {},
    this.notes = '',
  });

  final String id;
  final String name;
  final String partyId;
  final String location;
  final String startDate;
  final String endDate;
  final int contractMinor;
  final String status; // active | done | paused
  final Map<String, int> budgets;
  final String notes;

  int get budgetTotal => budgets.values.fold(0, (a, b) => a + b);

  /// Tahmini kar = sozlesme - butce toplami.
  int get estimatedProfit => contractMinor - budgetTotal;

  factory Project.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Project(
      id: doc.id,
      name: asStr(d['name']),
      partyId: asStr(d['partyId']),
      location: asStr(d['location']),
      startDate: asStr(d['startDate']),
      endDate: asStr(d['endDate']),
      contractMinor: asInt(d['contractMinor']),
      status: asStr(d['status']).isEmpty ? 'active' : asStr(d['status']),
      budgets: {
        for (final e in ((d['budgets'] as Map?) ?? const {}).entries)
          e.key as String: asInt(e.value),
      },
      notes: asStr(d['notes']),
    );
  }

  Json toMap() => {
        'name': name,
        'partyId': partyId,
        'location': location,
        'startDate': startDate,
        'endDate': endDate,
        'contractMinor': contractMinor,
        'status': status,
        'budgets': budgets,
        'notes': notes,
      };
}

/// `project_stats/{id}`.
class ProjectStats {
  const ProjectStats({
    this.revenueMinor = 0,
    this.costMinor = 0,
    this.collectedMinor = 0,
    this.paidOutMinor = 0,
    this.byDiscipline = const {},
  });

  final int revenueMinor;
  final int costMinor;
  final int collectedMinor;
  final int paidOutMinor;
  final Map<String, int> byDiscipline;

  int get profitMinor => revenueMinor - costMinor;

  factory ProjectStats.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return ProjectStats(
      revenueMinor: asInt(d['revenueMinor']),
      costMinor: asInt(d['costMinor']),
      collectedMinor: asInt(d['collectedMinor']),
      paidOutMinor: asInt(d['paidOutMinor']),
      byDiscipline: {
        for (final e in ((d['byDiscipline'] as Map?) ?? const {}).entries)
          e.key as String: asInt(e.value),
      },
    );
  }
}
