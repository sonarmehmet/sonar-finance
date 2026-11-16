# SONAR FINANCE — Android (Flutter)

Ajan 2 klasörü. Sözleşme: `../../CONTRACTS.md` (v1.0.0). İşlem mantığı: `../../docs/04-islem-akislari.md`.

## İlk kurulum (bir kez)
Bu klasörde `android/` platform dosyaları henüz yok (Flutter SDK olmayan ortamda yazıldı). Windows'ta:

```bat
cd apps\android
flutter create . --platforms=android --project-name sonar_finance --org com.sonar
flutter pub get
```
`flutter create` mevcut `lib/` ve `pubspec.yaml` dosyalarının üzerine yazmaz; çıktıda `lib/main.dart` değişirse `git checkout -- lib pubspec.yaml` ile geri alın.

Android `minSdkVersion` en az 23 olmalı (Firebase). `android/app/build.gradle` içinde `minSdkVersion 23` yapın.

## Çalıştırma
```bat
scripts\run_emulator.bat            REM Firebase emülatörü (ayrı pencere)
cd apps\android
flutter run --dart-define=USE_EMULATOR=true
```
Fiziksel cihazda emülatöre bağlanmak için: `--dart-define=EMULATOR_HOST=<bilgisayar-ip>`.
Emülatörde kullanıcı: Auth emülatörüne e-posta/şifre ile kullanıcı ekleyip `users/{uid}` belgesini (`companyId, displayName, email, role, permissions, active`) oluşturun (C1 seed verisi gelince otomatikleşecek).

## Paylaşılan dosyalar
`assets/shared/` = `../../shared/` kopyası (Flutter, paket dışı asset okumaz).
`shared/` değişince: `tool\sync_shared.bat` (veya `tool/sync_shared.sh`).

## Yapı
```
lib/
  core/        firebase, theme (tokens), l10n (tr.json), router, auth, providers
  data/        (A3+) modeller, repository'ler
  services/    (A4+) işlem servisleri: issueInvoice, cancelInvoice, ...
  features/    auth, shell, home, transactions, projects, reports, profile
```
