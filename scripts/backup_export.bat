@echo off
REM SONAR FINANCE - Yedek al. Kullanim: backup_export.bat sirketId [encrypt]
REM Gercek proje icin once GOOGLE_APPLICATION_CREDENTIALS ayarlayin (servis hesabi anahtari repoya KONMAZ).
setlocal
cd /d "%~dp0..\firebase\tools" || exit /b 1
call npm install || exit /b 1
if /I "%~2"=="encrypt" (node export.js --company %~1 --encrypt) else (node export.js --company %~1)
endlocal
