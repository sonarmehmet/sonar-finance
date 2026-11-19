@echo off
REM SONAR FINANCE - Android platform dosyalarini kurar (bir kez; tekrar calistirmak zararsiz).
REM  1) android/ yoksa `flutter create` ile uretir  2) manifest + minSdk 23 + simge uygular
setlocal
cd /d "%~dp0.." || exit /b 1

where flutter >nul 2>nul || (echo Flutter SDK bulunamadi. https://docs.flutter.dev/get-started/install/windows & exit /b 1)

if not exist "android\app" (
  call flutter create . --platforms=android --project-name sonar_finance --org com.sonar || exit /b 1
  REM flutter create lib/ ve pubspec'i degistirdiyse geri al
  git checkout -- lib pubspec.yaml test 2>nul
)

copy /Y "tool\android_overlay\AndroidManifest.xml" "android\app\src\main\AndroidManifest.xml" >nul || exit /b 1
if not exist "android\app\src\debug" mkdir "android\app\src\debug"
copy /Y "tool\android_overlay\AndroidManifest.debug.xml" "android\app\src\debug\AndroidManifest.xml" >nul || exit /b 1

REM Firebase icin minSdk 23 (Groovy ve Kotlin DSL ikisi de)
for %%F in ("android\app\build.gradle" "android\app\build.gradle.kts") do (
  if exist %%F powershell -NoProfile -Command "(Get-Content -Raw '%%~F') -replace 'minSdk\s*=\s*flutter\.minSdkVersion','minSdk = 23' -replace 'minSdkVersion\s+flutter\.minSdkVersion','minSdkVersion 23' | Set-Content -NoNewline '%%~F'"
)

REM Uygulama simgesi (shared/assets/png)
set RES=android\app\src\main\res
set PNG=..\..\shared\assets\png
for %%D in (mdpi hdpi xhdpi xxhdpi xxxhdpi) do if not exist "%RES%\mipmap-%%D" mkdir "%RES%\mipmap-%%D"
copy /Y "%PNG%\app-icon-48.png"  "%RES%\mipmap-mdpi\ic_launcher.png"    >nul
copy /Y "%PNG%\app-icon-96.png"  "%RES%\mipmap-hdpi\ic_launcher.png"    >nul
copy /Y "%PNG%\app-icon-96.png"  "%RES%\mipmap-xhdpi\ic_launcher.png"   >nul
copy /Y "%PNG%\app-icon-192.png" "%RES%\mipmap-xxhdpi\ic_launcher.png"  >nul
copy /Y "%PNG%\app-icon-192.png" "%RES%\mipmap-xxxhdpi\ic_launcher.png" >nul

call tool\sync_shared.bat
call flutter pub get || exit /b 1
echo.
echo Tamam. Calistirmak icin: flutter run --dart-define=USE_EMULATOR=true
endlocal
