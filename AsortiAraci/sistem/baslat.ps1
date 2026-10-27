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
# tarayicinin "kaydedilen bilgiler" onerilerini (adres / kisisel bilgi doldurma, form gecmisi) sadece bu uygulamanin profilinde kapat.
# Normal Edge'e dokunmaz. Uygulama penceresi aciksa (Edge bu profili kullaniyorsa) bir sey yapmaz.
function OnerileriKapat($profil) {
  $pref = Join-Path $profil 'Default\Preferences'
  if (-not (Test-Path $pref)) { return }
  $desen = [regex]::Escape($profil)
  if (@(Get-CimInstance Win32_Process -Filter "Name='msedge.exe' OR Name='chrome.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match $desen }).Count) { return }
  try {
    Add-Type -AssemblyName System.Web.Extensions
    $js = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $js.MaxJsonLength = [int]::MaxValue; $js.RecursionLimit = 1000
    $d = $js.DeserializeObject([IO.File]::ReadAllText($pref, [Text.Encoding]::UTF8))
    if (-not ($d -is [System.Collections.IDictionary])) { return }
    if ($d.ContainsKey('autofill') -and $d['autofill'] -is [System.Collections.IDictionary]) { $af = $d['autofill'] } else { $af = New-Object 'System.Collections.Generic.Dictionary[string,object]'; $d['autofill'] = $af }
    $deg = $false
    foreach ($k in 'profile_enabled', 'credit_card_enabled') { if (-not ($af.ContainsKey($k) -and ($af[$k] -is [bool]) -and -not $af[$k])) { $af[$k] = $false; $deg = $true } }
    if ($deg) {
      $yeni = $js.Serialize($d); [void]$js.DeserializeObject($yeni)   # yazmadan once gecerli mi bak
      Copy-Item -Force $pref ($pref + '.asorti_yedek')
      [IO.File]::WriteAllText($pref, $yeni, (New-Object Text.UTF8Encoding($false)))
    }
  } catch {}
}
OnerileriKapat $profil
if ($tarayici) { Start-Process -FilePath $tarayici -ArgumentList @("--app=$Url", "--user-data-dir=`"$profil`"", '--no-first-run', '--no-default-browser-check', '--start-maximized', '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows') }
else { Start-Process $Url }
