@echo off
REM SONAR FINANCE - Windows gelistirme calistirma (Tauri dev)
cd /d "%~dp0..\apps\windows" || exit /b 1
call npm install
call npm run tauri dev
