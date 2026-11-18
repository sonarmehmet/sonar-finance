@echo off
REM shared/ icindeki sozlesme dosyalarini Android asset klasorune kopyalar.
REM Sozlesme (CONTRACTS.md) surumu degistiginde calistirin.
set SRC=%~dp0..\..\..\shared
set DST=%~dp0..\assets\shared
if not exist "%DST%\l10n" mkdir "%DST%\l10n"
copy /Y "%SRC%\design-tokens.json" "%DST%\design-tokens.json"
copy /Y "%SRC%\constants.json" "%DST%\constants.json"
copy /Y "%SRC%\l10n\tr.json" "%DST%\l10n\tr.json"
