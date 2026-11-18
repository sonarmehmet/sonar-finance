@echo off
REM SONAR FINANCE - Android release APK
setlocal
cd /d "%~dp0..\apps\android" || exit /b 1
if not exist "android\app" call tool\setup_android.bat
call flutter pub get || exit /b 1
call flutter build apk --release || exit /b 1
if not exist "..\..\build\android" mkdir "..\..\build\android"
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "..\..\build\android\app-release.apk" || exit /b 1
echo.
echo Tamam: build\android\app-release.apk
endlocal
