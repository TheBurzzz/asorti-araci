# Asorti Araci - bu bilgisayarı tarar: Gerber AccuMark, müşteri klasörleri, OTOPASTAL (AccuNest kuyruğu) ve sürücü harfi.
# Hiçbir ayarı değiştirmez; bulduklarını JSON olarak yazar (kurulum sihirbazı ve ayarlar menüsü bunu okur).
#   -Cikti <dosya>   sonucu bu dosyaya yaz (yoksa ekrana)
#   -AyarKok <klasör> şu anki ayarlar bu kurulumdan okunur (yoksa bu paketin klasörü)
#   -Taze            şu anki ayarları hiç kullanma (ilk kurulum gibi ara)
#   -AgYok           ağdaki bilgisayarlara bakma (sadece bu bilgisayar ve bağlı sürücüler)
param([string]$Cikti = '', [string]$AyarKok = '', [switch]$Taze, [switch]$AgYok)
$ErrorActionPreference = 'Continue'
$Kok = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $Kok 'sistem\ortak.ps1')
. (Join-Path $Kok 'sistem\bul.ps1')
if (-not $AyarKok) { $AyarKok = $Kok }
$eski = $null
if (-not $Taze -and (Test-Path (Join-Path $AyarKok 'ayarlar.json'))) { $eski = Ayarlar $AyarKok }
$r = $null
try { $r = GerberBul -Eski $eski -AgTara:(-not $AgYok) -Tam:$Taze }
catch { $r = [pscustomobject]@{ hata = $_.Exception.Message; satir = $_.InvocationInfo.ScriptLineNumber; zaman = (Get-Date).ToString('s') } }
$y = YerelSurum $Kok
$r | Add-Member -NotePropertyName surum -NotePropertyValue ("" + $y.surum) -Force
$r | Add-Member -NotePropertyName taze -NotePropertyValue ([bool]$Taze) -Force
$json = $r | ConvertTo-Json -Depth 7
if ($Cikti) {
  $tmp = $Cikti + '.yaziliyor'
  [IO.File]::WriteAllText($tmp, $json, (New-Object Text.UTF8Encoding($false)))
  Move-Item -Force -LiteralPath $tmp -Destination $Cikti
} else { $json }
# ağda cevap vermeyen bir bilgisayarı bekleyen arka plan aramaları kalmışsa süreci beklemeden kapat
[Environment]::Exit(0)
