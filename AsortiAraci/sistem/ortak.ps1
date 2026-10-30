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
    guncelleme = 'TheBurzzz/asorti-araci'   # GitHub deposu (yeni surumler buradan gelir)
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
