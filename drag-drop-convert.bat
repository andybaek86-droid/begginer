@echo off
rem Drag and drop a CSV/TXT file onto this .bat file.
rem EUC-KR file  -> creates *_utf8 file
rem UTF-8 file   -> creates *_euckr file
if "%~1"=="" (
  echo Drag and drop a CSV/TXT file onto this .bat file.
  pause
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0convert-encoding.ps1" -InputFile "%~1"
pause
