@echo off
REM SONAR FINANCE - Windows kurulum paketi (Tauri 2, NSIS)
REM Gereksinimler (yalniz GELISTIRICI makinede): Node.js 20+, Rust (rustup), Visual Studio Build Tools (C++), WebView2.
setlocal
cd /d "%~dp0..\apps\windows" || exit /b 1
if not exist ".env" (
  echo UYARI: apps\windows\.env yok. .env.example dosyasini kopyalayip Firebase ayarlarini doldurun.
)
call npm install || exit /b 1
call npm run tauri build || exit /b 1
if not exist "..\..\build\windows" mkdir "..\..\build\windows"
for %%f in (src-tauri\target\release\bundle\nsis\*-setup.exe) do copy /Y "%%f" "..\..\build\windows\SONAR-FINANCE-Setup.exe"
echo.
echo Tamam: build\windows\SONAR-FINANCE-Setup.exe
endlocal
