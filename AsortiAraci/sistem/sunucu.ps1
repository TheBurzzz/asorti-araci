# Asorti Araci - yerel sunucu: uygulama penceresini sunar, Gerber koprusunu arka planda calistirir,
# pencere kapaninca kopruyu ve Batch'i de kapatir. GitHub'daki yeni surumu bulur ve tek tusla kurar.
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $Root 'sistem\ortak.ps1'); $A = Ayarlar $Root; $Port = $A.port
$ErrorActionPreference = 'Stop'
$mtx = New-Object Threading.Mutex($false, 'AsortiAraciSunucu')
$sahip = $false; try { $sahip = $mtx.WaitOne(0) } catch [Threading.AbandonedMutexException] { $sahip = $true }
if (-not $sahip) { exit }
New-Item -ItemType Directory -Force -Path (Join-Path $Root 'kopru\log') | Out-Null
$LOG = Join-Path $Root 'kopru\log\sunucu.txt'
function Log($s) { try { Add-Content -Path $LOG -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $s) -Encoding UTF8 } catch {} }

function KopruSurecleri { @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'kopru\\kopru\.ps1' }) }
# baska yerden (eski kurulum) calisan kopru varsa kapat; kopruyu bu sunucu yonetiyor
foreach ($p in KopruSurecleri) { try { Stop-Process -Id $p.ProcessId -Force } catch {} }
$script:kopru = $null
function KopruBaslat {
  $script:kBas = Get-Date
  $script:kopru = Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -PassThru -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $Root 'kopru\kopru.ps1'))
  Log ('kopru baslatildi, pid ' + $script:kopru.Id)
}
function Kapat {
  Log 'pencere kapandi: kopru ve Batch kapatiliyor'
  try { if ($script:kopru -and -not $script:kopru.HasExited) { Stop-Process -Id $script:kopru.Id -Force } } catch {}
  foreach ($p in KopruSurecleri) { try { Stop-Process -Id $p.ProcessId -Force } catch {} }
  foreach ($b in @(Get-Process -Name batch -ErrorAction SilentlyContinue)) { try { [void]$b.CloseMainWindow() } catch {} }
  Start-Sleep 3
  foreach ($b in @(Get-Process -Name batch -ErrorAction SilentlyContinue)) { try { Stop-Process -Id $b.Id -Force } catch {} }
}
if ($A.gerber) { KopruBaslat } else { Log 'Gerber kapali (sadece asorti): kopru baslatilmadi' }

