@echo off
REM SONAR FINANCE - TEK TIKLA DENEME (Chrome'da). Gerekenler: Flutter, Node.js, Java 17+, Firebase CLI (npm i -g firebase-tools)
REM Yapar: 1) Firebase emulatorunu ayri pencerede acar  2) demo veriyi yukler  3) flutter create + flutter run -d chrome
REM Giris: admin@sonar.local / Test1234!
setlocal
cd /d "%~dp0.."
start "SONAR emulator" cmd /k scripts\run_emulator.bat
echo Emulator aciliyor, 25 sn bekleniyor...
timeout /t 25 /nobreak >nul
call scripts\seed_emulator.bat
cd apps\android
if not exist "web" call flutter create . --platforms=web,android --project-name sonar_finance --org com.sonar
git checkout -- lib pubspec.yaml test 2>nul
call tool\sync_shared.bat
call flutter pub get
call flutter run -d chrome
endlocal
