# Asorti Araci'ni acar: yerel sunucuyu (ve onunla Gerber koprusunu) baslatir, uygulama penceresini acar.
$Root = 'C:\AccuNest'; $Port = 8642; $Url = "http://localhost:$Port/"
function Hazir { try { (Invoke-WebRequest -UseBasicParsing -Uri ($Url + 'ping') -TimeoutSec 2).StatusCode -eq 200 } catch { $false } }
if (-not (Hazir)) {
  Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $Root 'uygulama\sunucu.ps1'))
  for ($i = 0; $i -lt 40 -and -not (Hazir); $i++) { Start-Sleep -Milliseconds 250 }
}
$tarayici = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe", "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
$profil = Join-Path $Root 'uygulama\profil'
if ($tarayici) { Start-Process -FilePath $tarayici -ArgumentList @("--app=$Url", "--user-data-dir=$profil", '--no-first-run', '--no-default-browser-check', '--window-size=1400,900') }
else { Start-Process $Url }
