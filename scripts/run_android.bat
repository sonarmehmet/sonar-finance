@echo off
REM SONAR FINANCE - Android gelistirme calistirma
cd /d "%~dp0..\apps\android" || exit /b 1
if not exist "android\app" call tool\setup_android.bat
call flutter pub get
call flutter run
