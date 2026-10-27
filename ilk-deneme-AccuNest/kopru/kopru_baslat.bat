@echo off
rem Gerber koprusunu baslatir. Ilk calistirmada Windows acilisina da ekler.
set S=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\asorti_gerber_kopru.bat
if not exist "%S%" (
  echo @start "Gerber koprusu" /min powershell -NoProfile -ExecutionPolicy Bypass -File "C:\AccuNest\kopru\kopru.ps1" > "%S%"
  echo Windows acilisina eklendi.
)
start "Gerber koprusu" /min powershell -NoProfile -ExecutionPolicy Bypass -File "C:\AccuNest\kopru\kopru.ps1"
echo Kopru baslatildi (gorev cubugunda kucuk pencere).
timeout /t 3 >nul
