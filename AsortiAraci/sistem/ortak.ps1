# Asorti Araci - ortak ayarlar. Butun betikler bunu kullanir; ayarlar kurulum klasorundeki ayarlar.json'da.
function Ayarlar([string]$Kok) {
  $a = [ordered]@{
    kok      = $Kok
    port     = 8642
    accumark = 'C:\Program Files\Gerber Technology\AccuMark V12\AccuMark'
    userroot = 'C:\userroot'
    kuyruk   = '\\192.168.2.203\Users\Public\Gerber Technology\Queue\ultramrk.umq'
    surucu   = 'k:'
    surucu2  = 'z:'                    # OTOPASTAL'da ayni diskin ikinci harfi (birinci calismazsa denenir)
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
  return $a
}
function YerelSurum([string]$Kok) {
  try { return (Get-Content (Join-Path $Kok 'surum.json') -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return [pscustomobject]@{ surum = '0.0.0'; notlar = @() } }
}
