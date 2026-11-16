import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';

/// `parties/{partyId}` (cari). Bakiye: >0 alacak (bize borclu), <0 borc (biz borcluyuz).
class Party {
  const Party({
    required this.id,
    required this.companyId,
    required this.kinds,
    required this.name,
    this.taxOffice = '',
    this.taxNo = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.notes = '',
    this.balanceMinor = 0,
    this.lastTxId = '',
    this.active = true,
  });

  final String id;
  final String companyId;
  final List<String> kinds; // 'customer' | 'supplier'
  final String name;
  final String taxOffice;
  final String taxNo;
  final String phone;
  final String email;
  final String address;
  final String notes;
  final int balanceMinor;
  final String lastTxId;
  final bool active;

  bool get isCustomer => kinds.contains('customer');
  bool get isSupplier => kinds.contains('supplier');

  factory Party.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Party(
      id: doc.id,
      companyId: asStr(d['companyId']),
      kinds: asStrList(d['kinds']),
      name: asStr(d['name']),
      taxOffice: asStr(d['taxOffice']),
      taxNo: asStr(d['taxNo']),
      phone: asStr(d['phone']),
      email: asStr(d['email']),
      address: asStr(d['address']),
      notes: asStr(d['notes']),
      balanceMinor: asInt(d['balanceMinor']),
      lastTxId: asStr(d['lastTxId']),
      active: asBool(d['active'], fallback: true),
    );
  }

  /// Ana veri alanlari. Bakiye/`lastTxId` BURADA YOK: kurallar (03) bunlarin
  /// yalniz hareket belgesiyle degismesine izin verir.
  Json masterFields() => {
        'kinds': kinds,
        'name': name,
        'taxOffice': taxOffice,
        'taxNo': taxNo,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
        'active': active,
      };

  Party copyWith({
    List<String>? kinds,
    String? name,
    String? taxOffice,
    String? taxNo,
    String? phone,
    String? email,
    String? address,
    String? notes,
    bool? active,
  }) =>
      Party(
        id: id,
        companyId: companyId,
        kinds: kinds ?? this.kinds,
        name: name ?? this.name,
        taxOffice: taxOffice ?? this.taxOffice,
        taxNo: taxNo ?? this.taxNo,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        notes: notes ?? this.notes,
        balanceMinor: balanceMinor,
        lastTxId: lastTxId,
        active: active ?? this.active,
      );
}
