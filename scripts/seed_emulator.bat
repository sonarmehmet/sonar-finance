@echo off
REM SONAR FINANCE - Emulator'e DEMO verisi yukle (once run_emulator.bat calismali)
setlocal
set FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
set FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
set GCLOUD_PROJECT=demo-sonar-finance
cd /d "%~dp0..\firebase\seed" || exit /b 1
call npm install || exit /b 1
call node seed.js
endlocal
