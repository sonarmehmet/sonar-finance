# SONAR FINANCE — en kısa başlangıç

## Chrome'da denemek (en kolay)
Gerekenler: Flutter, Node.js, Java 17+, `npm i -g firebase-tools`.
Klasörde çift tıkla / çalıştır: `scripts\hizli_baslat_chrome.bat`
Giriş: `admin@sonar.local` / `Test1234!`

## Elle (aynı şey)
```
scripts\run_emulator.bat        (ayrı pencere, açık kalsın)
scripts\seed_emulator.bat       (bir kez)
cd apps\android
flutter create . --platforms=web,android
git checkout -- lib pubspec.yaml test
flutter run -d chrome
```
Firebase ayarı yapılmadıkça uygulama otomatik emülatöre bağlanır.

## .exe ve APK
Bu ortamda üretilemez; kendi bilgisayarında: `scripts\build_windows.bat`, `scripts\build_android.bat`. Ayrıntı: `docs/09-kurulum-rehberi.md`.
