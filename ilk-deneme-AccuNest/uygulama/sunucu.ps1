# Asorti Araci - yerel sunucu: uygulama penceresini sunar, Gerber koprusunu arka planda calistirir,
# pencere kapaninca kopruyu ve Batch'i de kapatir.
param([string]$Root = 'C:\AccuNest', [int]$Port = 8642)
$ErrorActionPreference = 'Stop'
$mtx = New-Object Threading.Mutex($false, 'AsortiAraciSunucu')
if (-not $mtx.WaitOne(0)) { exit }
$LOG = Join-Path $Root 'kopru\log\sunucu.txt'
function Log($s) { try { Add-Content -Path $LOG -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $s) -Encoding UTF8 } catch {} }

# eski (gorunur pencereli) kopru calisiyorsa kapat; artik kopruyu bu sunucu yonetiyor
function KopruSurecleri { @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'kopru\\kopru\.ps1' }) }
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
KopruBaslat

$L = New-Object Net.HttpListener
$L.Prefixes.Add("http://localhost:$Port/")
$L.Start(); Log "sunucu acildi: http://localhost:$Port/"
$tipler = @{ '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.json' = 'application/json; charset=utf-8'; '.txt' = 'text/plain; charset=windows-1254'; '.png' = 'image/png'; '.ico' = 'image/x-icon'; '.css' = 'text/css; charset=utf-8' }
$son = $null
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
      if ($script:kopru.HasExited -and ((Get-Date) - $script:kBas).TotalSeconds -gt 30) { Log 'kopru durmustu, yeniden baslatiliyor'; KopruBaslat }
    }
    $ctx = $t.Result
    try {
      $yol = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
      $m = $ctx.Request.HttpMethod
      if ($yol -eq 'nabiz') { $son = Get-Date; Yanit $ctx 200 ($utf8.GetBytes('{"kopru":' + $(if ($script:kopru -and -not $script:kopru.HasExited) { 'true' } else { 'false' }) + '}')) 'application/json'; continue }
      if ($yol -eq 'ping') { Yanit $ctx 200 ($utf8.GetBytes('ok')) 'text/plain'; continue }
      if ($yol -eq '') { $yol = 'uygulama.html' }
      if ($yol -match '\.\.' -or $yol -match ':') { Yanit $ctx 400 $null $null; continue }
      $dosya = Join-Path $Root ($yol -replace '/', '\')
      if ($m -eq 'GET') {
        if (Test-Path $dosya -PathType Leaf) {
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
