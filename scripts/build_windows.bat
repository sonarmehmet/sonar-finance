@echo off
REM SONAR FINANCE - Windows installer (Tauri 2)
setlocal
cd /d "%~dp0..\apps\windows" || exit /b 1
call npm install || exit /b 1
call npm run tauri build || exit /b 1
if not exist "..\..\build\windows" mkdir "..\..\build\windows"
for %%f in (src-tauri\target\release\bundle\nsis\*-setup.exe) do copy /Y "%%f" "..\..\build\windows\SONAR-FINANCE-Setup.exe"
echo.
echo Tamam: build\windows\SONAR-FINANCE-Setup.exe
endlocal
