# Asorti Araci kurulumu: masaustune ve Baslat menusune kisayol koyar, eski otomatik baslatmayi kaldirir
$LOG = 'C:\AccuNest\uygulama\kurulum_log.txt'
function W($s) { Write-Host $s; Add-Content -Path $LOG -Value $s -Encoding UTF8 }
Set-Content -Path $LOG -Value ("kurulum " + (Get-Date)) -Encoding UTF8
try {
  $S = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\asorti_gerber_kopru.bat'
  if (Test-Path $S) { Remove-Item -Force $S; W 'Eski otomatik baslatma kaldirildi.' }
  $w = New-Object -ComObject WScript.Shell
  $yerler = @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:USERPROFILE 'Desktop'), (Join-Path $env:USERPROFILE 'Masaüstü'))
  if ($env:OneDrive) { $yerler += (Join-Path $env:OneDrive 'Desktop'); $yerler += (Join-Path $env:OneDrive 'Masaüstü') }
  $yerler += (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs')
  $yerler += 'C:\AccuNest'
  $yap = 0
  foreach ($y in ($yerler | Where-Object { $_ } | Select-Object -Unique)) {
    if (-not (Test-Path $y)) { W "yok: $y"; continue }
    try {
      $k = $w.CreateShortcut((Join-Path $y 'Asorti Araci.lnk'))
      $k.TargetPath = "$env:WINDIR\System32\wscript.exe"
      $k.Arguments = '"C:\AccuNest\uygulama\baslat.vbs"'
      $k.WorkingDirectory = 'C:\AccuNest'
      $k.IconLocation = 'C:\AccuNest\uygulama\asorti.ico,0'
      $k.Description = 'Asorti Araci'
      $k.Save(); $yap++; W "kisayol: $y"
    } catch { W ("HATA $y : " + $_.Exception.Message) }
  }
  W "$yap yere kisayol kondu."
} catch { W ('HATA: ' + $_.Exception.Message) }
