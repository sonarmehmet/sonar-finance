import 'package:firebase_core/firebase_core.dart';

/// GELISTIRME (emulator) ayarlari. `demo-` on ekli proje kimligi emulator ile
/// gercek bulut kaynagi kullanmadan calisir.
///
/// URETIM icin: gercek Firebase projesinde `flutterfire configure` calistirin;
/// bu dosya o komutla uretilen dosyayla degistirilir.
class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-sonar-finance',
  );
}