# ---------- guncelleme ----------
$script:uzak = $null; $script:uzakZaman = [datetime]::MinValue
function Web { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 }
function SurumNo($v) { try { return [version]("$v".Trim()) } catch { return [version]'0.0' } }
function UzakSurum([bool]$taze) {
  if (-not $A.guncelleme) { return $null }
  if (-not $taze -and $script:uzak -and ((Get-Date) - $script:uzakZaman).TotalMinutes -lt 10) { return $script:uzak }
  Web
  $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 8 -Uri ("https://raw.githubusercontent.com/$($A.guncelleme)/main/AsortiAraci/surum.json?t=" + [DateTime]::UtcNow.Ticks)
  $metin = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()).TrimStart([char]0xFEFF)
  $script:uzak = $metin | ConvertFrom-Json; $script:uzakZaman = Get-Date
  return $script:uzak
}
function SurenIs { @(Get-ChildItem (Join-Path $Root 'kopru\gelen'), (Join-Path $Root 'kopru\isleniyor') -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.txt' }).Count -gt 0 }
function Guncelle {
  Web
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ('asorti_guncelleme_' + [guid]::NewGuid().ToString('N').Substring(0, 8)); New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  try {
    $zip = Join-Path $tmp 'paket.zip'
    Invoke-WebRequest -UseBasicParsing -TimeoutSec 120 -Uri "https://codeload.github.com/$($A.guncelleme)/zip/refs/heads/main" -OutFile $zip
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, (Join-Path $tmp 'ac'))
    $ic = Get-ChildItem (Join-Path $tmp 'ac') -Directory | Select-Object -First 1
    $src = Join-Path $ic.FullName 'AsortiAraci'
    foreach ($g in 'uygulama.html', 'asorti_araci.html', 'surum.json', 'sistem\sunucu.ps1', 'sistem\ortak.ps1', 'kopru\kopru.ps1') { if (-not (Test-Path (Join-Path $src $g))) { throw "indirilen pakette $g yok" } }
    $yeni = (Get-Content (Join-Path $src 'surum.json') -Raw -Encoding UTF8 | ConvertFrom-Json).surum; $eski = (YerelSurum $Root).surum
    # geri donebilmek icin simdiki surumu yedekle (sadece program dosyalari)
    $yd = Join-Path $Root 'yedek'; if (Test-Path $yd) { Remove-Item -Recurse -Force $yd }
    New-Item -ItemType Directory -Force -Path (Join-Path $yd 'sistem'), (Join-Path $yd 'kopru') | Out-Null
    foreach ($f in 'uygulama.html', 'asorti_araci.html', 'surum.json') { if (Test-Path (Join-Path $Root $f)) { Copy-Item (Join-Path $Root $f) $yd } }
    Copy-Item (Join-Path $Root 'sistem\*') (Join-Path $yd 'sistem') -Force
    Copy-Item (Join-Path $Root 'kopru\*.ps1') (Join-Path $yd 'kopru') -Force
    # yeni dosyalari yerine koy (ayarlar, calisma sayfalari, siparis kayitlari pakette yok, dokunulmaz)
    Copy-Item -Path (Join-Path $src '*') -Destination $Root -Recurse -Force
    $kp = Join-Path $ic.FullName 'kurulum'; if (Test-Path $kp) { $hk = Join-Path $Root 'kurulum_paketi'; if (Test-Path $hk) { Remove-Item -Recurse -Force $hk }; New-Item -ItemType Directory -Force -Path $hk | Out-Null; Copy-Item -Path (Join-Path $ic.FullName '*') -Destination $hk -Recurse -Force }
    Log "guncellendi: $eski -> $yeni"
    return $yeni
  } finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
}
function YenidenBaslat {
  Log 'sunucu yeni surumle yeniden baslatiliyor'
  foreach ($p in KopruSurecleri) { try { Stop-Process -Id $p.ProcessId -Force } catch {} }
  try { $L.Stop(); $L.Close() } catch {}
  try { $mtx.ReleaseMutex() } catch {}
  Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $Root 'sistem\sunucu.ps1'))
  exit
}

