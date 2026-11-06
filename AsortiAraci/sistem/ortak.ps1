# Asorti Araci - ortak ayarlar. Butun betikler bunu kullanir; ayarlar kurulum klasorundeki ayarlar.json'da.
function Ayarlar([string]$Kok) {
  $a = [ordered]@{
    kok      = $Kok
    port     = 8642
    accumark = 'C:\Program Files\Gerber Technology\AccuMark V12\AccuMark'
    userroot = 'C:\userroot'          # AccuMark sistem klasoru (Batch'in engine.que ve bprmtbl'si burada)
    depo     = ''                      # musteri klasorlerinin oldugu userroot (bos: userroot ile ayni)
    kuyruk   = ''                      # OTOPASTAL (AccuNest) kuyruk dosyasi; bos: OTOPASTAL yok
    otopastal = ''                     # ayri (baska bilgisayarda) | ayni (bu bilgisayarda) | yok ; bos: kuyruk varsa ayri
    surucu   = 'k:'                    # OTOPASTAL bu bilgisayarin pastallarina hangi harfle ulasiyor
    surucu2  = 'z:'                    # ikinci harf (birinci calismazsa denenir)
    tarayici = ''
    gerber   = $true                   # false: Gerber/OTOPASTAL yok, sadece asorti
    guncelleme = 'TheBurzzz/eleman'   # GitHub deposu (yeni surumler buradan gelir; eski adi asorti-araci, GitHub yonlendirir)
  }
  $f = Join-Path $Kok 'ayarlar.json'
  if (Test-Path $f) {
    try {
      $j = Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($p in $j.PSObject.Properties) { if ($null -ne $p.Value -and "$($p.Value)" -ne '') { $a[$p.Name] = $p.Value } }
    } catch {}
  }
  $a.kok = $Kok
  $a.port = [int]$a.port
  $a.gerber = -not ("$($a.gerber)" -match '^(?i)(false|0|hayir|no)$')
  $a.surucu = ("$($a.surucu)".TrimEnd(':', '\') + ':').ToLowerInvariant()
  if (-not $a.depo) { $a.depo = $a.userroot }
  $a.otopastal = "$($a.otopastal)".ToLowerInvariant()
  if ($a.otopastal -notin @('ayri', 'ayni', 'yok')) { $a.otopastal = $(if ($a.kuyruk) { 'ayri' } else { 'yok' }) }
  if (-not $a.kuyruk) { $a.otopastal = 'yok' }
  return $a
}
# ayarlar.json'daki verilen anahtarlari degistirir, digerlerine dokunmaz
function AyarYaz([string]$Kok, $degisen) {
  $f = Join-Path $Kok 'ayarlar.json'; $h = [ordered]@{}
  if (Test-Path $f) { try { (Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value } } catch {} }
  foreach ($k in @($degisen.Keys)) { $h[$k] = $degisen[$k] }
  $tmp = $f + '.yeni'
  [IO.File]::WriteAllText($tmp, ($h | ConvertTo-Json), (New-Object Text.UTF8Encoding($true)))
  Move-Item -Force -LiteralPath $tmp -Destination $f
}
function YerelSurum([string]$Kok) {
  try { return (Get-Content (Join-Path $Kok 'surum.json') -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return [pscustomobject]@{ surum = '0.0.0'; notlar = @() } }
}

# uygulamanin kendisi (sistem\uygulama\*.cs) bu bilgisayarda .NET Framework'un derleyicisiyle derlenir: sistem\AsortiAraci.exe
# Parmak izi uygulamanin kendi hesabiyla (Derleyici.Damga) birebir aynidir; degismediyse yeniden derlenmez.
# uygulama\derleme.txt: derlenirken hangi kitapliklara basvurulacagi (uygulamanin kendi hesabiyla, Derleyici.Basvurular, birebir ayni)
function UygulamaBasvurulari([string]$uk) {
  $f = Join-Path $uk 'derleme.txt'; if (Test-Path -LiteralPath ($f + '.yeni')) { $f += '.yeni' }
  $l = @(); if (Test-Path -LiteralPath $f) { $l = @(Get-Content -LiteralPath $f -Encoding UTF8 | ForEach-Object { $_.Trim().TrimStart([char]0xFEFF) } | Where-Object { $_ -and -not $_.StartsWith('#') }) }
  if (-not $l.Count) { $l = @('System.dll', 'System.Core.dll', 'System.Drawing.dll', 'System.Windows.Forms.dll', 'System.Management.dll', 'System.IO.Compression.dll', 'System.IO.Compression.FileSystem.dll', 'gac:System.Management.Automation', 'sistem:Microsoft.Web.WebView2.Core.dll', 'sistem:Microsoft.Web.WebView2.WinForms.dll') }
  return ,$l
}
# Windows'un ortak kitapligindaki (GAC) en yeni 4.x surumu (or. PowerShell motoru)
function GacYolu([string]$ad) {
  $kok = Join-Path $env:WINDIR 'Microsoft.NET\assembly'
  foreach ($g in @('GAC_MSIL', $(if ([Environment]::Is64BitProcess) { 'GAC_64' } else { 'GAC_32' }))) {
    $d = Join-Path (Join-Path $kok $g) $ad; if (-not (Test-Path -LiteralPath $d)) { continue }
    [string[]]$alt = @(Get-ChildItem -LiteralPath $d -Directory -Filter 'v4.0_*' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }); [Array]::Sort($alt, [StringComparer]::OrdinalIgnoreCase)
    for ($i = $alt.Count - 1; $i -ge 0; $i--) { $f = Join-Path $alt[$i] ($ad + '.dll'); if (Test-Path -LiteralPath $f) { return $f } }
  }
  return $null
}
function UygulamaDamga([string]$Kok) {
  $sis = Join-Path $Kok 'sistem'; $uk = Join-Path $sis 'uygulama'
  [string[]]$cs = @(Get-ChildItem -LiteralPath $uk -Filter *.cs -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
  [Array]::Sort($cs, [StringComparer]::OrdinalIgnoreCase)
  $liste = @($cs) + @((Join-Path $uk 'uygulama.manifest'), (Join-Path $uk 'derleme.txt'))
  foreach ($b in (UygulamaBasvurulari $uk)) { if ($b -like 'sistem:*') { $liste += (Join-Path $sis $b.Substring(7)) } }
  $ms = New-Object IO.MemoryStream
  foreach ($f in $liste) {
    $g = $(if (Test-Path -LiteralPath ($f + '.yeni')) { $f + '.yeni' } else { $f }); if (-not (Test-Path -LiteralPath $g)) { continue }
    $ad = [Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFileName($f).ToLowerInvariant() + '|'); $ms.Write($ad, 0, $ad.Length)
    $v = [IO.File]::ReadAllBytes($g); $ms.Write($v, 0, $v.Length)
  }
  $md5 = [Security.Cryptography.MD5]::Create()
  try { return ([BitConverter]::ToString($md5.ComputeHash($ms.ToArray()))).Replace('-', '') } finally { $md5.Dispose() }
}
function UygulamaDerle([string]$Kok) {
  $ErrorActionPreference = 'Continue'   # cagiran 'Stop' kullansa da derleyicinin ciktisi hata sayilmasin
  $sis = Join-Path $Kok 'sistem'; $uk = Join-Path $sis 'uygulama'
  if (-not (Test-Path -LiteralPath (Join-Path $uk 'Program.cs'))) { return $false }
  $exe = Join-Path $sis 'AsortiAraci.exe'; $damgaF = Join-Path $sis 'AsortiAraci.surum'; $damga = UygulamaDamga $Kok
  if ((Test-Path -LiteralPath $exe) -and ("$(Get-Content -LiteralPath $damgaF -Raw -ErrorAction SilentlyContinue)".Trim() -eq $damga)) { return $true }   # guncel
  $csc = Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'csc.exe'
  $kayit = Join-Path $Kok 'kopru\log\uygulama_derleme.txt'
  if (-not (Test-Path -LiteralPath $csc)) { try { Set-Content -LiteralPath $kayit -Value 'csc.exe bulunamadi' -Encoding UTF8 } catch {}; return $false }
  $yeni = Join-Path $sis 'AsortiAraci.yeni.exe'; Remove-Item -LiteralPath $yeni -Force -ErrorAction SilentlyContinue
  $arg = @('/nologo', '/target:winexe', '/optimize+', '/platform:anycpu', '/codepage:65001', "/out:$yeni", ('/win32icon:' + $(if (Test-Path -LiteralPath (Join-Path $sis 'eleman.ico')) { Join-Path $sis 'eleman.ico' } else { Join-Path $sis 'asorti.ico' })), ('/win32manifest:' + (Join-Path $uk 'uygulama.manifest')))
  foreach ($b in (UygulamaBasvurulari $uk)) {
    if ($b -like 'sistem:*') { $f = Join-Path $sis $b.Substring(7); if (Test-Path -LiteralPath ($f + '.yeni')) { $f += '.yeni' }; $arg += "/r:$f" }
    elseif ($b -like 'gac:*') { $g = GacYolu $b.Substring(4); $arg += $(if ($g) { "/r:$g" } else { '/r:' + $b.Substring(4) + '.dll' }) }
    elseif ($b.StartsWith('/')) { if ($b -match '^/[A-Za-z0-9:+.\-]+$') { $arg += $b } }
    else { $arg += "/r:$b" }
  }
  [string[]]$kaynak = @(Get-ChildItem -LiteralPath $uk -Filter *.cs -File | ForEach-Object { $_.FullName }); [Array]::Sort($kaynak, [StringComparer]::OrdinalIgnoreCase)
  $cikti = (& $csc @arg @kaynak 2>&1 | Out-String)
  $ok = ($LASTEXITCODE -eq 0) -and (Test-Path -LiteralPath $yeni)
  try { Set-Content -LiteralPath $kayit -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + $(if ($ok) { ' derlendi' } else { ' DERLENEMEDI' }) + "`r`n" + $cikti) -Encoding UTF8 } catch {}
  if (-not $ok) { return $false }
  [IO.File]::WriteAllText((Join-Path $sis 'AsortiAraci.yeni.surum'), $damga, [Text.Encoding]::ASCII)
  # uygulama su an acik degilse hemen yerine koy (aciksa kendisi bir sonraki acilista koyar)
  if (-not (Get-Process -Name AsortiAraci -ErrorAction SilentlyContinue)) {
    try {
      if (Test-Path -LiteralPath $exe) { Remove-Item -LiteralPath $exe -Force -ErrorAction Stop }
      Move-Item -LiteralPath $yeni -Destination $exe -Force
      Move-Item -LiteralPath (Join-Path $sis 'AsortiAraci.yeni.surum') -Destination $damgaF -Force
    } catch {}
  }
  return $true
}
