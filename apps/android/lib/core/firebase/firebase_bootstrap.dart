import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

/// Emulator: `flutter run --dart-define=USE_EMULATOR=true`
/// Fiziksel cihazda: `--dart-define=EMULATOR_HOST=<bilgisayar-ip>`
const bool _useEmulator = bool.fromEnvironment('USE_EMULATOR');
const String _emulatorHost =
    String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');

Future<void> bootstrapFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;
  // Cevrimdisi onbellek acik (docs/01, CONTRACTS kural 5).
  firestore.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  if (_useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
    firestore.useFirestoreEmulator(_emulatorHost, 8080);
  }
}
