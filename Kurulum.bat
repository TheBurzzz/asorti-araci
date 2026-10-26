@echo off
title Asorti Araci - Kurulum
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0kurulum\kontrol.ps1"
if errorlevel 1 (
  echo.
  echo Paket dosyalarinda hata bulundu. Bu pencerenin goruntusunu gonder.
  pause
  exit /b 1
)
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0kurulum\Kurulum.ps1"
if errorlevel 1 pause
