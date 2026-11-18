import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firestore_paths.dart';
import '../models/account.dart';
import '../models/account_movement.dart';

class AccountRepository {
  AccountRepository(this._p);

  final CompanyPaths _p;

  Stream<List<Account>> watchAll() => _p
      .col('accounts')
      .orderBy('name')
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(Account.fromDoc).toList());

  Stream<Account?> watch(String id) => _p
      .doc('accounts', id)
      .snapshots()
      .map((s) => s.exists ? Account.fromDoc(s) : null);

  /// Hesap hareketleri (index: accountId + date desc).
  Stream<List<AccountMovement>> watchMovements(String accountId, {int limit = 50}) => _p
      .col('account_movements')
      .where('accountId', isEqualTo: accountId)
      .orderBy('date', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(AccountMovement.fromDoc).toList());
}

final accountRepositoryProvider = Provider.autoDispose<AccountRepository>(
  (ref) => AccountRepository(ref.watch(companyPathsProvider)),
);

final accountsProvider = StreamProvider.autoDispose<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).watchAll(),
);

final accountProvider = StreamProvider.autoDispose.family<Account?, String>(
  (ref, id) => ref.watch(accountRepositoryProvider).watch(id),
);

final accountMovementsProvider =
    StreamProvider.autoDispose.family<List<AccountMovement>, String>(
  (ref, id) => ref.watch(accountRepositoryProvider).watchMovements(id),
);