$L = New-Object Net.HttpListener
$L.Prefixes.Add("http://localhost:$Port/")
$L.Start(); Log "sunucu acildi: http://localhost:$Port/"
$tipler = @{ '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.json' = 'application/json; charset=utf-8'; '.txt' = 'text/plain; charset=windows-1254'; '.png' = 'image/png'; '.ico' = 'image/x-icon'; '.css' = 'text/css; charset=utf-8' }
$son = $null; $basla = Get-Date
function JsonYanit($ctx, $obj) { Yanit $ctx 200 ($utf8.GetBytes(($obj | ConvertTo-Json -Depth 5 -Compress))) 'application/json; charset=utf-8' }
function Yanit($ctx, [int]$kod, [byte[]]$veri, [string]$tip) {
  $r = $ctx.Response; $r.StatusCode = $kod; $r.Headers['Cache-Control'] = 'no-store'
  if ($tip) { $r.ContentType = $tip }
  if ($veri) { $r.ContentLength64 = $veri.Length; $r.OutputStream.Write($veri, 0, $veri.Length) }
  $r.OutputStream.Close()
}
$utf8 = New-Object Text.UTF8Encoding($false)
try {
  while ($true) {
    $t = $L.GetContextAsync()
    while (-not $t.Wait(1000)) {
      if ($son -and ((Get-Date) - $son).TotalSeconds -gt 30) { Kapat; $L.Stop(); exit }
      if (-not $son -and ((Get-Date) - $basla).TotalSeconds -gt 180) { Log 'pencere hic acilmadi'; Kapat; $L.Stop(); exit }
      if ($A.gerber -and $script:kopru.HasExited -and ((Get-Date) - $script:kBas).TotalSeconds -gt 30) { Log 'kopru durmustu, yeniden baslatiliyor'; KopruBaslat }
    }
    $ctx = $t.Result
    try {
      $yol = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
      $m = $ctx.Request.HttpMethod
      if ($yol -eq 'nabiz') { $son = Get-Date; JsonYanit $ctx @{ kopru = [bool]($script:kopru -and -not $script:kopru.HasExited); gerber = [bool]$A.gerber }; continue }
      if ($yol -eq 'surum') { $y = YerelSurum $Root; JsonYanit $ctx @{ surum = "$($y.surum)"; tarih = "$($y.tarih)"; gerber = [bool]$A.gerber; guncelleme = [bool]$A.guncelleme }; continue }
      if ($yol -eq 'guncelleme') {
        $y = YerelSurum $Root
        try { $u = UzakSurum ($ctx.Request.QueryString['taze'] -eq '1') } catch { JsonYanit $ctx @{ hata = 'Güncelleme sunucusuna ulaşılamadı: ' + $_.Exception.Message; yerel = "$($y.surum)" }; continue }
        if (-not $u) { JsonYanit $ctx @{ var = $false; yerel = "$($y.surum)"; kapali = $true }; continue }
        JsonYanit $ctx @{ var = ((SurumNo $u.surum) -gt (SurumNo $y.surum)); yerel = "$($y.surum)"; yeni = "$($u.surum)"; tarih = "$($u.tarih)"; notlar = @($u.notlar) }; continue
      }
      if ($yol -eq 'guncelle' -and $m -eq 'POST') {
        if (-not $A.guncelleme) { JsonYanit $ctx @{ hata = 'Güncelleme adresi ayarlı değil.' }; continue }
        if (SurenIs) { JsonYanit $ctx @{ hata = 'Gerber''de süren bir iş var. Pastallar bitince güncelle.' }; continue }
        try { $yeni = Guncelle } catch { Log ('guncelleme hatasi: ' + $_.Exception.Message); JsonYanit $ctx @{ hata = 'Güncellenemedi: ' + $_.Exception.Message }; continue }
        JsonYanit $ctx @{ ok = $true; surum = "$yeni" }
        YenidenBaslat
      }
      if ($yol -eq 'ping') { Yanit $ctx 200 ($utf8.GetBytes('ok')) 'text/plain'; continue }
      if ($yol -eq '') { $yol = 'uygulama.html' }
      if ($yol -match '\.\.' -or $yol -match ':') { Yanit $ctx 400 $null $null; continue }
      $dosya = Join-Path $Root ($yol -replace '/', '\')
      if ($m -eq 'GET') {
        if ((Test-Path $dosya -PathType Leaf) -and $tipler.ContainsKey([IO.Path]::GetExtension($dosya).ToLowerInvariant())) {
          $ext = [IO.Path]::GetExtension($dosya).ToLowerInvariant()
          $veri = $null; for ($i = 0; $i -lt 10 -and $null -eq $veri; $i++) { try { $fs = New-Object IO.FileStream($dosya, 'Open', 'Read', 'ReadWrite'); try { $ms = New-Object IO.MemoryStream; $fs.CopyTo($ms); $veri = $ms.ToArray() } finally { $fs.Close() } } catch { Start-Sleep -Milliseconds 100 } }
          if ($null -eq $veri) { Yanit $ctx 503 $null $null } else { Yanit $ctx 200 $veri $tipler[$ext] }
        } else { Yanit $ctx 404 $null $null }
      } elseif (($m -eq 'PUT' -or $m -eq 'POST') -and $yol -match '^kopru/(gelen|iptal)/[A-Za-z0-9._\-]+$') {
        $ms = New-Object IO.MemoryStream; $ctx.Request.InputStream.CopyTo($ms); $veri = $ms.ToArray()
        $gecici = $dosya + '.yaziliyor'; [IO.File]::WriteAllBytes($gecici, $veri); Move-Item -Force $gecici $dosya
        Yanit $ctx 200 $null $null
      } elseif ($m -eq 'DELETE' -and $yol -match '^kopru/gelen/[A-Za-z0-9._\-]+$') {
        if (Test-Path $dosya) { Remove-Item -Force $dosya; Yanit $ctx 200 $null $null } else { Yanit $ctx 404 $null $null }
      } else { Yanit $ctx 405 $null $null }
    } catch { Log ('istek hatasi: ' + $_.Exception.Message); try { Yanit $ctx 500 $null $null } catch {} }
  }
} finally { try { $L.Stop() } catch {} }
