@echo off
rem KALIP1 bilgisayarinin C: diskini K: olarak baglar (Z: plot icin kullaniliyor, ona dokunmaz)
set L=%~dp0k_log_%COMPUTERNAME%.txt
echo %date% %time% %COMPUTERNAME% > "%L%"
if exist K:\userroot\storage goto ok
net use K: \\KALIP1\C /persistent:yes >> "%L%" 2>&1
:ok
net use >> "%L%" 2>&1
if exist K:\userroot\storage (echo TAMAM: K: surucusu hazir. >> "%L%") else (echo SORUN: K: baglanamadi. >> "%L%")
type "%L%"
echo.
echo Kapatmak icin bir tusa bas.
pause
