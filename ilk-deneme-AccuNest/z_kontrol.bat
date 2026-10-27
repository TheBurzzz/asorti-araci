@echo off
set L=C:\AccuNest\z_log.txt
echo %date% %time% > %L%
echo ==== net use >> %L%
net use >> %L% 2>&1
echo ==== subst >> %L%
subst >> %L% 2>&1
echo ==== diskler >> %L%
wmic logicaldisk get name,drivetype,providername,volumename >> %L% 2>&1
echo ==== Z icerigi >> %L%
dir Z:\ >> %L% 2>&1
echo ==== paylasimlar >> %L%
net share >> %L% 2>&1
echo Bitti. Kapatmak icin bir tusa bas.
pause
