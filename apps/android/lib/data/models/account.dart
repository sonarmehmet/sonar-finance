import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';

/// `accounts/{accountId}` (kasa + banka). `balanceMinor` yalniz hareketle degisir.
class Account {
  const Account({
    required this.id,
    required this.companyId,
    required this.type,
    required this.name,
    this.bankName = '',
    this.iban = '',
    this.balanceMinor = 0,
    this.lastTxId = '',
    this.active = true,
  });

  final String id;
  final String companyId;
  final String type; // 'cash' | 'bank'
  final String name;
  final String bankName;
  final String iban;
  final int balanceMinor;
  final String lastTxId;
  final bool active;

  bool get isCash => type == 'cash';
  bool get isBank => type == 'bank';

  factory Account.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Account(
      id: doc.id,
      companyId: asStr(d['companyId']),
      type: asStr(d['type']).isEmpty ? 'cash' : asStr(d['type']),
      name: asStr(d['name']),
      bankName: asStr(d['bankName']),
      iban: asStr(d['iban']),
      balanceMinor: asInt(d['balanceMinor']),
      lastTxId: asStr(d['lastTxId']),
      active: asBool(d['active'], fallback: true),
    );
  }

  /// Ana veri alanlari; bakiye/`lastTxId` YOK (kurallar: yalniz hareketle degisir).
  Json masterFields() => {
        'type': type,
        'name': name,
        'bankName': bankName,
        'iban': iban,
        'currency': 'TRY',
        'active': active,
      };
}
