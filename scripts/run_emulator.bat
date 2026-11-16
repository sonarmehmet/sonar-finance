@echo off
REM SONAR FINANCE - Firebase Emulator (Auth + Firestore)
cd /d "%~dp0..\firebase" || exit /b 1
call firebase emulators:start --project demo-sonar-finance
