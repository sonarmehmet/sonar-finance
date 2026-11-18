import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `users/{uid}` belgesi (docs/02).
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.companyId,
    required this.displayName,
    required this.email,
    required this.role,
    required this.permissions,
    required this.active,
  });

  final String uid;
  final String companyId;
  final String displayName;
  final String email;
  final String role; // 'admin' | 'employee'
  final Map<String, bool> permissions;
  final bool active;

  bool get isAdmin => role == 'admin';

  /// `invoice.write`, `party.write`, `stock.write`, `finance.write`, `project.write`.
  /// admin hepsine sahiptir.
  bool can(String permission) => isAdmin || (permissions[permission] ?? false);

  factory UserProfile.fromDoc(String uid, Map<String, dynamic> d) {
    final rawPerms = (d['permissions'] as Map?) ?? const {};
    return UserProfile(
      uid: uid,
      companyId: (d['companyId'] as String?) ?? '',
      displayName: (d['displayName'] as String?) ?? '',
      email: (d['email'] as String?) ?? '',
      role: (d['role'] as String?) ?? 'employee',
      permissions: {
        for (final e in rawPerms.entries) e.key as String: e.value == true,
      },
      active: d['active'] == true,
    );
  }
}

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

/// Oturum acan kullanicinin profili. Oturum yoksa `null`.
/// Belge yoksa da `null` doner (router "erisim yok" ekranina yonlendirir).
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .doc('users/${user.uid}')
      .snapshots()
      .map((snap) {
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return UserProfile.fromDoc(user.uid, data);
  });
});

/// Sirket kimligi; tum veri `companies/{cid}/...` altinda.
/// Profil yuklenmeden okunmamali (router bunu garanti eder).
final companyIdProvider = Provider<String>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  if (profile == null) {
    throw StateError('companyIdProvider: profil yuklenmedi');
  }
  return profile.companyId;
});
