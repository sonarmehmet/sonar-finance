import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';

/// `warehouses/{whId}`.
class Warehouse {
  const Warehouse({
    required this.id,
    required this.companyId,
    required this.name,
    this.location = '',
    this.isDefault = false,
    this.active = true,
  });

  final String id;
  final String companyId;
  final String name;
  final String location;
  final bool isDefault;
  final bool active;

  factory Warehouse.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Warehouse(
      id: doc.id,
      companyId: asStr(d['companyId']),
      name: asStr(d['name']),
      location: asStr(d['location']),
      isDefault: asBool(d['isDefault']),
      active: asBool(d['active'], fallback: true),
    );
  }

  Json masterFields() => {
        'name': name,
        'location': location,
        'isDefault': isDefault,
        'active': active,
      };

  Warehouse copyWith({
    String? name,
    String? location,
    bool? isDefault,
    bool? active,
  }) =>
      Warehouse(
        id: id,
        companyId: companyId,
        name: name ?? this.name,
        location: location ?? this.location,
        isDefault: isDefault ?? this.isDefault,
        active: active ?? this.active,
      );
}
