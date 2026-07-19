@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0fir-duo-push-askpass.ps1" %*
