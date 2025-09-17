@echo off
REM One-click start for Windows users. Opens a new PowerShell window and runs the robust start-server.ps1 script.
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0start-server.ps1"
pause
