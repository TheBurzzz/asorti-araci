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
$AM     = $A.accumark
$UR     = $A.userroot
$STOR   = Join-Path $UR 'storage'
$ENGQ   = Join-Path $UR 'engine.que'
$BPRM   = Join-Path $UR 'bprmtbl'
$DRV    = Split-Path -Qualifier $UR                             # depolama alanlarinin surucusu (C:)
$QUEUE  = $A.kuyruk
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

function Bekle($base, $res, $orders, $sub0, $ek = @()) {
    $t0 = Get-Date; $bitti = @{}; $yok = @{}; $lastLog = Get-Date; $inv = [Globalization.CultureInfo]::InvariantCulture
    $subO = @{}; $tekrar = @{}; $dv = @{}; foreach ($o in $orders) { $subO[$o] = $sub0; $tekrar[$o] = 0; $dv[$o] = $script:DEV }
    while ($bitti.Count -lt $orders.Count) {
      Start-Sleep 5
      Get-ChildItem -Path (Join-Path $K 'gelen') -Filter *.txt -ErrorAction SilentlyContinue | ForEach-Object { $qb = [IO.Path]::GetFileNameWithoutExtension($_.Name); if (-not (Test-Path (Join-Path $K "sonuc\$qb.json"))) { Durum $qb @{ dosya = $_.Name; asama = 'sirada'; mesaj = ''; pastallar = @() } } }
      try { $E = ReadQueue } catch { if (((Get-Date) - $lastLog).TotalSeconds -gt 60) { Log ('kuyruk okunamadi: ' + $_.Exception.Message); $lastLog = Get-Date }; continue }
      # programdan "Durdur" basildiysa: bekleyen isleri kuyruktan sil, kalanlari iptal say
      $flag = Join-Path $K "iptal\$base"
      if (Test-Path $flag) {
        $rq = @($E | Where-Object { $orders -contains ('' + $_.d['marker']).ToUpperInvariant() -and $_.d['submittime'] -and [double]::Parse($_.d['submittime'], $inv) -ge $sub0 -and -not $_.d['result'] } | ForEach-Object { $_.d['RequestNum'] } | Sort-Object -Unique)
        if ($rq.Count) { $o2 = $(try { & (Join-Path $K 'kuyruktan_sil.ps1') -Requests ($rq -join ',') -Queue $QUEUE 2>&1 | Out-String } catch { 'kuyruktan silinemedi: ' + $_.Exception.Message }); Log ($o2.Trim()) }
        foreach ($o in $orders) { if (-not $bitti.ContainsKey($o)) { $bitti[$o] = @{ ad = $o; tamam = $false; boy_cm = 0; verim = 0; adet = 0; sonuc = 'iptal' } } }
        Remove-Item -Force $flag -ErrorAction SilentlyContinue; Log "$base : programdan durduruldu"; $res.iptal = $true; break
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
      if (((Get-Date) - $lastLog).TotalSeconds -gt 60) {
        $lastLog = Get-Date
        $mine = @($E | Where-Object { $orders -contains ('' + $_.d['marker']).ToUpperInvariant() })
        Log ("bekleniyor: kuyrukta {0} kayit, bu ise ait {1}: {2}" -f $E.Count, $mine.Count, (($mine | ForEach-Object { '' + $_.job + '/' + $_.st + '/' + $_.d['type'] + '/' + $_.d['result'] }) -join ' '))
        try { Copy-Item -Force $QUEUE (Join-Path $K 'log\kuyruk_son.umq') } catch {}
      }
      if (((Get-Date) - $t0).TotalMinutes -gt (15 + 3 * $orders.Count)) { throw 'OTOPASTAL zamaninda bitirmedi. OTOPASTAL''daki QueueSubmit listesine bak.' }
    }
  $sonuclar = @($orders | ForEach-Object { $bitti[$_] })
  $res.pastallar = @(@($ek) + $sonuclar)
  $tamamS = @($sonuclar | Where-Object { $_.tamam }).Count; $iptalS = @($sonuclar | Where-Object { $_.sonuc -eq 'iptal' }).Count
  if ($tamamS) { $res.asama = 'bitti' }
  elseif ($iptalS -eq $sonuclar.Count) { $res.asama = 'iptal' }
  else {
    $res.asama = 'hata'
    $res.mesaj = $(if (@($sonuclar | Where-Object { $_.adet -eq 0 -and $_.sonuc -ne 'iptal' }).Count) { "OTOPASTAL pastallari acamadi (hic parca yuklenemedi). OTOPASTAL bu bilgisayarin C: diskine ulasamiyor olabilir: OTOPASTAL'da Bilgisayarim'dan K: ve Z: suruculerini acip kontrol et." } else { 'OTOPASTAL pastallari yerlestiremedi.' })
  }
  Durum $base $res
}

function Isle($file) {
  $base = [IO.Path]::GetFileNameWithoutExtension($file.Name)
  $work = Join-Path $K "isleniyor\$($file.Name)"; Move-Item -Force $file.FullName $work
  $lines = Get-Content -Path $work -Encoding Default
  $area = ''; $over = $false; $orders = @(); $mods = @(); $temiz = $false; $nq = @()
  foreach ($l in $lines) {
    if ($l -match '^#\s*alan\s*:\s*(\S+)') { $area = $matches[1].ToUpperInvariant() }
    if ($l -match '^#\s*uzerine-yaz\s*:\s*evet') { $over = $true }
    if ($l -match '^o:(.+)$') { $orders += $matches[1].Trim().ToUpperInvariant() }
    if ($l -match '^m:(.+)$') { $mods += $matches[1].Trim().ToUpperInvariant() }
    if ($l -match '^#\s*temizle-deneme\s*:\s*evet') { $temiz = $true }
    # Gerber'de olusturulacak ama OTOPASTAL'a gonderilmeyecek pastallar (ek asorti tablolari)
    if ($l -match '^#\s*kuyruksuz\s*:\s*(.+)$') { $nq += @($matches[1] -split ',' | ForEach-Object { $_.Trim().ToUpperInvariant() } | Where-Object { $_ }) }
  }
  $res = @{ dosya = $file.Name; alan = $area; asama = 'basladi'; mesaj = ''; pastallar = @() }
  try {
    if (-not $area) { throw 'Dosyada musteri klasoru (# alan:) yok.' }
    if (-not (Test-Path (Join-Path $STOR $area))) { throw "Musteri klasoru bulunamadi: $area" }
    $varO = CtlNames $area 'order'; $varolan = @($orders | Where-Object { $varO -contains $_ })
    if ($varolan.Count -and -not $over) { throw ('Bu siparisler klasorde zaten var: ' + ($varolan -join ', ') + '. Uzerine yazmak icin programda kutuyu isaretle.') }
    # 0) "En verimli asortiyi bul" denemelerinden kalan MODEL-ASnn siparis ve pastallarini sil
    if ($temiz) {
      $pend = @(); try { $pend = @(ReadQueue | Where-Object { -not $_.d['result'] } | ForEach-Object { ('' + $_.d['marker']).ToUpperInvariant() }) } catch {}
      $mods = @($mods | Sort-Object -Unique); $sil = 0
      foreach ($kind in 'order', 'mark') {
        $cand = @(CtlNames $area $kind | Sort-Object -Unique | Where-Object { $n = $_; @($mods | Where-Object { $n -match ('^' + [regex]::Escape($_) + '-AS\d+$') }).Count -gt 0 -and $pend -notcontains $n })
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
    # 2) Batch ile pastal hazirla
    $res.asama = 'pastal'; Durum $base $res
    if (-not (Get-Process -Name batch -ErrorAction SilentlyContinue)) { Start-Process -FilePath (Join-Path $AM 'batch.exe') -WorkingDirectory $AM -WindowStyle Minimized; Start-Sleep 5; Log 'Batch programi acildi'; $script:batchBizde = $true }
    $tbl = BatchTable $area; $skip = EngineCount
    $script:batchIs = @($orders); $script:batchSkip = $skip
    # OTOPASTAL'a gidecekler AUTO; sadece Gerber'de olusacak ek pastallar MED (siparis islenir, pastal elle yerlestirilmek uzere bos olusur;
    # AUTO ile Batch "PASTAL BEKLIYOR"da kalir ve arkasindaki isleri bekletir)
    foreach ($o in $orders) { $yon = if ($nq -contains $o) { 'MED' } else { 'AUTO' }; $o4 = Yerel { & .\amsubmit.exe $tbl $o $o $yon 0 0 4 0 $o 0 }; if ($o4 -match '(?i)usage|error|hata') { Log ("amsubmit $o : " + ($o4.Trim() -replace '\s+', ' ')) } }
    $t0 = Get-Date; $u0 = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 5
    while ($true) {
      $st = @($orders | ForEach-Object { EngineStatus $skip $_ })
      if (-not ($st | Where-Object { $_ -ne 'ok' -and $_ -ne 'hata' })) { break }
      # Batch pastali yazinca kaydin zamani bu gonderimden sonrasini gosterir: hepsi yazildiktan 5 sn sonra devam et
      # (Batch pastala sonradan bir daha yazarsa zaman ilerler ve bekleme de kendiliginden uzar)
      $zm = CtlZaman $area 'mark'; $hep = -not @($orders | Where-Object { -not $zm.ContainsKey($_) -or $zm[$_] -lt $u0 }).Count
      if ($hep) { $enYeni = ($orders | ForEach-Object { $zm[$_] } | Measure-Object -Maximum).Maximum; if (([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $enYeni) -ge 5) { break } }
      $varM = CtlNames $area 'mark'
      if (((Get-Date) - $t0).TotalSeconds -gt 60 -and -not (@($orders | Where-Object { $varM -notcontains $_ }).Count)) { break }
      if (((Get-Date) - $t0).TotalMinutes -gt 10) { throw 'Batch 10 dakikada pastallari hazirlamadi. Batch Islemi penceresine bak.' }
      Start-Sleep 3
    }
    $varM = CtlNames $area 'mark'; $eksik = @($orders | Where-Object { $varM -notcontains $_ })
    if ($eksik.Count) { throw ('Pastal olusmadi: ' + ($eksik -join ', ')) }
    Log "$base : pastallar hazir"
    $hazir = @($orders | Where-Object { $nq -contains $_ } | ForEach-Object { @{ ad = $_; tamam = $true; kaydedildi = $true; boy_cm = 0; verim = 0; adet = 0; sonuc = 'olusturuldu' } })
    $qo = @($orders | Where-Object { $nq -notcontains $_ })
    if ($hazir.Count) { Log ("$base : OTOPASTAL'a gonderilmeyen (sadece Gerber'de) " + (($hazir | ForEach-Object { $_.ad }) -join ', ')) }
    if (-not $qo.Count) {
      $res.pastallar = $hazir; $res.asama = 'bitti'; Durum $base $res; Log "$base : bitti (OTOPASTAL'a gonderilecek pastal yok)"
      Move-Item -Force $work (Join-Path $K "bitti\$($file.Name)"); $script:isBitti = Get-Date; IptalTemizle $base; return
    }
    $res.pastallar = $hazir
    # 3) OTOPASTAL kuyruguna yolla
    $res.asama = 'yerlesim'; Durum $base $res
    $sub0 = (Get-Date).AddSeconds(-5).ToOADate()
    $out = & (Join-Path $K 'kuyruga_ekle.ps1') -Area $area -Markers $qo -Queue $QUEUE -Device $DEV 2>&1 | Out-String
    Log ($out.Trim() -replace '\s+', ' ')
    $req = @{}; foreach ($m in [regex]::Matches($out, 'EKLENDI: (\S+) \(is (\d+)')) { $req[$m.Groups[1].Value] = $m.Groups[2].Value }
    if ($req.Count -ne $qo.Count) { throw 'Kuyruga eklenemedi: ' + $out.Trim() }
    $res.gonderim = $sub0; Durum $base $res
    Bekle $base $res $qo $sub0 $hazir
    Log "$base : bitti"
  } catch {
    $res.asama = 'hata'; $res.mesaj = $_.Exception.Message; Durum $base $res; Log "$base : HATA $($res.mesaj)"
  }
  Move-Item -Force $work (Join-Path $K "bitti\$($file.Name)"); $script:isBitti = Get-Date; IptalTemizle $base
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

Log ('Gerber koprusu calisiyor (' + $KOK + ')')
# eski kayitlari temizle: gunlukler 30 gun, bitmis isler 14 gun
try {
  Get-ChildItem (Join-Path $K 'log') -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force -ErrorAction SilentlyContinue
  Get-ChildItem (Join-Path $K 'iptal') -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } | Remove-Item -Force -ErrorAction SilentlyContinue
  foreach ($d in 'bitti','sonuc','iptal') { Get-ChildItem (Join-Path $K $d) -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-14) } | Remove-Item -Force -ErrorAction SilentlyContinue }
} catch {}
try { Copy-Item -Force $QUEUE (Join-Path $K 'log\kuyruk_son.umq'); $E = ReadQueue; Log ("kuyruk okundu: {0} kayit" -f $E.Count) } catch { Log ('kuyruk okunamadi: ' + $_.Exception.Message) }
# yarim kalan isleri surdur (kopru yeniden baslatildiysa)
Get-ChildItem -Path (Join-Path $K 'isleniyor') -Filter *.txt -ErrorAction SilentlyContinue | ForEach-Object {
  $f = $_; $base = [IO.Path]::GetFileNameWithoutExtension($f.Name); $js = Join-Path $K "sonuc\$base.json"
  try {
    $res = @{}; (Get-Content $js -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $res[$_.Name] = $_.Value }
    if ($res.asama -eq 'yerlesim') {
      $orders = @(); $nq = @(); Get-Content $f.FullName -Encoding Default | ForEach-Object { if ($_ -match '^o:(.+)$') { $orders += $matches[1].Trim().ToUpperInvariant() }; if ($_ -match '^#\s*kuyruksuz\s*:\s*(.+)$') { $nq += @($matches[1] -split ',' | ForEach-Object { $_.Trim().ToUpperInvariant() } | Where-Object { $_ }) } }
      $hazir = @($orders | Where-Object { $nq -contains $_ } | ForEach-Object { @{ ad = $_; tamam = $true; kaydedildi = $true; boy_cm = 0; verim = 0; adet = 0; sonuc = 'olusturuldu' } }); $orders = @($orders | Where-Object { $nq -notcontains $_ })
      $sub0 = if ($res.gonderim) { [double]$res.gonderim } else { ([datetime]$res.zaman).AddMinutes(-5).ToOADate() }
      Log "$base : yarim kalan is surduruluyor"
      try { Bekle $base $res $orders $sub0 $hazir; Log "$base : bitti" } catch { $res.asama = 'hata'; $res.mesaj = $_.Exception.Message; Durum $base $res; Log "$base : HATA $($res.mesaj)" }
    } elseif ($res.asama -notin @('bitti', 'hata', 'iptal')) {
      $res.asama = 'hata'; $res.mesaj = 'Program bu is bitmeden kapatildi. Tekrar gonder (gerekirse "var olanin uzerine yaz" ile).'; Durum $base $res; Log "$base : yarim kalmisti, hata olarak isaretlendi"
    }
  } catch { Log ("$base surdurulemedi: " + $_.Exception.Message) }
  Move-Item -Force $f.FullName (Join-Path $K "bitti\$($f.Name)"); IptalTemizle $base
}

$alanT = [datetime]::MinValue
while ($true) {
  if (((Get-Date) - $alanT).TotalMinutes -ge 2) { try { Alanlar } catch { Log ('klasor listesi yazilamadi: ' + $_.Exception.Message) }; $alanT = Get-Date }
  try {
    Get-ChildItem -Path (Join-Path $K 'gelen') -Filter *.txt | Sort-Object LastWriteTime | ForEach-Object { Start-Sleep 1; Isle $_ }
  } catch { Log ('HATA: ' + $_.Exception.Message) }
  try { BatchKapatGerekirse } catch { Log ('Batch kapatilamadi: ' + $_.Exception.Message) }
  Start-Sleep 3
}
