@echo off
REM SONAR FINANCE - Android gelistirme calistirma
cd /d "%~dp0..\apps\android" || exit /b 1
call flutter pub get
call flutter run
