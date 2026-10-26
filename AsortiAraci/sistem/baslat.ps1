# Asorti Araci'ni acar: yerel sunucuyu (o da Gerber koprusunu) baslatir ve uygulama penceresini acar.
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $Root 'sistem\ortak.ps1'); $A = Ayarlar $Root
$Url = "http://localhost:$($A.port)/"
function Hazir { try { (Invoke-WebRequest -UseBasicParsing -Uri ($Url + 'ping') -TimeoutSec 2).StatusCode -eq 200 } catch { $false } }
if (-not (Hazir)) {
  Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $Root 'sistem\sunucu.ps1'))
  for ($i = 0; $i -lt 40 -and -not (Hazir); $i++) { Start-Sleep -Milliseconds 250 }
}
$aday = @($A.tarayici, "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe", "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe")
$tarayici = $aday | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
$profil = Join-Path $Root 'profil'
if ($tarayici) { Start-Process -FilePath $tarayici -ArgumentList @("--app=$Url", "--user-data-dir=`"$profil`"", '--no-first-run', '--no-default-browser-check', '--start-maximized') }
else { Start-Process $Url }
