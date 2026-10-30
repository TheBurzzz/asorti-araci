# Asorti Araci - Gerber Koprusu
# gelen\ klasorune dusen siparis dosyalarini: Gerber'e alir -> Batch ile pastal yapar ->
# OTOPASTAL kuyruguna yollar -> sonuclari sonuc\ klasorune yazar.
$ErrorActionPreference = 'Stop'
$mtx = New-Object Threading.Mutex($false, 'AsortiGerberKopru')
if (-not $mtx.WaitOne(0)) { Write-Host 'Kopru zaten calisiyor.'; Start-Sleep 3; exit }
try { $Host.UI.RawUI.WindowTitle = 'Gerber koprusu' } catch {}
# konsol penceresine tiklayinca programin donmamasi icin "Hizli Duzenleme"yi kapat
try {
  Add-Type -Namespace W -Name C -MemberDefinition '[DllImport("kernel32.dll")] public static extern System.IntPtr GetStdHandle(int h); [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(System.IntPtr h, out uint m); [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(System.IntPtr h, uint m);'
  $hIn = [W.C]::GetStdHandle(-10); [uint32]$mode = 0; [void][W.C]::GetConsoleMode($hIn, [ref]$mode); [void][W.C]::SetConsoleMode($hIn, [uint32](([uint64]$mode -bor 0x80) -band 0xFFFFFFBF))
} catch {}
$K      = Split-Path -Parent $MyInvocation.MyCommand.Path       # ...\kopru
$KOK    = Split-Path -Parent $K                                 # kurulum klasoru
. (Join-Path $KOK 'sistem\ortak.ps1'); $A = Ayarlar $KOK
# otomatik bulma yardimcilari (yuklenemezse kopru eskisi gibi calisir, sadece kendi kendini onarma kapali olur)
$script:bulHata = ''; try { . (Join-Path $KOK 'sistem\bul.ps1') } catch { $script:bulHata = $_.Exception.Message }
$script:bulVar = -not $script:bulHata -and [bool](Get-Command AccuMarkGecerli -ErrorAction SilentlyContinue)
$AM     = $A.accumark
$UR     = $A.userroot                                           # AccuMark sistem klasoru (Batch dosyalari)
$STOR   = Join-Path $A.depo 'storage'                           # musteri klasorleri
$ENGQ   = Join-Path $UR 'engine.que'
$BPRM   = Join-Path $UR 'bprmtbl'
$DRV    = $(if ("$($A.depo)" -match '^([A-Za-z]:)') { $matches[1] } else { 'C:' })   # musteri klasorlerinin surucusu (C:)
$QUEUE  = $A.kuyruk
$OTO    = $A.otopastal                                          # ayri | ayni | yok
$DEV    = $A.surucu
# OTOPASTAL bu bilgisayarin C: diskini hangi harfle goruyor: once ayarlardaki (k:), olmazsa yedek (z:).
# Calisan harf hatirlanir (kopru\surucu.txt); OTOPASTAL'da bir harfin baglantisi koparsa digeri denenir.
$DEVS   = @(@($A.surucu, $A.surucu2) | Where-Object { $_ } | ForEach-Object { ("$_".TrimEnd(':', '\') + ':').ToLowerInvariant() } | Select-Object -Unique)
$DEVF   = Join-Path $K 'surucu.txt'
if (Test-Path $DEVF) { $t = ("" + (Get-Content $DEVF -Raw -ErrorAction SilentlyContinue)).Trim().ToLowerInvariant(); if ($DEVS -contains $t) { $DEV = $t } }
function DigerSurucu($d) { $x = @($DEVS | Where-Object { $_ -ne $d }); if ($x.Count) { return $x[0] } else { return $d } }
function SurucuTercih($d) { if ($script:DEV -ne $d) { $script:DEV = $d; try { Set-Content -Path $DEVF -Value $d -Encoding ASCII } catch {}; Log "OTOPASTAL artik $d harfiyle kullaniliyor" } }
$enc    = [Text.Encoding]::GetEncoding(28591)
$tr     = [Text.Encoding]::GetEncoding(1254)
foreach ($d in 'gelen','isleniyor','bitti','sonuc','log','iptal') { New-Item -ItemType Directory -Force -Path (Join-Path $K $d) | Out-Null }
$LOGF = Join-Path $K ('log\kopru_' + (Get-Date -Format 'yyyy-MM-dd') + '.txt')
# Gerber programlarini calistirir; hata akisina yazsalar bile isi durdurmaz, butun ciktiyi metin olarak dondurur
function Yerel([scriptblock]$b) { $ErrorActionPreference = 'Continue'; Push-Location $AM; try { (& $b 2>&1 | ForEach-Object { "$_" }) -join "`r`n" } finally { Pop-Location } }
function Log($s) { $l = (Get-Date -Format 'HH:mm:ss') + ' ' + $s; Add-Content -Path $LOGF -Value $l -Encoding UTF8; Write-Host $l }

function Durum($base, $h) { $h.zaman = (Get-Date -Format 's'); ($h | ConvertTo-Json -Depth 5) | Set-Content -Path (Join-Path $K "sonuc\$base.json") -Encoding UTF8 }

# AccuMark .ctl dosyasindaki isimler (64 baytlik kayitlar)
function CtlNames($area, $kind) {
  $f = Join-Path $STOR "$area\data\$kind.ctl"; if (-not (Test-Path $f)) { return @() }
  $b = ReadShared $f; $r = @(); if ($null -eq $b) { return $r }
  for ($i = 0; $i + 64 -le $b.Length; $i += 64) { if ($b[$i + 25] -ne 0) { continue }; $n = $enc.GetString($b, $i, 20).Split([char]0)[0].Trim(); if ($n) { $r += $n.ToUpperInvariant() } }  # 25. bayt 0 degilse kayit silinmis (cop kutusunda)
  return $r
}

# ctl kayitlarinin olusma / degisme zamani (Unix sn): 26. bayt olusturma, 30. bayt son degisiklik
function CtlZaman($area, $kind) {
  $f = Join-Path $STOR "$area\data\$kind.ctl"; $z = @{}; if (-not (Test-Path $f)) { return $z }
  $b = ReadShared $f; if ($null -eq $b) { return $z }
  for ($i = 0; $i + 64 -le $b.Length; $i += 64) {
    if ($b[$i + 25] -ne 0) { continue }; $n = $enc.GetString($b, $i, 20).Split([char]0)[0].Trim().ToUpperInvariant(); if (-not $n) { continue }
    $t = [math]::Max([BitConverter]::ToUInt32($b, $i + 26), [BitConverter]::ToUInt32($b, $i + 30)); if (-not $z.ContainsKey($n) -or $z[$n] -lt $t) { $z[$n] = $t }
  }
  return $z
}

# kuyruk dosyasini oku: @{state;entries=@(@{job;st;d})}
function ReadQueue {
  $b = ReadShared $QUEUE; if ($null -eq $b) { throw 'kuyruk dosyasi su an okunamiyor' }; $cnt = [BitConverter]::ToUInt32($b, 4); $p = 8; $list = New-Object System.Collections.ArrayList
  for ($i = 0; $i -lt $cnt; $i++) {
    $tag = [BitConverter]::ToUInt16($b, $p); $p += 2
    if ($tag -eq 0xFFFF) { $p += 2; $ln = [BitConverter]::ToUInt16($b, $p); $p += 2 + $ln }
    $job = [BitConverter]::ToUInt32($b, $p); $st = [BitConverter]::ToUInt32($b, $p + 4); $np = [BitConverter]::ToUInt32($b, $p + 8); $p += 12
    $d = @{}
    for ($k = 0; $k -lt 2 * $np; $k++) {
      $L = [int]$b[$p]; $p++; if ($L -eq 255) { $L = [int][BitConverter]::ToUInt16($b, $p); $p += 2 }
      $s = $enc.GetString($b, $p, $L); $p += $L
      if ($k % 2 -eq 0) { $key = $s } else { $d[$key] = $s }
    }
    [void]$list.Add(@{ job = $job; st = $st; d = $d })
  }
  return ,$list
}

function BatchTable($area) {
  $name = 'AS-' + ($area -replace '[^A-Za-z0-9]', '')
  $f = Join-Path $BPRM "$name.bpm"
  if (-not (Test-Path $f)) {
    $b = [IO.File]::ReadAllBytes((Join-Path $KOK 'sistem\sablon.bpm'))
    $a8 = $enc.GetBytes($area.ToUpperInvariant().PadRight(8).Substring(0, 8)); [Array]::Copy($a8, 0, $b, 0, 8)
    $a16 = $enc.GetBytes($area.ToUpperInvariant().PadRight(16).Substring(0, 16))
    [Array]::Copy($a16, 0, $b, 285, 16); [Array]::Copy($a16, 0, $b, 3073, 16)
    [IO.File]::WriteAllBytes($f, $b); Log "Batch tablosu olusturuldu: $name"
  }
  return (Join-Path $BPRM $name)
}

# baska programin acik tuttugu dosyayi paylasimli oku (Batch engine.que'yu acik tutuyor)
function ReadShared($path) {
  for ($i = 0; $i -lt 20; $i++) {
    try {
      $fs = New-Object IO.FileStream($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
      try { $ms = New-Object IO.MemoryStream; $fs.CopyTo($ms); return ,$ms.ToArray() } finally { $fs.Close() }
    } catch { Start-Sleep -Milliseconds 300 }
  }
  return $null
}

function EngineCount { if (-not (Test-Path $ENGQ)) { return 0 }; $x = ReadShared $ENGQ; if ($null -eq $x) { return 0 }; $t = $enc.GetString($x); return ([regex]::Matches($t, 'amordprc')).Count }
function EngineStatus($skip, $order) {
  if (-not (Test-Path $ENGQ)) { return '' }
  $x = ReadShared $ENGQ; if ($null -eq $x) { return '' }; $t = $tr.GetString($x); $parts = $t -split 'amordprc'
  for ($i = $parts.Count - 1; $i -ge 1 + $skip; $i--) {
    if ($parts[$i] -match ('\s' + [regex]::Escape($order) + '\s')) {
      if ($parts[$i] -match 'TAMAMLANDI|COMPLETED') { return 'ok' }
      if ($parts[$i] -match 'BA.ARISIZ|HATA|FAILED|IPTAL|CANCEL') { return 'hata' }
      return 'bekliyor'
    }
  }
  return ''
}

# modeldeki parcalarin kumas tipleri (K, H, A, S ...): model.ctl -> model???.mod
$script:mkCache = @{}
function ModelKumas($area) {
  $ctl = Join-Path $STOR "$area\data\model.ctl"
  if (-not (Test-Path $ctl)) { return @() }
  $t = (Get-Item $ctl).LastWriteTimeUtc.Ticks
  if ($script:mkCache.ContainsKey($area) -and $script:mkCache[$area].t -eq $t) { return $script:mkCache[$area].v }
  $b = ReadShared $ctl; $v = @(); $files = @{}
  if ($null -ne $b) {
    for ($i = 0; $i + 64 -le $b.Length; $i += 64) {
      if ($b[$i + 25] -ne 0) { continue }
      $name = $enc.GetString($b, $i, 20).Split([char]0)[0].Trim().ToUpperInvariant(); $suf = $enc.GetString($b, $i + 20, 3)
      if (-not $name -or $suf -notmatch '^[a-z]{3}$') { continue }
      $slot = [int]$b[$i + 23]; $kum = @()
      try {
        if (-not $files.ContainsKey($suf)) { $files[$suf] = ReadShared (Join-Path $STOR "$area\data\model$suf.mod") }
        $m = $files[$suf]
        if ($null -ne $m) {
          $e = 16 + 64 * $slot; $off = [int][BitConverter]::ToUInt32($m, $e); $sz = [int][BitConverter]::ToUInt32($m, $e + 4)
          if ($off -gt 0 -and $off + $sz -le $m.Length) {
            $sec = $enc.GetString($m, $off, $sz); $j = 0
            while (($j = $sec.IndexOf('=+', $j, [StringComparison]::Ordinal)) -ge 0 -and $j + 41 -le $sec.Length) { $f = $sec.Substring($j + 37, 4).Split([char]0)[0]; if (-not $f) { $f = '_' }; if ($kum -notcontains $f) { $kum += $f }; $j += 2 }
          }
        }
      } catch {}
      $v += [pscustomobject]@{ ad = $name; kumas = ($kum -join ',') }
    }
  }
  $script:mkCache[$area] = @{ t = $t; v = $v }
  return $v
}

# musteri klasorleri listesi (programdaki secim kutusu icin): ad, son kullanim, icindeki modeller ve kumas tipleri
function Alanlar {
  $L = @()
  foreach ($d in (Get-ChildItem -Path $STOR -Directory -ErrorAction SilentlyContinue)) {
    $son = $d.LastWriteTime
    foreach ($c in 'mark','order','model') { $f = Join-Path $d.FullName "data\$c.ctl"; if (Test-Path $f) { $t = (Get-Item $f).LastWriteTime; if ($t -gt $son) { $son = $t } } }
    $L += [pscustomobject]@{ ad = $d.Name.ToUpperInvariant(); son = $son.ToString('yyyy-MM-dd HH:mm'); modeller = @(ModelKumas $d.Name) }
  }
  $L = @($L | Sort-Object son -Descending)
  $o = [pscustomobject]@{ zaman = (Get-Date -Format 's'); alanlar = $L }
  ($o | ConvertTo-Json -Depth 5 -Compress) | Set-Content -Path (Join-Path $K 'alanlar.json') -Encoding UTF8
}

# ---------- isler ----------
# Her is (gelen\ klasorune dusen siparis dosyasi) asama asama ilerler ve birbirini beklemez:
#   1) siparisler Gerber'e alinir (ve varsa deneme pastallari uretim adiyla kopyalanir)  -> hemen
#   2) 'pastal'  : Batch pastallari hazirlar                                              -> beklenir, bu arada diger isler ilerler
#   3) 'yerlesim': OTOPASTAL kuyrugunda yerlesir                                          -> beklenir, bu arada diger isler ilerler
# Boylece ikinci model, birincisi OTOPASTAL'da yerlesirken Gerber'e alinip kuyruga girer.
# Ayni isimli pastallari ya da ayni modelin deneme pastallarini kullanan isler yine sirayla calisir.
$script:isler = [ordered]@{}
$script:kuyrukImza = ''; $script:kuyrukDegisim = Get-Date; $script:kuyrukOkuma = [datetime]::MinValue; $script:kuyrukHataLog = [datetime]::MinValue
$inv = [Globalization.CultureInfo]::InvariantCulture

# pastal dosyasindan en / boy / verim (mark.ctl -> mark???.mar; programdaki "Gerber'den boy ve verimi al" ile ayni yer)
function PastalOku($area, $ad) {
  $dd = Join-Path $STOR "$area\data"; $c = ReadShared (Join-Path $dd 'mark.ctl')
  if ($null -eq $c) { return @{ var = $false; mesaj = 'mark.ctl okunamadi' } }
  $ad = $ad.ToUpperInvariant(); $kay = $null
  for ($i = 0; $i + 64 -le $c.Length; $i += 64) {
    if ($c[$i + 25] -ne 0) { continue }
    $n = $enc.GetString($c, $i, 20).Split([char]0)[0].Trim()
    if ($n.ToUpperInvariant() -eq $ad) { $kay = @{ ek = $enc.GetString($c, $i + 20, 3); slot = [int]$c[$i + 23] } }
  }
  if (-not $kay) { return @{ var = $false; mesaj = 'pastal yok' } }
  $m = ReadShared (Join-Path $dd ('mark' + $kay.ek + '.mar')); if ($null -eq $m) { return @{ var = $false; mesaj = 'pastal dosyasi okunamadi' } }
  $o = [BitConverter]::ToUInt32($m, 16 + 64 * $kay.slot); $u = [BitConverter]::ToUInt32($m, 20 + 64 * $kay.slot)
  if ($o + 316 -gt $m.Length -or $u -lt 316) { return @{ var = $false; mesaj = 'pastal kaydi okunamadi' } }
  $en = [BitConverter]::ToDouble($m, $o + 258) * 2.54; $boy = [BitConverter]::ToDouble($m, $o + 274) * 2.54; $ver = [BitConverter]::ToDouble($m, $o + 308)
  if ([double]::IsNaN($boy) -or $boy -lt 0 -or $boy -gt 100000 -or [double]::IsNaN($ver) -or $ver -lt 0 -or $ver -gt 100 -or [double]::IsNaN($en)) { return @{ var = $false; mesaj = 'pastal kaydi taninmadi' } }
  return @{ var = $true; en_cm = [math]::Round($en, 2); boy_cm = [math]::Round($boy, 2); verim = [math]::Round($ver, 2) }
}

# "En verimli asortiyi bul" denemesinde OTOPASTAL'da yerlesip kaydedilmis pastali uretim adiyla kopyalar: yeniden yerlestirmeye gerek kalmaz.
# Sadece deneme pastali yerlesmisse ve kumas eni ayniysa kopyalanir; kopyanin boyu ve verimi denemeyle ayni degilse
# kopya sayilmaz, o pastal her zamanki gibi Batch ve OTOPASTAL'dan gecer. Siparis (order) uretim adiyla ayrica Gerber'e alinir,
# yani sonradan siparisi guncelleyip yeniden islersen pastal yine uretim adiyla olusur.
function KopyaYap($area, $src, $dst, $w) {
  try {
    $a = PastalOku $area $src
    if (-not $a.var -or -not ($a.boy_cm -gt 0) -or -not ($a.verim -gt 0)) { Log "$dst : $src kopyalanamadi ($(if ($a.var) { 'yerlesmemis' } else { $a.mesaj })), yeniden yerlestirilecek"; return $null }
    if ($w -and [math]::Abs($a.en_cm - $w) -gt 0.05) { Log "$dst : $src kumas eni farkli ($($a.en_cm) / $w cm), yeniden yerlestirilecek"; return $null }
    $vardi = (CtlNames $area 'mark') -contains $dst
    $o = Yerel { @('Y', 'Y', 'Y') | & .\amcopy.exe -y marker ($DRV + $area) $src ($DRV + $area) $dst }
    $b = PastalOku $area $dst
    $tutar = $b.var -and [math]::Abs($b.boy_cm - $a.boy_cm) -le 0.05 -and [math]::Abs($b.verim - $a.verim) -le 0.05 -and [math]::Abs($b.en_cm - $a.en_cm) -le 0.05
    if ($tutar -and $vardi -and $o -notmatch '(?i)\bcopy\b') { $tutar = $false }   # eskiden kalan ayni adli pastali kopya sanma
    if (-not $tutar -or $o -match '(?i)\berror\b|hata') { Log ("$dst : $src kopyalanamadi (" + ($o.Trim() -replace '\s+', ' ') + '), yeniden yerlestirilecek'); return $null }
    Log ("$dst : $src pastalindan kopyalandi, boy $($b.boy_cm) cm verim %$($b.verim) | " + ($o.Trim() -replace '\s+', ' '))
    return @{ ad = $dst; tamam = $true; kaydedildi = $true; boy_cm = $b.boy_cm; verim = $b.verim; adet = 0; sonuc = 'kopyalandi'; kaynak = $src }
  } catch { Log "$dst : $src kopyalanamadi: $($_.Exception.Message)"; return $null }
}

function IsOzeti($path) {
  $o = @(); $m = @(); $t = $false
  foreach ($l in @(Get-Content -Path $path -Encoding Default -ErrorAction SilentlyContinue)) {
    if ($l -match '^o:(.+)$') { $o += $matches[1].Trim().ToUpperInvariant() }
    elseif ($l -match '^m:(.+)$') { $m += $matches[1].Trim().ToUpperInvariant() }
    elseif ($l -match '^#\s*temizle-deneme\s*:\s*evet') { $t = $true }
  }
  return @{ orders = @($o); mods = @($m | Sort-Object -Unique); temiz = $t }
}
# yeni is suren bir isle cakisiyor mu: ayni adli pastal ya da (deneme pastallarini silecekse) ayni model
function Cakisiyor($f) {
  if (-not $script:isler.Count) { return $false }
  $z = IsOzeti $f.FullName
  foreach ($j in @($script:isler.Values)) {
    if (@($z.orders | Where-Object { $j.orders -contains $_ }).Count) { return $true }
    if ($z.temiz -and @($z.mods | Where-Object { $j.mods -contains $_ }).Count) { return $true }
  }
  return $false
}
# gelen\ klasorunde bekleyenler programda "sirada" gorunsun
function SiradakileriYaz {
  Get-ChildItem -Path (Join-Path $K 'gelen') -Filter *.txt -ErrorAction SilentlyContinue | ForEach-Object {
    $qb = [IO.Path]::GetFileNameWithoutExtension($_.Name)
    if (-not (Test-Path (Join-Path $K "sonuc\$qb.json"))) { Durum $qb @{ dosya = $_.Name; asama = 'sirada'; mesaj = ''; pastallar = @() } }
  }
}
function IsKapat($j) {
  try { if (Test-Path $j.work) { Move-Item -Force $j.work (Join-Path $K "bitti\$($j.dosya)") } } catch {}
  $script:isBitti = Get-Date; IptalTemizle $j.base
  if ($script:isler.Contains($j.base)) { $script:isler.Remove($j.base) }
}
function IsHata($j, $msg) { $j.res.asama = 'hata'; $j.res.mesaj = $msg; Durum $j.base $j.res; Log "$($j.base) : HATA $msg"; IsKapat $j }

function IsBasla($file) {
  $base = [IO.Path]::GetFileNameWithoutExtension($file.Name)
  $work = Join-Path $K "isleniyor\$($file.Name)"; Move-Item -Force $file.FullName $work
  $lines = Get-Content -Path $work -Encoding Default
  $area = ''; $over = $false; $orders = @(); $mods = @(); $temiz = $false; $nq = @(); $kopya = [ordered]@{}; $wOf = @{}; $cur = ''
  foreach ($l in $lines) {
    if ($l -match '^#\s*alan\s*:\s*(\S+)') { $area = $matches[1].ToUpperInvariant() }
    if ($l -match '^#\s*uzerine-yaz\s*:\s*evet') { $over = $true }
    if ($l -match '^o:(.+)$') { $cur = $matches[1].Trim().ToUpperInvariant(); $orders += $cur }
    if ($l -match '^w:\s*([0-9]+(?:[.,][0-9]+)?)' -and $cur) { $wOf[$cur] = [double]::Parse($matches[1].Replace(',', '.'), $inv) }
    if ($l -match '^m:(.+)$') { $mods += $matches[1].Trim().ToUpperInvariant() }
    if ($l -match '^#\s*temizle-deneme\s*:\s*evet') { $temiz = $true }
    # Gerber'de olusturulacak ama OTOPASTAL'a gonderilmeyecek pastallar (ek asorti tablolari)
    if ($l -match '^#\s*kuyruksuz\s*:\s*(.+)$') { $nq += @($matches[1] -split ',' | ForEach-Object { $_.Trim().ToUpperInvariant() } | Where-Object { $_ }) }
    # uretim pastali = en verimli asorti denemesinde yerlesmis pastal (URT1=AS03, ...)
    if ($l -match '^#\s*kopya\s*:\s*(.+)$') { foreach ($p in ($matches[1] -split ',')) { $kv = @($p -split '='); if ($kv.Count -eq 2 -and $kv[0].Trim() -and $kv[1].Trim()) { $kopya[$kv[0].Trim().ToUpperInvariant()] = $kv[1].Trim().ToUpperInvariant() } } }
  }
  # OTOPASTAL yoksa butun pastallar sadece Gerber'de olusur (yerlestirmeyi kullanici elle yapar)
  if ($OTO -eq 'yok') { $nq = @($orders) }
  $mods = @($mods | Sort-Object -Unique)
  $j = @{ base = $base; work = $work; dosya = $file.Name; area = $area; orders = @($orders); mods = $mods; temiz = $temiz; nq = @($nq); ek = @(); qo = @(); asama = 'basladi'
          res = @{ dosya = $file.Name; alan = $area; asama = 'basladi'; mesaj = ''; pastallar = @() } }
  $res = $j.res
  try {
    if (-not $area) { throw 'Dosyada musteri klasoru (# alan:) yok.' }
    if (-not (Test-Path (Join-Path $STOR $area))) { throw "Musteri klasoru bulunamadi: $area" }
    $varO = CtlNames $area 'order'; $varolan = @($orders | Where-Object { $varO -contains $_ })
    if ($varolan.Count -and -not $over) { throw ('Bu siparisler klasorde zaten var: ' + ($varolan -join ', ') + '. Uzerine yazmak icin programda kutuyu isaretle.') }
    $kaynak = @($kopya.Values)
    $pend = @(); if ($QUEUE -and ($temiz -or $kopya.Count)) { try { $pend = @(ReadQueue | Where-Object { -not $_.d['result'] } | ForEach-Object { ('' + $_.d['marker']).ToUpperInvariant() }) } catch {} }
    # 0) "En verimli asortiyi bul" denemelerinden kalan MODEL-ASnn siparis ve pastallarini sil (uretime kopyalanacaklar kopyadan sonra silinir)
    if ($temiz) {
      $sil = 0
      foreach ($kind in 'order', 'mark') {
        $cand = @(CtlNames $area $kind | Sort-Object -Unique | Where-Object { $n = $_; @($mods | Where-Object { $n -match ('^' + [regex]::Escape($_) + '-AS\d+$') }).Count -gt 0 -and $pend -notcontains $n -and $kaynak -notcontains $n })
        foreach ($n in $cand) {
          $o3 = Yerel { & .\amdelete.exe $(if ($kind -eq 'mark') { 'marker' } else { 'order' }) ($DRV + $area) $n }
          Log ("sil $kind $n : " + ($o3.Trim() -replace '\s+', ' ')); $sil++
        }
      }
      if ($sil) { Log "$base : $sil deneme kaydi (MODEL-ASnn) silindi" }
    }
    # 1) siparisleri ice al
    $res.asama = 'siparis'; Durum $base $res; Log "$base : $($orders.Count) siparis $area klasorune aliniyor"
    $ans = (@($(if ($over) { 'Y' } else { 'N' })) * 50) -join "`r`n"
    $out = Yerel { $ans | & .\csvimprt.exe $area $work }
    Log ($out.Trim() -replace '\s+', ' ')
    $varO = CtlNames $area 'order'; $eksik = @($orders | Where-Object { $varO -notcontains $_ })
    if ($eksik.Count) { throw ('Gerber su siparisleri almadi: ' + ($eksik -join ', ')) }
    # 1b) deneme pastallarini uretim adiyla kopyala (OTOPASTAL'da yeniden yerlestirmeye gerek yok)
    if ($kopya.Count) {
      $res.asama = 'kopya'; Durum $base $res
      $kop = @()
      foreach ($o in @($kopya.Keys)) { if ($orders -contains $o -and $nq -notcontains $o) { $r1 = KopyaYap $area $kopya[$o] $o $wOf[$o]; if ($r1) { $kop += $r1 } } }
      $j.ek = @($kop)
      if ($kop.Count) { Log "$base : $($kop.Count)/$($kopya.Count) pastal deneme pastallarindan kopyalandi" }
      # deneme kayitlari artik gerekmez (kopyalanamayanlar da her zamanki gibi silinir)
      foreach ($src in @($kaynak | Sort-Object -Unique)) {
        if ($pend -contains $src) { continue }
        foreach ($kind in 'order', 'mark') {
          if ((CtlNames $area $kind) -notcontains $src) { continue }
          $o3 = Yerel { & .\amdelete.exe $(if ($kind -eq 'mark') { 'marker' } else { 'order' }) ($DRV + $area) $src }
          Log ("sil $kind $src : " + ($o3.Trim() -replace '\s+', ' '))
        }
      }
    }
    $kopAd = @($j.ek | ForEach-Object { $_.ad })
    $bo = @($orders | Where-Object { $kopAd -notcontains $_ })
    if (-not $bo.Count) {
      $res.pastallar = @($j.ek); $res.asama = 'bitti'; Durum $base $res
      Log "$base : bitti (butun pastallar deneme pastallarindan kopyalandi, OTOPASTAL'a gonderilmedi)"; IsKapat $j; return
    }
    # 2) Batch ile pastal hazirla (sonucu ana dongu bekler)
    $res.asama = 'pastal'; $res.pastallar = @($j.ek); Durum $base $res
    if (-not (Get-Process -Name batch -ErrorAction SilentlyContinue)) { Start-Process -FilePath (Join-Path $AM 'batch.exe') -WorkingDirectory $AM -WindowStyle Minimized; Start-Sleep 5; Log 'Batch programi acildi'; $script:batchBizde = $true }
    $tbl = BatchTable $area; $skip = EngineCount
    if (-not $script:isler.Count) { $script:batchIs = @(); $script:batchSkip = $skip }
    $script:batchIs = @(@($script:batchIs) + $bo)
    # OTOPASTAL'a gidecekler AUTO; sadece Gerber'de olusacak ek pastallar MED (siparis islenir, pastal elle yerlestirilmek uzere bos olusur;
    # AUTO ile Batch "PASTAL BEKLIYOR"da kalir ve arkasindaki isleri bekletir)
    foreach ($o in $bo) { $yon = if ($nq -contains $o) { 'MED' } else { 'AUTO' }; $o4 = Yerel { & .\amsubmit.exe $tbl $o $o $yon 0 0 4 0 $o 0 }; if ($o4 -match '(?i)usage|error|hata') { Log ("amsubmit $o : " + ($o4.Trim() -replace '\s+', ' ')) } }
    $j.bo = $bo; $j.skip = $skip; $j.t0 = Get-Date; $j.t0b = Get-Date; $j.u0 = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 5; $j.asama = 'pastal'
    $script:isler[$base] = $j
  } catch { IsHata $j $_.Exception.Message }
}

# 'pastal' asamasi: Batch pastallari yazdi mi
function PastalAdim($j) {
  $base = $j.base; $res = $j.res; $area = $j.area; $bo = @($j.bo)
  if (Test-Path (Join-Path $K "iptal\$base")) {
    Remove-Item -Force (Join-Path $K "iptal\$base") -ErrorAction SilentlyContinue
    $res.asama = 'iptal'; $res.iptal = $true; $res.pastallar = @($j.ek); Durum $base $res; Log "$base : programdan durduruldu"; IsKapat $j; return
  }
  # bu isten once baslamis isler suruyorsa (Batch onlarla mesgul olabilir) bekleme suresi saymaya baslamaz
  $once = $false; foreach ($x in @($script:isler.Values)) { if ($x.base -eq $base) { break }; $once = $true }
  if ($once) { $j.t0b = Get-Date }
  $hazir = $false
  $st = @($bo | ForEach-Object { EngineStatus $j.skip $_ })
  if (-not ($st | Where-Object { $_ -ne 'ok' -and $_ -ne 'hata' })) { $hazir = $true }
  if (-not $hazir) {
    # Batch pastali yazinca kaydin zamani gonderimden sonrasini gosterir: hepsi yazildiktan 5 sn sonra devam et
    # (Batch pastala sonradan bir daha yazarsa zaman ilerler ve bekleme de kendiliginden uzar)
    $zm = CtlZaman $area 'mark'; $hep = -not @($bo | Where-Object { -not $zm.ContainsKey($_) -or $zm[$_] -lt $j.u0 }).Count
    if ($hep) { $enYeni = ($bo | ForEach-Object { $zm[$_] } | Measure-Object -Maximum).Maximum; if (([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $enYeni) -ge 5) { $hazir = $true } }
  }
  if (-not $hazir) {
    $varM = CtlNames $area 'mark'
    if (((Get-Date) - $j.t0b).TotalSeconds -gt 60 -and -not (@($bo | Where-Object { $varM -notcontains $_ }).Count)) { $hazir = $true }
  }
  if (-not $hazir) {
    if (((Get-Date) - $j.t0b).TotalMinutes -gt 10) { throw 'Batch 10 dakikada pastallari hazirlamadi. Batch Islemi penceresine bak.' }
    return
  }
  $varM = CtlNames $area 'mark'; $eksik = @($bo | Where-Object { $varM -notcontains $_ })
  if ($eksik.Count) { throw ('Pastal olusmadi: ' + ($eksik -join ', ')) }
  Log "$base : pastallar hazir"
  $hz = @($bo | Where-Object { $j.nq -contains $_ } | ForEach-Object { @{ ad = $_; tamam = $true; kaydedildi = $true; boy_cm = 0; verim = 0; adet = 0; sonuc = 'olusturuldu' } })
  $qo = @($bo | Where-Object { $j.nq -notcontains $_ })
  if ($hz.Count) { Log ("$base : OTOPASTAL'a gonderilmeyen (sadece Gerber'de) " + (($hz | ForEach-Object { $_.ad }) -join ', ')) }
  $j.ek = @(@($j.ek) + $hz)
  if (-not $qo.Count) { $res.pastallar = @($j.ek); $res.asama = 'bitti'; Durum $base $res; Log "$base : bitti (OTOPASTAL'a gonderilecek pastal yok)"; IsKapat $j; return }
  $res.pastallar = @($j.ek)
  # 3) OTOPASTAL kuyruguna yolla
  $res.asama = 'yerlesim'; Durum $base $res
  KuyrukProgramiCalistir
  $sub0 = (Get-Date).AddSeconds(-5).ToOADate()
  $out = & (Join-Path $K 'kuyruga_ekle.ps1') -Area $area -Markers $qo -Queue $QUEUE -Device $DEV 2>&1 | Out-String
  Log ($out.Trim() -replace '\s+', ' ')
  $req = @{}; foreach ($m in [regex]::Matches($out, 'EKLENDI: (\S+) \(is (\d+)')) { $req[$m.Groups[1].Value] = $m.Groups[2].Value }
  if ($req.Count -ne $qo.Count) { throw 'Kuyruga eklenemedi: ' + $out.Trim() }
  $res.gonderim = $sub0; Durum $base $res
  BekleHazirla $j $qo $sub0
}

function BekleHazirla($j, $qo, $sub0) {
  $j.qo = @($qo); $j.sub0 = $sub0; $j.bitti = @{}; $j.yok = @{}; $j.subO = @{}; $j.tekrar = @{}; $j.dv = @{}
  foreach ($o in $j.qo) { $j.subO[$o] = $sub0; $j.tekrar[$o] = 0; $j.dv[$o] = $script:DEV }
  $j.t0 = Get-Date; $j.tIlerleme = Get-Date; $j.lastLog = Get-Date; $j.imza = ''; $j.son = $false; $j.asama = 'yerlesim'
}

# OTOPASTAL kuyrugu ilerliyor mu (herhangi bir kaydin durumu degisti mi)
function KuyrukIlerleme($E) {
  $imza = '' + $E.Count + ':' + (($E | ForEach-Object { '' + $_.st + $_.d['result'] }) -join ',')
  if ($imza -ne $script:kuyrukImza) { $script:kuyrukImza = $imza; $script:kuyrukDegisim = Get-Date }
}

# 'yerlesim' asamasi: kuyruktaki sonuclara bir kez bak (her pastal bitince sonuc programa yazilir)
function BekleAdim($j, $E) {
  $base = $j.base; $res = $j.res; $orders = @($j.qo); $ek = @($j.ek)
  $bitti = $j.bitti; $yok = $j.yok; $subO = $j.subO; $tekrar = $j.tekrar; $dv = $j.dv
  # programdan "Durdur" basildiysa: bekleyen isleri kuyruktan sil, kalanlari iptal say
  $flag = Join-Path $K "iptal\$base"
  if (Test-Path $flag) {
    $rq = @($E | Where-Object { $orders -contains ('' + $_.d['marker']).ToUpperInvariant() -and $_.d['submittime'] -and [double]::Parse($_.d['submittime'], $inv) -ge $j.sub0 -and -not $_.d['result'] } | ForEach-Object { $_.d['RequestNum'] } | Sort-Object -Unique)
    if ($rq.Count) { $o2 = $(try { & (Join-Path $K 'kuyruktan_sil.ps1') -Requests ($rq -join ',') -Queue $QUEUE 2>&1 | Out-String } catch { 'kuyruktan silinemedi: ' + $_.Exception.Message }); Log ($o2.Trim()) }
    foreach ($o in $orders) { if (-not $bitti.ContainsKey($o)) { $bitti[$o] = @{ ad = $o; tamam = $false; boy_cm = 0; verim = 0; adet = 0; sonuc = 'iptal' } } }
    Remove-Item -Force $flag -ErrorAction SilentlyContinue; Log "$base : programdan durduruldu"; $res.iptal = $true; $j.son = $true; return
  }
  foreach ($o in $orders) {
    if ($bitti.ContainsKey($o)) { continue }
    # programda sadece bu pastal icin "x" basildiysa
    $pf = Join-Path $K "iptal\$($base)__$($o)"
    if (Test-Path $pf) {
      $rq = @($E | Where-Object { $_.d['marker'] -eq $o.ToLowerInvariant() -and $_.d['submittime'] -and [double]::Parse($_.d['submittime'], $inv) -ge $subO[$o] -and -not $_.d['result'] } | ForEach-Object { $_.d['RequestNum'] } | Sort-Object -Unique)
      if ($rq.Count) { $o2 = $(try { & (Join-Path $K 'kuyruktan_sil.ps1') -Requests ($rq -join ',') -Queue $QUEUE 2>&1 | Out-String } catch { 'kuyruktan silinemedi: ' + $_.Exception.Message }); Log ("$o : " + $o2.Trim()) }
      $bitti[$o] = @{ ad = $o; tamam = $false; boy_cm = 0; verim = 0; adet = 0; sonuc = 'iptal' }; Remove-Item -Force $pf -ErrorAction SilentlyContinue
      Log "$o : programdan durduruldu"; $res.pastallar = @(@($ek) + @($bitti.Values)); Durum $base $res; continue
    }
    # OTOPASTAL'da elle silindiyse (hic kaydi kalmadiysa ya da sadece bekleyen Save Best kaldiysa) iptal say
    $mineO = @($E | Where-Object { $_.d['marker'] -eq $o.ToLowerInvariant() -and $_.d['submittime'] -and [double]::Parse($_.d['submittime'], $inv) -ge $subO[$o] })
    $frO = @($mineO | Where-Object { $_.d['type'] -eq 'fraun' }); $cmO = @($mineO | Where-Object { $_.d['type'] -eq 'commit' })
    if (-not $mineO.Count -or (-not $frO.Count -and $cmO.Count -and -not ($cmO | Where-Object { $_.d['result'] }))) {
      # kuyruk dosyasi baska bir program tarafindan yeniden yazilirken kayitlar kisa sure gorunmeyebilir; 3 dakika boyunca hic yoksa silinmis say
      if (-not $yok.ContainsKey($o)) { $yok[$o] = Get-Date }
      if (((Get-Date) - $yok[$o]).TotalSeconds -ge 180) { $bitti[$o] = @{ ad = $o; tamam = $false; boy_cm = 0; verim = 0; adet = 0; sonuc = 'iptal' }; Log "$o : kuyrukta yok (silinmis), atlandi"; $res.pastallar = @(@($ek) + @($bitti.Values)); Durum $base $res }
      continue
    } else { $yok.Remove($o) }
    $c = $E | Where-Object { $_.d['marker'] -eq $o.ToLowerInvariant() -and $_.d['type'] -eq 'commit' -and $_.d['result'] -and $_.d['submittime'] -and [double]::Parse($_.d['submittime'], $inv) -ge $subO[$o] } | Select-Object -Last 1
    $kay = $true
    if (-not $c) {
      # "Save Best" satiri yoksa (silinmis olabilir) yerlestirme satirinin sonucunu kullan
      $fr = $E | Where-Object { $_.d['marker'] -eq $o.ToLowerInvariant() -and $_.d['type'] -eq 'fraun' -and $_.d['result'] -and $_.d['submittime'] -and [double]::Parse($_.d['submittime'], $inv) -ge $subO[$o] } | Select-Object -Last 1
      if ($fr) {
        $rq = $fr.d['RequestNum']; $hasC = @($E | Where-Object { $_.d['type'] -eq 'commit' -and $_.d['RequestNum'] -eq $rq }).Count -gt 0
        if ($fr.d['result'] -eq '0') { $c = $fr; $kay = $false }
        elseif (-not $hasC) { $c = $fr; $kay = $false }
      }
    }
    if ($c) {
      $d = $c.d; $ok = ($d['result'] -eq 'committed') -or ($d['type'] -eq 'fraun' -and $d['result'] -eq '1')
      # yerlesmediyse (OTOPASTAL pastali acamadiysa) bir kere daha gonder
      # hic parca yuklenemediyse (adet 0) OTOPASTAL pastala bu harfle ulasamamistir: diger harfle tekrar gonder
      $frD = $E | Where-Object { $_.d['marker'] -eq $o.ToLowerInvariant() -and $_.d['type'] -eq 'fraun' -and $_.d['result'] -and $_.d['submittime'] -and [double]::Parse($_.d['submittime'], $inv) -ge $subO[$o] } | Select-Object -Last 1
      $bos = (-not $ok) -and $frD -and ('' + $frD.d['bundle_count']) -in @('', '0')
      if (-not $ok -and $tekrar[$o] -lt 1) {
        $eskiD = $dv[$o]; $yeniD = if ($bos) { DigerSurucu $eskiD } else { $eskiD }
        # bu harf calismiyorsa: ayni harfle siraya konmus, henuz baslamamis diger pastallari da kuyruktan alip yeni harfle gonder
        $tasi = @($o)
        if ($bos -and $yeniD -ne $eskiD) {
          foreach ($o2 in $orders) {
            if ($o2 -eq $o -or $bitti.ContainsKey($o2) -or $dv[$o2] -ne $eskiD -or $tekrar[$o2] -ge 1) { continue }
            $e2 = @($E | Where-Object { $_.d['marker'] -eq $o2.ToLowerInvariant() -and $_.d['submittime'] -and [double]::Parse($_.d['submittime'], $inv) -ge $subO[$o2] })
            if ($e2.Count -and -not @($e2 | Where-Object { $_.st -ne 1 }).Count) {
              $rq2 = @($e2 | ForEach-Object { $_.d['RequestNum'] } | Sort-Object -Unique)
              $o6 = $(try { & (Join-Path $K 'kuyruktan_sil.ps1') -Requests ($rq2 -join ',') -Queue $QUEUE 2>&1 | Out-String } catch { 'silinemedi: ' + $_.Exception.Message })
              if ($o6 -match 'kuyruktan silindi') { $tasi += $o2 }
            }
          }
        }
        Start-Sleep 3; $yeniT = (Get-Date).AddSeconds(-5).ToOADate()
        foreach ($o3 in $tasi) { $tekrar[$o3]++; $dv[$o3] = $yeniD; $subO[$o3] = $yeniT; $yok.Remove($o3) }
        $o5 = $(try { & (Join-Path $K 'kuyruga_ekle.ps1') -Area $res.alan -Markers $tasi -Queue $QUEUE -Device $yeniD 2>&1 | Out-String } catch { 'gonderilemedi: ' + $_.Exception.Message })
        Log ("$o : yerlesmedi ($($d['result'])$(if ($bos) { ', parca yuklenemedi' })); $yeniD ile tekrar gonderildi: " + ($tasi -join ', ') + ' | ' + ($o5.Trim() -replace '\s+', ' ')); continue
      }
      if ($ok) { SurucuTercih $dv[$o] }
      $cm = if ($d['length']) { [double]::Parse($d['length'], $inv) / 10000 * 2.54 } else { 0 }
      $ef = if ($d['efficiency']) { [double]::Parse($d['efficiency'], $inv) / 10000 } else { 0 }
      $bitti[$o] = @{ ad = $o; tamam = $ok; kaydedildi = ($ok -and $kay); boy_cm = [math]::Round($cm, 2); verim = [math]::Round($ef, 2); adet = [int]('0' + $d['bundle_count']); sonuc = $(if ($d['result'] -eq '0') { 'yerlesmedi' } else { $d['result'] }) }
      Log "$o : $($d['result']) boy $([math]::Round($cm,2)) cm verim %$([math]::Round($ef,2))"
      $res.pastallar = @(@($ek) + @($bitti.Values)); Durum $base $res
    }
  }
  # bu isin kayitlari ilerliyor mu
  $mine = @($E | Where-Object { $orders -contains ('' + $_.d['marker']).ToUpperInvariant() })
  $imza = (($mine | ForEach-Object { '' + $_.job + '/' + $_.st + '/' + $_.d['result'] }) -join ' ') + '|' + $bitti.Count
  if ($imza -ne $j.imza) { $j.imza = $imza; $j.tIlerleme = Get-Date }
  if (((Get-Date) - $j.lastLog).TotalSeconds -gt 60) {
    $j.lastLog = Get-Date
    Log ("{3} bekleniyor: kuyrukta {0} kayit, bu ise ait {1}: {2}" -f $E.Count, $mine.Count, (($mine | ForEach-Object { '' + $_.job + '/' + $_.st + '/' + $_.d['type'] + '/' + $_.d['result'] }) -join ' '), $base)
    try { Copy-Item -Force $QUEUE (Join-Path $K 'log\kuyruk_son.umq') } catch {}
  }
  if ($bitti.Count -ge $orders.Count) { $j.son = $true; return }
  # OTOPASTAL 20 dakika boyunca ne bu iste ne kuyrugun geri kalaninda ilerlediyse (kapali / takili) dur
  $dur = [math]::Min(((Get-Date) - $j.tIlerleme).TotalMinutes, ((Get-Date) - $script:kuyrukDegisim).TotalMinutes)
  if ($dur -gt 20 -or ((Get-Date) - $j.t0).TotalHours -gt 8) { throw 'OTOPASTAL zamaninda bitirmedi. OTOPASTAL''daki QueueSubmit listesine bak.' }
}

function IsBitir($j) {
  $res = $j.res; $orders = @($j.qo); $bitti = $j.bitti
  $sonuclar = @($orders | ForEach-Object { $bitti[$_] })
  $res.pastallar = @(@($j.ek) + $sonuclar)
  $kopyaS = @($j.ek | Where-Object { $_.sonuc -eq 'kopyalandi' }).Count
  $tamamS = @($sonuclar | Where-Object { $_.tamam }).Count + $kopyaS; $iptalS = @($sonuclar | Where-Object { $_.sonuc -eq 'iptal' }).Count
  if ($tamamS) { $res.asama = 'bitti' }
  elseif ($iptalS -eq $sonuclar.Count) { $res.asama = 'iptal' }
  else {
    $res.asama = 'hata'
    $harfler = (($DEVS | ForEach-Object { $_.ToUpperInvariant() }) -join ' ve ')
    $res.mesaj = $(if (@($sonuclar | Where-Object { $_.adet -eq 0 -and $_.sonuc -ne 'iptal' }).Count) { "OTOPASTAL pastallari acamadi (hic parca yuklenemedi). OTOPASTAL bu bilgisayarin pastallarina ulasamiyor olabilir: OTOPASTAL'da Bilgisayarim'dan $harfler suruculerini acip kontrol et." } else { 'OTOPASTAL pastallari yerlestiremedi.' })
  }
  Durum $j.base $res; Log "$($j.base) : bitti"
  IsKapat $j
}

# butun suren isleri bir adim ilerlet
function IslerAdim {
  if (-not $script:isler.Count) { return }
  $E = $null
  if (@($script:isler.Values | Where-Object { $_.asama -eq 'yerlesim' }).Count -and ((Get-Date) - $script:kuyrukOkuma).TotalSeconds -ge 4.5) {
    $script:kuyrukOkuma = Get-Date
    try { $E = ReadQueue; KuyrukIlerleme $E }
    catch { if (((Get-Date) - $script:kuyrukHataLog).TotalSeconds -gt 60) { Log ('kuyruk okunamadi: ' + $_.Exception.Message); $script:kuyrukHataLog = Get-Date } }
  }
  foreach ($j in @($script:isler.Values)) {
    try {
      if ($j.asama -eq 'yerlesim') { if ($null -ne $E) { BekleAdim $j $E | Out-Null; if ($j.son) { IsBitir $j } } }
      elseif ($j.asama -eq 'pastal') { PastalAdim $j | Out-Null }
    } catch { IsHata $j $_.Exception.Message }
  }
}

# OTOPASTAL bu bilgisayardaysa ve kuyruk programi kapaliysa acar (yoksa isler kuyrukta bekler)
function KuyrukProgramiCalistir {
  if ($OTO -ne 'ayni' -or -not $script:bulVar) { return }
  try {
    $p = KuyrukProgramiBul
    if ($p.calisiyor) { return }
    if (-not $p.exe) { Log 'UYARI: bu bilgisayardaki OTOPASTAL (AccuNest kuyruk) programi bulunamadi; acik degilse pastallar kuyrukta bekler'; return }
    Start-Process -FilePath $p.exe -WorkingDirectory (Split-Path -Parent $p.exe) -WindowStyle Minimized
    Log "OTOPASTAL programi acildi: $($p.exe)"; Start-Sleep 5
  } catch { Log ('OTOPASTAL programi acilamadi: ' + $_.Exception.Message) }
}

# isi bitince bu ise ait durdurma isaretlerini temizle
function IptalTemizle($base) { Get-ChildItem -Path (Join-Path $K 'iptal') -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $base -or $_.Name.StartsWith($base + '__') } | Remove-Item -Force -ErrorAction SilentlyContinue }

# Batch'i is bitince kapat (sadece kopru actiysa; kullanici kendisi actiysa dokunma).
# Batch'teki pastallar "TAMAMLANDI" olana kadar en fazla 15 sn bekler (Batch durumu dosyaya gec yazar).
$script:batchBizde = $false; $script:batchIs = @(); $script:batchSkip = 0; $script:isBitti = [datetime]::MinValue
function BatchKapatGerekirse {
  if (-not $script:batchBizde) { return }
  if (@(Get-ChildItem -Path (Join-Path $K 'gelen') -Filter *.txt -ErrorAction SilentlyContinue).Count) { return }
  if (@(Get-ChildItem -Path (Join-Path $K 'isleniyor') -Filter *.txt -ErrorAction SilentlyContinue).Count) { return }
  $bek = @($script:batchIs | Where-Object { (EngineStatus $script:batchSkip $_) -notin @('ok', 'hata', '') })
  if ($bek.Count -and ((Get-Date) - $script:isBitti).TotalSeconds -lt 15) { return }
  $b = @(Get-Process -Name batch -ErrorAction SilentlyContinue)
  if ($b.Count) {
    foreach ($p in $b) { try { [void]$p.CloseMainWindow() } catch {} }
    for ($i = 0; $i -lt 10 -and @(Get-Process -Name batch -ErrorAction SilentlyContinue).Count; $i++) { Start-Sleep 1 }
    foreach ($p in @(Get-Process -Name batch -ErrorAction SilentlyContinue)) { try { Stop-Process -Id $p.Id -Force } catch {} }
    Log 'Batch kapatildi (is bitti)'
  }
  $script:batchBizde = $false
}

Log ('Gerber koprusu calisiyor (' + $KOK + ')' + " OTOPASTAL: $OTO")
if (-not $script:bulVar) { Log ('UYARI: bul.ps1 yuklenemedi: ' + $script:bulHata) }
# AccuMark baska yere kurulduysa (surum yukseltme vb.) kendisi bulur ve ayarlara yazar
if ($script:bulVar -and -not (AccuMarkGecerli $AM)) {
  $bAm = AccuMarkBul
  if ($bAm.yol) { Log "AccuMark $AM klasorunde yok; $($bAm.yol) bulundu, o kullaniliyor"; $AM = $bAm.yol; try { AyarYaz $KOK @{ accumark = $AM } } catch {} }
  else { Log "UYARI: AccuMark programlari bulunamadi ($AM)" }
}
# eski kayitlari temizle: gunlukler 30 gun, bitmis isler 14 gun
try {
  Get-ChildItem (Join-Path $K 'log') -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force -ErrorAction SilentlyContinue
  Get-ChildItem (Join-Path $K 'iptal') -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } | Remove-Item -Force -ErrorAction SilentlyContinue
  foreach ($d in 'bitti','sonuc','iptal') { Get-ChildItem (Join-Path $K $d) -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-14) } | Remove-Item -Force -ErrorAction SilentlyContinue }
} catch {}
if ($QUEUE) {
  try {
    Copy-Item -Force $QUEUE (Join-Path $K 'log\kuyruk_son.umq'); $E = ReadQueue; Log ("kuyruk okundu: {0} kayit" -f $E.Count)
    # OTOPASTAL bu bilgisayarin pastallarina gecmiste hangi harflerle ulasti: yedek harf olarak eklenir
    $alS = New-Object 'System.Collections.Generic.HashSet[string]'; foreach ($d in (Get-ChildItem -Path $STOR -Directory -ErrorAction SilentlyContinue)) { [void]$alS.Add($d.Name.ToUpperInvariant()) }
    $ogr = @(); if ($script:bulVar) { $ogr = @(CihazOgren $E $alS) }
    $yeniH = @($ogr | Where-Object { $DEVS -notcontains $_ })
    if ($yeniH.Count) { $script:DEVS = @($DEVS + $yeniH); Log ('gecmis islerden ogrenilen harf: ' + ($yeniH -join ', ')) }
  } catch { Log ('kuyruk okunamadi: ' + $_.Exception.Message) }
} else { Log 'OTOPASTAL (kuyruk) ayarlanmamis: pastallar sadece Gerber''de olusturulur' }
# yarim kalan isleri surdur (kopru yeniden baslatildiysa): OTOPASTAL'da bekleyenler kaldigi yerden izlenir
Get-ChildItem -Path (Join-Path $K 'isleniyor') -Filter *.txt -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | ForEach-Object {
  $f = $_; $base = [IO.Path]::GetFileNameWithoutExtension($f.Name); $js = Join-Path $K "sonuc\$base.json"; $devam = $false
  try {
    $res = @{}; (Get-Content $js -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $res[$_.Name] = $_.Value }
    if ($res.asama -eq 'yerlesim') {
      $z = IsOzeti $f.FullName; $nq = @(); Get-Content $f.FullName -Encoding Default | ForEach-Object { if ($_ -match '^#\s*kuyruksuz\s*:\s*(.+)$') { $nq += @($matches[1] -split ',' | ForEach-Object { $_.Trim().ToUpperInvariant() } | Where-Object { $_ }) } }
      if ($OTO -eq 'yok') { $nq = @($z.orders) }
      # sadece Gerber'de olusanlar ve deneme pastalindan kopyalananlar zaten bitmisti
      $ek = @(@($res.pastallar) | Where-Object { $_ -and ($_.sonuc -eq 'kopyalandi' -or $_.sonuc -eq 'olusturuldu') } | ForEach-Object { $h = @{}; $_.PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value }; $h })
      $ekAd = @($ek | ForEach-Object { ('' + $_.ad).ToUpperInvariant() })
      foreach ($o in $nq) { if ($ekAd -notcontains $o -and $z.orders -contains $o) { $ek += @{ ad = $o; tamam = $true; kaydedildi = $true; boy_cm = 0; verim = 0; adet = 0; sonuc = 'olusturuldu' }; $ekAd += $o } }
      $qo = @($z.orders | Where-Object { $ekAd -notcontains $_ })
      $sub0 = if ($res.gonderim) { [double]$res.gonderim } else { ([datetime]$res.zaman).AddMinutes(-5).ToOADate() }
      $j = @{ base = $base; work = $f.FullName; dosya = $f.Name; area = ('' + $res.alan).ToUpperInvariant(); orders = @($z.orders); mods = $z.mods; temiz = $z.temiz; nq = @($nq); ek = @($ek); res = $res }
      BekleHazirla $j $qo $sub0
      $script:isler[$base] = $j; $devam = $true
      Log "$base : yarim kalan is surduruluyor"
    } elseif ($res.asama -notin @('bitti', 'hata', 'iptal')) {
      $res.asama = 'hata'; $res.mesaj = 'Program bu is bitmeden kapatildi. Tekrar gonder (gerekirse "var olanin uzerine yaz" ile).'; Durum $base $res; Log "$base : yarim kalmisti, hata olarak isaretlendi"
    }
  } catch { Log ("$base surdurulemedi: " + $_.Exception.Message) }
  if (-not $devam) { Move-Item -Force $f.FullName (Join-Path $K "bitti\$($f.Name)"); IptalTemizle $base }
}

$alanT = [datetime]::MinValue
while ($true) {
  if (((Get-Date) - $alanT).TotalMinutes -ge 2) { try { Alanlar } catch { Log ('klasor listesi yazilamadi: ' + $_.Exception.Message) }; $alanT = Get-Date }
  try { SiradakileriYaz } catch {}
  # yeni isler: suren bir isle cakismiyorsa hemen baslar (cakisiyorsa "sirada" bekler)
  try {
    foreach ($f in @(Get-ChildItem -Path (Join-Path $K 'gelen') -Filter *.txt -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)) {
      if (Cakisiyor $f) { continue }
      Start-Sleep 1; if (Test-Path $f.FullName) { IsBasla $f }
    }
  } catch { Log ('HATA: ' + $_.Exception.Message) }
  try { IslerAdim } catch { Log ('HATA: ' + $_.Exception.Message) }
  try { BatchKapatGerekirse } catch { Log ('Batch kapatilamadi: ' + $_.Exception.Message) }
  Start-Sleep 3
}
