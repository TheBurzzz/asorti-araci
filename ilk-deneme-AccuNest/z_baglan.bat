@echo off
rem OTOPASTAL ile ayni yolu gormek icin: bu bilgisayarin C: diskini Z: olarak bagla
net use Z: \\KALIP1\C /persistent:yes
echo.
if exist Z:\userroot\storage (echo TAMAM: Z: surucusu baglandi.) else (echo SORUN: Z: baglanamadi, bu pencerenin fotografini gonder.)
pause
