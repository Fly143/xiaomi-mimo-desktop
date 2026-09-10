@echo off
REM Double-click: patch Xiaomi MiMo app.asar (skip login UI).
REM Requires Administrator. Closes Xiaomi MiMo first.
net session >nul 2>&1
if errorlevel 1 (
  echo Requesting Administrator...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0patch-mimo-login-bypass.ps1" -Start
pause
