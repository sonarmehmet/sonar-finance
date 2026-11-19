# SONAR FINANCE — Android (Flutter)

Ajan 2 klasörü. Sözleşme: `../../CONTRACTS.md` (v1.0.0). İşlem mantığı: `../../docs/04-islem-akislari.md`.

## İlk kurulum (bir kez)
Flutter SDK (3.22+) kurulu olmalı. `android/` platform klasörü depoda yok; tek komutla üretilir:

```bat
cd apps\android
tool\setup_android.bat
```
Script: `flutter create` (yoksa) → `AndroidManifest.xml` (INTERNET, ağ durumu, debug'da http emülatör izni) → `minSdk 23` (Firebase) → uygulama simgesi → `flutter pub get`.
Sonra doğrulama: `flutter analyze` ve `flutter test`.

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
