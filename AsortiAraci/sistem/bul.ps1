# Asorti Araci - bu bilgisayarda Gerber AccuMark, müşteri klasörleri ve OTOPASTAL (AccuNest kuyruğu) nerede, kendisi bulur.
# Kurulum sihirbazı, ayarlar menüsündeki "Otomatik bul" ve köprü aynı fonksiyonları kullanır.
# Hiçbir şeyi değiştirmez: sadece bakar (kayıt defteri, klasörler, ağdaki bilgisayarların paylaşımları) ve rapor döndürür.

$script:BulEnc = [Text.Encoding]::GetEncoding(28591)
$script:BulNotlar = $null
function BulNot([string]$s) { if ($null -ne $script:BulNotlar) { [void]$script:BulNotlar.Add($s) } }
function BulPc { ("" + $env:COMPUTERNAME).ToUpperInvariant() }
# iki parçayı birleştirir (Join-Path olmayan sürücülerde hata yazar; bu yazmaz)
function Yol([string]$a, [string]$b) { $t = [char]92; return $a.TrimEnd($t) + $t + $b.TrimStart($t) }

# ---------- sürücüler ----------
# her sürücü: harf, tip (2 çıkarılabilir, 3 yerel disk, 4 ağ), ağ yolu (\\bilgisayar\paylaşım), kopuk (bağlantısı düşmüş ağ sürücüsü)
function SurucuListesi {
  if ($script:BulSurucuOnbellek) { return $script:BulSurucuOnbellek }
  $r = New-Object System.Collections.ArrayList
  try {
    foreach ($d in @(Get-CimInstance Win32_LogicalDisk -ErrorAction Stop)) {
      if (-not $d.DeviceID) { continue }
      [void]$r.Add([pscustomobject]@{ harf = $d.DeviceID.Substring(0, 1).ToUpperInvariant(); tip = [int]$d.DriveType; ag = "$($d.ProviderName)"; kopuk = $false })
    }
  } catch {}
  # bağlantısı kopuk (Kullanılamıyor) ağ sürücüleri yukarıda görünmez: net use listesine de bak
  try {
    foreach ($s in @(cmd /c 'net use 2>nul')) {
      if ($s -match '(?:^|\s)([A-Za-z]):\s+(\\\\\S+)') {
        $h = $matches[1].ToUpperInvariant(); $yol = $matches[2]
        $var = @($r | Where-Object { $_.harf -eq $h })
        if ($var.Count) { if (-not $var[0].ag) { $var[0].ag = $yol } }
        else { [void]$r.Add([pscustomobject]@{ harf = $h; tip = 4; ag = $yol; kopuk = $true }) }
      }
    }
  } catch {}
  $script:BulSurucuOnbellek = @($r)
  return $script:BulSurucuOnbellek
}
function YerelDiskler { $x = @(SurucuListesi | Where-Object { $_.tip -eq 3 } | ForEach-Object { $_.harf }); if (-not $x.Count) { $x = @('C') }; return $x }
# ağ yolu bu bilgisayarın kendisini mi gösteriyor (K: -> \\KALIP1\C gibi)
function KendiYolu([string]$unc) {
  if ($unc -notmatch '^\\\\([^\\]+)\\') { return $false }
  $h = $matches[1].ToUpperInvariant()
  if ($h -eq (BulPc) -or $h -eq 'LOCALHOST' -or $h -eq '127.0.0.1') { return $true }
  try { foreach ($ip in (BulIpler)) { if ($h -eq $ip) { return $true } } } catch {}
  return $false
}
function BulIpler {
  if ($script:BulIpOnbellek) { return $script:BulIpOnbellek }
  $L = @()
  try {
    foreach ($n in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
      if ($n.OperationalStatus -ne 'Up' -or $n.NetworkInterfaceType -in 'Loopback', 'Tunnel') { continue }
      foreach ($u in $n.GetIPProperties().UnicastAddresses) { if ($u.Address.AddressFamily -eq 'InterNetwork' -and "$($u.Address)" -notmatch '^(127|169\.254)\.') { $L += "$($u.Address)" } }
    }
  } catch {}
  $script:BulIpOnbellek = $L
  return $L
}

# klasörün alt klasörleri / dosyaları (yol yoksa ya da okunamazsa boş liste)
function AltKlasorler([string]$yol) { try { return @(Get-ChildItem -LiteralPath $yol -Force -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer }) } catch { return @() } }
function DosyaAra([string]$yol, [string]$filtre, [int]$derinlik = 2) { try { return @(Get-ChildItem -LiteralPath $yol -Filter $filtre -Recurse -Depth $derinlik -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }) } catch { return @() } }

# ---------- kayıt defteri ----------
# Gerber anahtarları altındaki bütün metin değerleri (derinlik ve sayı sınırlı)
function GerberKayitDegerleri {
  if ($null -ne $script:BulKayitOnbellek) { return $script:BulKayitOnbellek }
  $L = New-Object System.Collections.ArrayList
  foreach ($k in 'HKCU:\Software\Gerber', 'HKLM:\SOFTWARE\Gerber', 'HKLM:\SOFTWARE\WOW6432Node\Gerber',
                 'HKCU:\Software\Gerber Technology', 'HKLM:\SOFTWARE\Gerber Technology', 'HKLM:\SOFTWARE\WOW6432Node\Gerber Technology') {
    $var = $false; try { $var = Test-Path -LiteralPath $k } catch {}
    if (-not $var) { continue }
    $anahtarlar = @()
    try { $anahtarlar = @(Get-Item -LiteralPath $k -ErrorAction Stop) + @(Get-ChildItem -LiteralPath $k -Recurse -Depth 5 -ErrorAction SilentlyContinue) } catch {}
    foreach ($a in $anahtarlar) {
      if ($L.Count -gt 5000) { break }
      try {
        foreach ($n in $a.GetValueNames()) {
          $v = $a.GetValue($n)
          foreach ($x in @($v)) { if ($x -is [string] -and $x) { [void]$L.Add([pscustomobject]@{ anahtar = $a.Name; ad = $n; deger = $x }) } }
        }
      } catch {}
    }
  }
  $script:BulKayitOnbellek = @($L)
  return $script:BulKayitOnbellek
}

# ---------- AccuMark program klasörü ----------
$script:AmGerekli = @('csvimprt.exe', 'amsubmit.exe', 'batch.exe', 'amdelete.exe')
function AccuMarkGecerli([string]$yol) {
  if (-not $yol) { return $false }
  try { if (-not (Test-Path -LiteralPath $yol)) { return $false } } catch { return $false }
  foreach ($g in $script:AmGerekli) { if (-not (Test-Path -LiteralPath (Yol $yol $g))) { return $false } }
  return $true
}
function AccuMarkSurum([string]$yol) {
  $t = ''; try { $t = "" + (Get-Content -LiteralPath (Yol $yol 'Version.txt') -TotalCount 1 -ErrorAction Stop) } catch {}
  if ($t -match 'V(\d+)\.(\d+)') { return @{ metin = 'V' + $matches[1] + '.' + $matches[2]; sayi = [int]$matches[1] * 1000 + [int]$matches[2] } }
  if ($yol -match '(?i)AccuMark\s*V(\d+)') { return @{ metin = 'V' + $matches[1]; sayi = [int]$matches[1] * 1000 } }
  try { $v = (Get-Item -LiteralPath (Yol $yol 'batch.exe')).VersionInfo; if ($v.FileMajorPart) { return @{ metin = 'V' + $v.FileMajorPart + '.' + $v.FileMinorPart; sayi = $v.FileMajorPart * 1000 + $v.FileMinorPart } } } catch {}
  return @{ metin = ''; sayi = 0 }
}
function AccuMarkBul([string]$Eski = '') {
  $aday = New-Object System.Collections.ArrayList
  function Ekle($p, $kaynak) { if ($p) { $p = ("" + $p).Trim().Trim('"').TrimEnd('\'); if ($p -match '^([A-Za-z]:\\|\\\\)') { [void]$aday.Add([pscustomobject]@{ yol = $p; kaynak = $kaynak }) } } }
  if ($Eski) { Ekle $Eski 'ayar' }
  # 1) şu an açık Gerber programları (kullanılan sürüm budur)
  foreach ($n in 'amxplore', 'marking', 'model', 'batch', 'bengine', 'order', 'pdsmain', 'AccuMarkNotifications', 'medpro') {
    foreach ($p in @(Get-Process -Name $n -ErrorAction SilentlyContinue)) { try { if ($p.Path) { Ekle (Split-Path -Parent $p.Path) 'açık program' } } catch {} }
  }
  # 2) kayıt defteri: program kaldırma listesi + Gerber anahtarları
  foreach ($u in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall') {
    foreach ($k in @(Get-ChildItem -LiteralPath $u -ErrorAction SilentlyContinue)) {
      $v = $null; try { $v = Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction Stop } catch { continue }
      if ("$($v.DisplayName)" -notmatch '(?i)accumark') { continue }
      foreach ($x in @($v.InstallLocation, $v.DisplayIcon, $v.InstallSource)) {
        if (-not $x) { continue }
        $x = ("" + $x) -replace '"', '' -replace ',\s*-?\d+$', ''
        if ($x -match '(?i)\.(exe|ico|dll)$') { $x = Split-Path -Parent $x }
        Ekle $x 'kayıt defteri'; Ekle (Yol $x 'AccuMark') 'kayıt defteri'
      }
    }
  }
  foreach ($d in (GerberKayitDegerleri)) {
    $x = "" + $d.deger
    if ($x -match '^[A-Za-z]:\\' -and $x -match '(?i)accumark') { if ($x -match '(?i)\.[a-z]{2,4}$') { $x = Split-Path -Parent $x }; Ekle $x 'kayıt defteri'; Ekle (Yol $x 'AccuMark') 'kayıt defteri' }
  }
  # 3) bilinen klasörler (bütün yerel disklerde)
  foreach ($h in (YerelDiskler)) {
    foreach ($pf in "$($h):\Program Files\Gerber Technology", "$($h):\Program Files (x86)\Gerber Technology", "$($h):\Gerber Technology", "$($h):\Program Files\Gerber", "$($h):\Program Files (x86)\Gerber") {
      foreach ($d in (AltKlasorler $pf)) { Ekle (Yol $d.FullName 'AccuMark') 'klasör'; Ekle $d.FullName 'klasör' }
    }
  }
  # 4) PATH
  foreach ($x in ("" + $env:Path) -split ';') { if ($x -match '(?i)accumark') { Ekle $x 'PATH' } }
  $gecerli = @(); $gor = @{}
  foreach ($a in $aday) {
    $k = $a.yol.ToUpperInvariant(); if ($gor.ContainsKey($k)) { continue }; $gor[$k] = 1
    if (-not (AccuMarkGecerli $a.yol)) { continue }
    $s = AccuMarkSurum $a.yol
    $gecerli += [pscustomobject]@{ yol = $a.yol; surum = $s.metin; sayi = $s.sayi; kaynak = $a.kaynak }
  }
  # seçim: açık program > ayarlardaki > en yeni sürüm
  $sira = { param($x) if ($x.kaynak -eq 'açık program') { 2 } elseif ($x.kaynak -eq 'ayar') { 1 } else { 0 } }
  $sec = @($gecerli | Sort-Object @{ Expression = { & $sira $_ }; Descending = $true }, @{ Expression = { $_.sayi }; Descending = $true }) | Select-Object -First 1
  return [pscustomobject]@{ yol = $(if ($sec) { $sec.yol } else { '' }); surum = $(if ($sec) { $sec.surum } else { '' }); kaynak = $(if ($sec) { $sec.kaynak } else { '' }); adaylar = @($gecerli | ForEach-Object { [pscustomobject]@{ yol = $_.yol; surum = $_.surum; kaynak = $_.kaynak } }) }
}

# ---------- müşteri klasörleri (userroot\storage) ----------
function AlanListesi([string]$storage) {
  $ad = @(); $son = [datetime]::MinValue
  foreach ($d in (AltKlasorler $storage)) { $ad += $d.Name.ToUpperInvariant(); if ($d.LastWriteTime -gt $son) { $son = $d.LastWriteTime } }
  return @{ adlar = $ad; son = $son }
}
function UserrootBul([string]$EskiSistem = '', [string]$EskiDepo = '') {
  # sistem klasörü: Batch'in dosyaları (engine.que, bprmtbl) burada; AccuMark bunu hep C:\userroot'ta tutar
  $sistem = ''
  foreach ($u in @($EskiSistem, 'C:\userroot') + @(YerelDiskler | ForEach-Object { "$($_):\userroot" })) {
    if (-not $u) { continue }
    $ok = $false; foreach ($alt in 'bprmtbl', 'engine.que', 'system', 'storage') { try { if (Test-Path -LiteralPath (Yol $u $alt)) { $ok = $true; break } } catch {} }
    if ($ok) { $sistem = $u.TrimEnd('\'); break }
  }
  # müşteri klasörlerinin olduğu yer(ler): her diskte \userroot\storage
  $depolar = @()
  foreach ($s in (SurucuListesi)) {
    if ($s.tip -notin 2, 3, 4) { continue }
    if ($s.tip -eq 4) {
      if ($s.kopuk) { continue }                       # bağlantısı kopuk ağ sürücüsünde beklemeyelim
      if (KendiYolu $s.ag) { continue }                 # bu bilgisayarın kendi diski (K: -> \\KALIP1\C gibi): aynı klasörler
      if ($s.ag -match '^\\\\([^\\]+)\\' -and -not (HostAcik $matches[1])) { continue }   # kapalı bilgisayar: atla
    }
    $st = "$($s.harf):\userroot\storage"
    $ok = $false; try { $ok = Test-Path -LiteralPath $st } catch {}
    if (-not $ok) { continue }
    $al = AlanListesi $st
    $depolar += [pscustomobject]@{ kok = "$($s.harf):\userroot"; harf = $s.harf; tip = $s.tip; ag = $s.ag; alan = $al.adlar.Count; son = $al.son; adlar = $al.adlar }
  }
  # birincil: ayarlardaki (hâlâ duruyorsa) > sistem klasörünün diski (doluysa) > en çok/son kullanılan
  $sec = $null
  if ($EskiDepo) { $sec = @($depolar | Where-Object { $_.kok -ieq $EskiDepo.TrimEnd('\') }) | Select-Object -First 1 }
  if (-not $sec -and $sistem) { $sec = @($depolar | Where-Object { $_.kok -ieq $sistem -and $_.alan -gt 0 }) | Select-Object -First 1 }
  if (-not $sec) { $sec = @($depolar | Where-Object { $_.alan -gt 0 } | Sort-Object @{ Expression = { $_.son }; Descending = $true }, @{ Expression = { $_.alan }; Descending = $true }) | Select-Object -First 1 }
  if (-not $sec) { $sec = @($depolar) | Select-Object -First 1 }
  if (-not $sistem -and $sec) { $sistem = $sec.kok }
  return [pscustomobject]@{
    sistem = $sistem; depo = $(if ($sec) { $sec.kok } else { $sistem }); harf = $(if ($sec) { $sec.harf } else { $(if ($sistem) { $sistem.Substring(0, 1) } else { 'C' }) })
    tip = $(if ($sec) { $sec.tip } else { 3 }); ag = $(if ($sec) { $sec.ag } else { '' }); alan = $(if ($sec) { $sec.alan } else { 0 })
    adlar = $(if ($sec) { $sec.adlar } else { @() })
    depolar = @($depolar | ForEach-Object { [pscustomobject]@{ kok = $_.kok; tip = $_.tip; ag = $_.ag; alan = $_.alan; son = $(if ($_.son -gt [datetime]::MinValue) { $_.son.ToString('s') } else { '' }) } })
  }
}

# ---------- ağ ----------
# 445 (dosya paylaşımı) kapısı açık olanlar; hepsine aynı anda bakar, en fazla $ms bekler
function Acik445([string[]]$adresler, [int]$ms = 700) {
  $is = @()
  foreach ($a in @($adresler | Where-Object { $_ } | Select-Object -Unique)) {
    try { $c = New-Object Net.Sockets.TcpClient; $t = $c.ConnectAsync($a, 445); $is += [pscustomobject]@{ a = $a; c = $c; t = $t } } catch {}
  }
  if ($is.Count) { try { [void][Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($is | ForEach-Object { $_.t }), $ms) } catch {} }
  $acik = @($is | Where-Object { $_.t.Status -eq 'RanToCompletion' -and $_.c.Connected } | ForEach-Object { $_.a })
  foreach ($x in $is) { try { $x.c.Close() } catch {} }
  return $acik
}
# tek bilgisayar için (sonuç saklanır; aynı bilgisayara tekrar tekrar bakılmaz)
function HostAcik([string]$h) {
  if (-not $h) { return $false }
  if (-not $script:BulHostOnbellek) { $script:BulHostOnbellek = @{} }
  $k = $h.ToUpperInvariant()
  if (-not $script:BulHostOnbellek.ContainsKey($k)) { $script:BulHostOnbellek[$k] = [bool](@(Acik445 @($h) 700).Count) }
  return $script:BulHostOnbellek[$k]
}
# verilen köklerde (\\bilgisayar ya da \\bilgisayar\paylaşım) kuyruk dosyasını aynı anda arar.
# Hepsi birlikte en fazla $ms bekler: cevap vermeyen bir bilgisayar (yazıcı, NAS, kapanmakta olan PC) taramayı uzatmaz.
function KuyrukAgdaAra([string[]]$kokler, [string[]]$alt, [int]$ms = 8000) {
  $bulunan = New-Object System.Collections.ArrayList
  $kokler = @($kokler | Where-Object { $_ } | Select-Object -Unique)
  if (-not $kokler.Count) { return @() }
  try {
    $havuz = [RunspaceFactory]::CreateRunspacePool(1, [Math]::Min(32, $kokler.Count)); $havuz.Open()
    $kod = 'param($k, $alt) $t = [char]92; foreach ($a in $alt) { $p = $k.TrimEnd($t) + $t + $a; try { if ([IO.File]::Exists($p)) { return $p } } catch {} }; return ""'
    $isler = @()
    foreach ($k in $kokler) {
      $ps = [PowerShell]::Create(); $ps.RunspacePool = $havuz
      [void]$ps.AddScript($kod).AddArgument($k).AddArgument([string[]]$alt)
      $isler += [pscustomobject]@{ k = $k; ps = $ps; a = $ps.BeginInvoke() }
    }
    $bitis = (Get-Date).AddMilliseconds($ms)
    foreach ($i in $isler) {
      $kalan = [int][Math]::Max(0, ($bitis - (Get-Date)).TotalMilliseconds)
      if ($i.a.AsyncWaitHandle.WaitOne($kalan)) { try { $p = "" + (@($i.ps.EndInvoke($i.a)) | Select-Object -First 1); if ($p) { [void]$bulunan.Add($p) } } catch {} }
      else { BulNot "$($i.k) zamanında cevap vermedi, atlandı." }
    }
  } catch { BulNot ('Ağda aranamadı: ' + $_.Exception.Message) }
  return @($bulunan)
}
# OTOPASTAL olabilecek bilgisayarlar: ağ sürücülerinin bağlı olduğu bilgisayarlar, son konuşulanlar (ARP), aynı ağdaki bütün adresler
function AgBilgisayarlari([switch]$Tara) {
  $once = New-Object System.Collections.ArrayList; $sonra = New-Object System.Collections.ArrayList
  foreach ($s in (SurucuListesi)) { if ($s.ag -match '^\\\\([^\\]+)\\' -and -not (KendiYolu $s.ag)) { [void]$once.Add($matches[1]) } }
  try {
    foreach ($n in @(Get-NetNeighbor -AddressFamily IPv4 -ErrorAction Stop)) {
      if ("$($n.State)" -in 'Reachable', 'Stale', 'Delay', 'Probe' -and "$($n.IPAddress)" -notmatch '^(22[4-9]|23\d|255|169\.254|127)\.' -and "$($n.IPAddress)" -notmatch '\.(0|255)$') { [void]$sonra.Add("$($n.IPAddress)") }
    }
  } catch {
    try { foreach ($s in @(cmd /c 'arp -a 2>nul')) { if ($s -match '^\s+(\d+\.\d+\.\d+\.\d+)\s+[0-9a-fA-F]{2}-') { $ip = $matches[1]; if ($ip -notmatch '^(22[4-9]|23\d|255)\.' -and $ip -notmatch '\.(0|255)$') { [void]$sonra.Add($ip) } } } } catch {}
  }
  if ($Tara) {
    foreach ($ip in (BulIpler)) { if ($ip -match '^(\d+\.\d+\.\d+)\.\d+$') { $on = $matches[1]; for ($i = 1; $i -le 254; $i++) { [void]$sonra.Add("$on.$i") } } }
  }
  $ben = @(BulIpler)
  $hepsi = @(@($once) + @($sonra) | Where-Object { $_ -and $ben -notcontains $_ } | Select-Object -Unique)
  return [pscustomobject]@{ once = @($once | Select-Object -Unique); hepsi = $hepsi }
}

# ---------- AccuNest kuyruğu (ultramrk.umq) ----------
function KuyrukOku([string]$yol) {
  if (-not $script:BulKuyrukOnbellek) { $script:BulKuyrukOnbellek = @{} }
  $ok = $yol.ToUpperInvariant(); if ($script:BulKuyrukOnbellek.ContainsKey($ok)) { return ,$script:BulKuyrukOnbellek[$ok] }
  $b = $null
  try {
    $fs = New-Object IO.FileStream($yol, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    try { $ms = New-Object IO.MemoryStream; $fs.CopyTo($ms); $b = $ms.ToArray() } finally { $fs.Close() }
  } catch { return $null }
  $list = New-Object System.Collections.ArrayList
  if ($b.Length -lt 8) { return ,$list }
  try {
    $cnt = [BitConverter]::ToUInt32($b, 4); $p = 8
    for ($i = 0; $i -lt $cnt -and $p -lt $b.Length; $i++) {
      $tag = [BitConverter]::ToUInt16($b, $p); $p += 2
      if ($tag -eq 0xFFFF) { $p += 2; $ln = [BitConverter]::ToUInt16($b, $p); $p += 2 + $ln }
      $job = [BitConverter]::ToUInt32($b, $p); $st = [BitConverter]::ToUInt32($b, $p + 4); $np = [BitConverter]::ToUInt32($b, $p + 8); $p += 12
      $d = @{}
      for ($k = 0; $k -lt 2 * $np; $k++) {
        $L = [int]$b[$p]; $p++; if ($L -eq 255) { $L = [int][BitConverter]::ToUInt16($b, $p); $p += 2 }
        $s = $script:BulEnc.GetString($b, $p, $L); $p += $L
        if ($k % 2 -eq 0) { $key = $s } else { $d[$key] = $s }
      }
      [void]$list.Add(@{ job = $job; st = $st; d = $d })
    }
  } catch {}
  $script:BulKuyrukOnbellek[$ok] = $list
  return ,$list
}
# kuyruk dosyası hangi bilgisayarda: \\OTOPASTAL\... -> OTOPASTAL ; yerel yol -> ''
function KuyrukSunucusu([string]$yol) { if ($yol -match '^\\\\([^\\]+)\\') { return $matches[1] }; return '' }
function KuyrukDegerlendir([string]$yol, [string]$kaynak, $alanlar) {
  $o = [ordered]@{ yol = $yol; kaynak = $kaynak; erisim = $false; sunucu = (KuyrukSunucusu $yol); son = ''; kayit = 0; bizden = 0; alanimiz = 0; puan = 0 }
  if ($o.sunucu -and -not (KendiYolu $yol) -and -not (HostAcik $o.sunucu)) { return [pscustomobject]$o }   # kapalı bilgisayarda beklenmez
  $f = $null; try { $f = Get-Item -LiteralPath $yol -ErrorAction Stop } catch {}
  if (-not $f) { return [pscustomobject]$o }
  $o.erisim = $true; $o.son = $f.LastWriteTime.ToString('s')
  $kayitlar = KuyrukOku $yol
  $pc = (BulPc).ToLowerInvariant()
  if ($kayitlar) {
    $o.kayit = $kayitlar.Count
    foreach ($q in $kayitlar) {
      if (("" + $q.d['station']).ToLowerInvariant() -eq $pc) { $o.bizden++ }
      if ($alanlar -and $alanlar.Contains(("" + $q.d['area']).ToUpperInvariant())) { $o.alanimiz++ }
    }
  }
  $gun = ((Get-Date) - $f.LastWriteTime).TotalDays
  $p = 0
  if ($o.bizden) { $p += 40 }; if ($o.alanimiz) { $p += 30 }
  if ($kaynak -eq 'ayar') { $p += 20 } elseif ($kaynak -eq 'kayıt defteri') { $p += 10 }
  if ($gun -lt 1) { $p += 10 } elseif ($gun -lt 7) { $p += 6 } elseif ($gun -lt 60) { $p += 3 }
  if ($o.kayit) { $p += 2 }
  if ($o.sunucu -and $o.sunucu -notmatch '^\d+\.\d+\.\d+\.\d+$') { $p += 1 }
  $o.puan = $p
  return [pscustomobject]$o
}
function KuyrukBul([string]$Eski = '', $alanlar = $null, [switch]$AgTara, [switch]$Tam, [int]$Butce = 25) {
  $t0 = Get-Date
  $aday = New-Object System.Collections.ArrayList
  function Ekle($p, $kaynak) { if ($p) { $p = ("" + $p).Trim().Trim('"'); if ($p -match '(?i)\.umq$') { [void]$aday.Add([pscustomobject]@{ yol = $p; kaynak = $kaynak }) } } }
  if ($Eski) { Ekle $Eski 'ayar' }
  # 1) kayıt defteri: UltraQueue'nun varsayılan kuyruğu ve son açılan kuyruklar
  foreach ($d in (GerberKayitDegerleri)) { if ("$($d.deger)" -match '(?i)\.umq') { Ekle $d.deger 'kayıt defteri' } }
  # 2) bu bilgisayardaki varsayılan yerler
  foreach ($k in @("$env:PUBLIC\Gerber Technology", "$env:ProgramData\Gerber Technology", 'C:\Users\Public\Gerber Technology', 'C:\ProgramData\Gerber Technology', "$env:ALLUSERSPROFILE\Application Data\Gerber Technology") | Select-Object -Unique) {
    if (-not $k -or $k -match '^\\') { continue }
    foreach ($f in (DosyaAra $k '*.umq' 2)) { Ekle $f.FullName 'bu bilgisayar' }
  }
  # 3) ağ sürücülerinin bağlı olduğu paylaşımlar (cevap vermeyen bilgisayar beklenmez)
  $alt = @('Users\Public\Gerber Technology\Queue\ultramrk.umq', 'Users\Public\Gerber Technology\ultramrk.umq', 'Public\Gerber Technology\Queue\ultramrk.umq', 'Public\Gerber Technology\ultramrk.umq',
           'Gerber Technology\Queue\ultramrk.umq', 'Gerber Technology\ultramrk.umq', 'Queue\ultramrk.umq', 'ultramrk\ultramrk.umq',
           'C\Users\Public\Gerber Technology\Queue\ultramrk.umq', 'C\ProgramData\Gerber Technology\ultramrk.umq', 'C\ProgramData\Gerber Technology\Queue\ultramrk.umq', 'ProgramData\Gerber Technology\ultramrk.umq')
  $payAlt = @('ultramrk.umq', 'Queue\ultramrk.umq', 'Gerber Technology\Queue\ultramrk.umq', 'Gerber Technology\ultramrk.umq', 'Public\Gerber Technology\Queue\ultramrk.umq')
  $payKok = @()
  foreach ($s in (SurucuListesi)) {
    if ($s.tip -ne 4 -or $s.kopuk -or -not $s.ag -or (KendiYolu $s.ag)) { continue }
    if ($s.ag -match '^\\\\([^\\]+)\\' -and (HostAcik $matches[1])) { $payKok += $s.ag }
  }
  foreach ($p in (KuyrukAgdaAra $payKok $payAlt 5000)) { Ekle $p 'ağ sürücüsü' }
  # bulunanlardan biri bu bilgisayarın işlerini ya da klasörlerini içeriyorsa ağa bakmaya gerek yok (Tam istenmediyse)
  $guclu = $false
  if (-not $Tam) { foreach ($a in $aday) { $d = KuyrukDegerlendir $a.yol $a.kaynak $alanlar; if ($d.erisim -and ($d.bizden -or $d.alanimiz)) { $guclu = $true; break } } }
  $bakildi = 0; $acikSay = 0
  if (-not $guclu) {
    # 4) önce ağ sürücülerinin bilgisayarları ve son konuşulan bilgisayarlar; hepsine aynı anda, her biri en fazla birkaç saniye
    $ag = AgBilgisayarlari
    $acik = @(Acik445 $ag.hepsi 900)
    $sira = @($ag.once | Where-Object { $acik -contains $_ }) + @($acik | Where-Object { $ag.once -notcontains $_ })
    foreach ($p in (KuyrukAgdaAra @($sira | ForEach-Object { '\\' + $_ }) $alt 8000)) { Ekle $p 'ağ' }
    $bakildi = $sira.Count; $acikSay = $acik.Count
    # 5) hâlâ bulunamadıysa (ya da tam tarama istendiyse) aynı ağdaki bütün adresler
    $erisilebilir = @($aday | Where-Object { $_.kaynak -ne 'ayar' -or (KuyrukDegerlendir $_.yol $_.kaynak $alanlar).erisim })
    if ($AgTara -and ($Tam -or -not $erisilebilir.Count)) {
      $ag2 = AgBilgisayarlari -Tara
      $yeni = @($ag2.hepsi | Where-Object { $sira -notcontains $_ })
      $acik2 = @(Acik445 $yeni 900)
      foreach ($p in (KuyrukAgdaAra @($acik2 | ForEach-Object { '\\' + $_ }) $alt 8000)) { Ekle $p 'ağ' }
      $bakildi += $acik2.Count; $acikSay += $acik2.Count
    }
  }
  # değerlendir: aynı dosya farklı yazılmış olabilir (ad / IP); en yüksek puanlı seçilir
  $deg = @(); $gor = @{}
  foreach ($a in $aday) {
    $k = $a.yol.ToUpperInvariant(); if ($gor.ContainsKey($k)) { continue }; $gor[$k] = 1
    $deg += KuyrukDegerlendir $a.yol $a.kaynak $alanlar
  }
  $erisilen = @($deg | Where-Object { $_.erisim })
  $sec = @($erisilen | Sort-Object @{ Expression = { $_.puan }; Descending = $true }) | Select-Object -First 1
  return [pscustomobject]@{
    yol = $(if ($sec) { $sec.yol } else { '' }); yer = $(if (-not $sec) { '' } elseif ($sec.yol -match '^\\\\') { $(if (KendiYolu $sec.yol) { 'yerel' } else { 'ag' }) } else { 'yerel' })
    sunucu = $(if ($sec) { $sec.sunucu } else { '' }); kaynak = $(if ($sec) { $sec.kaynak } else { '' })
    adaylar = $deg; bakilan_bilgisayar = $bakildi; acik_bilgisayar = $acikSay; sure_ms = [int]((Get-Date) - $t0).TotalMilliseconds
  }
}

# ---------- OTOPASTAL pastallara hangi sürücü harfiyle ulaşıyor ----------
# Kuyruktaki geçmiş işlerden öğrenilir: bu bilgisayarın klasörlerindeki pastallar hangi harfle başarıyla yerleşmiş.
function CihazOgren($kayitlar, $alanlar) {
  $puan = @{}; $pc = (BulPc).ToLowerInvariant()
  if (-not $kayitlar -or -not $alanlar) { return @() }
  foreach ($q in $kayitlar) {
    $d = $q.d; $dev = ("" + $d['device']).ToLowerInvariant(); if ($dev -notmatch '^[a-z]:$') { continue }
    if (-not $alanlar.Contains(("" + $d['area']).ToUpperInvariant())) { continue }
    $adet = "" + $d['bundle_count']
    $ok = ($d['type'] -eq 'commit' -and $d['result'] -eq 'committed') -or ($d['type'] -eq 'fraun' -and $d['result'] -eq '1' -and $adet -notin '', '0')
    $bos = ($d['type'] -eq 'fraun' -and $d['result'] -and $adet -in '', '0')
    $w = $(if (("" + $d['station']).ToLowerInvariant() -eq $pc) { 3 } else { 1 })
    if (-not $puan.ContainsKey($dev)) { $puan[$dev] = 0 }
    if ($ok) { $puan[$dev] += $w } elseif ($bos) { $puan[$dev] -= $w }
  }
  return @($puan.GetEnumerator() | Where-Object { $_.Value -gt 0 } | Sort-Object Value -Descending | ForEach-Object { $_.Key })
}
function PaylasimBul([string]$harf) {
  $h = $harf.TrimEnd(':').ToUpperInvariant()
  try { foreach ($s in @(Get-CimInstance Win32_Share -ErrorAction Stop)) { if (("" + $s.Path).TrimEnd('\').ToUpperInvariant() -eq "$($h):" -and $s.Name -notmatch '\$$') { return "" + $s.Name } } } catch {}
  try { foreach ($s in @(cmd /c 'net share 2>nul')) { if ($s -match '^(\S+)\s+([A-Za-z]):\\\s*$' -or $s -match '^(\S+)\s+([A-Za-z]):\\\s') { if ($matches[2].ToUpperInvariant() -eq $h -and $matches[1] -notmatch '\$$') { return $matches[1] } } } } catch {}
  return ''
}
# bu bilgisayarda kendi diskine bağlanmış harf (K: -> \\KALIP1\C): OTOPASTAL'da da aynı harf kullanılır
function KendiHarfi([string]$depoHarf) {
  foreach ($s in (SurucuListesi)) { if ($s.tip -eq 4 -and $s.ag -and (KendiYolu $s.ag)) { return $s.harf.ToLowerInvariant() + ':' } }
  return ''
}
function BosHarf {
  $dolu = @(SurucuListesi | ForEach-Object { $_.harf })
  foreach ($h in 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y') { if ($dolu -notcontains $h) { return $h.ToLowerInvariant() + ':' } }
  return 'k:'
}

# ---------- aynı bilgisayardaki AccuNest kuyruk sunucusu (OTOPASTAL programı) ----------
function KuyrukProgramiBul {
  $sonuc = [ordered]@{ exe = ''; ad = ''; calisiyor = $false }
  $bilinen = 'UltraNst', 'AccuNestSrv', 'EngServ', 'NesterServer'
  foreach ($n in $bilinen) { if (@(Get-Process -Name $n -ErrorAction SilentlyContinue).Count) { $sonuc.calisiyor = $true; $sonuc.ad = $n; break } }
  try {
    $w = New-Object -ComObject WScript.Shell
    $yerler = @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs") | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    $lnk = @(Get-ChildItem -LiteralPath $yerler -Recurse -Filter *.lnk -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match '(?i)ultraqueue|accunest|nest|gerber' })
    $iyi = @($lnk | Where-Object { $_.BaseName -match '(?i)queue\s*server|kuyruk\s*sunucu|accunest.*server|nest.*server' }) + @($lnk)
    foreach ($l in $iyi) {
      $t = ''; try { $t = $w.CreateShortcut($l.FullName).TargetPath } catch {}
      if ($t -and $t -match '(?i)\.exe$' -and (Split-Path -Leaf $t) -match '(?i)^(UltraNst|AccuNestSrv|NestServ|EngServ)') { $sonuc.exe = $t; break }
    }
  } catch {}
  if (-not $sonuc.exe) {
    foreach ($h in (YerelDiskler)) { foreach ($k in "$($h):\AccuNest", "$($h):\Program Files\Gerber Technology\AccuNest", "$($h):\Program Files (x86)\Gerber Technology\AccuNest") { $x = Yol $k 'UltraNst.exe'; if (Test-Path -LiteralPath $x) { $sonuc.exe = $x; break } }; if ($sonuc.exe) { break } }
  }
  return [pscustomobject]$sonuc
}

# ---------- hepsi ----------
# $Eski: şu anki ayarlar (Ayarlar fonksiyonunun döndürdüğü). Dönen 'oneri' doğrudan ayarlar.json'a yazılabilir.
function GerberBul($Eski = $null, [switch]$AgTara, [switch]$Tam, [int]$Butce = 25) {
  $t0 = Get-Date
  $script:BulNotlar = New-Object System.Collections.ArrayList
  $script:BulSurucuOnbellek = $null; $script:BulKayitOnbellek = $null; $script:BulIpOnbellek = $null; $script:BulKuyrukOnbellek = @{}; $script:BulHostOnbellek = @{}
  $e = @{}
  if ($Eski) {
    foreach ($k in 'accumark', 'userroot', 'depo', 'kuyruk', 'surucu', 'surucu2', 'otopastal', 'gerber') {
      $v = $null
      if ($Eski -is [System.Collections.IDictionary]) { if ($Eski.Contains($k)) { $v = $Eski[$k] } } else { try { $v = $Eski.$k } catch {} }
      $e[$k] = $(if ($null -ne $v) { "" + $v } else { '' })
    }
  }
  $am = AccuMarkBul $e['accumark']
  $ur = UserrootBul $e['userroot'] $e['depo']
  $alanlar = New-Object 'System.Collections.Generic.HashSet[string]'; foreach ($x in @($ur.adlar)) { [void]$alanlar.Add($x) }
  $ku = $null
  if ($am.yol -or $ur.alan) { $ku = KuyrukBul $e['kuyruk'] $alanlar -AgTara:$AgTara -Tam:$Tam -Butce $Butce }
  else { $ku = [pscustomobject]@{ yol = ''; yer = ''; sunucu = ''; kaynak = ''; adaylar = @(); bakilan_bilgisayar = 0; acik_bilgisayar = 0 } }
  $nestPc = ''
  if ($ku.yol) {
    $sv = @{}; foreach ($x in (KuyrukOku $ku.yol)) { $n = ("" + $x.d['server']).Trim(); if ($n -and $x.d['result']) { $sv[$n.ToUpperInvariant()] = 1 + [int]$sv[$n.ToUpperInvariant()] } }
    if ($sv.Count) { $nestPc = @($sv.GetEnumerator() | Sort-Object Value -Descending)[0].Key }
    elseif ($ku.yer -eq 'yerel') { $nestPc = BulPc } else { $nestPc = ("" + $ku.sunucu).ToUpperInvariant() }
  }
  $oto = $(if (-not $ku.yol) { 'yok' } elseif ($nestPc -eq (BulPc)) { 'ayni' } else { 'ayri' })
  # sürücü harfi
  $depoHarf = ("" + $ur.harf).ToLowerInvariant() + ':'
  $ogr = @(); if ($ku.yol) { $ogr = @(CihazOgren (KuyrukOku $ku.yol) $alanlar) }
  $harf = ''; $yedek = ''; $kaynak = ''; $sunucudaGerekli = $false
  if ($oto -eq 'ayni') { $harf = $(if ($ogr.Count) { $ogr[0] } else { $depoHarf }); $kaynak = $(if ($ogr.Count) { 'geçmiş işler' } else { 'aynı bilgisayar' }) }
  elseif ($oto -eq 'ayri') {
    if ($ogr.Count) {
      # şu anki harf geçmişte de çalışmışsa onu koru; öbürü yedek olur
      $eh0 = ("" + $e['surucu']).ToLowerInvariant()
      $sira = @(@($(if ($ogr -contains $eh0) { $eh0 })) + @($ogr | Where-Object { $_ -ne $eh0 }) | Where-Object { $_ })
      $harf = $sira[0]; $kaynak = 'geçmiş işler'; if ($sira.Count -gt 1) { $yedek = $sira[1] }
    }
    elseif ($ur.tip -eq 4) { $harf = $depoHarf; $kaynak = 'ağdaki müşteri klasörleri' }
    else {
      $kh = KendiHarfi $depoHarf; $eh = ("" + $e['surucu']).ToLowerInvariant()
      if ($eh -match '^[a-z]:$' -and $e['kuyruk'] -and $e['kuyruk'] -ieq $ku.yol) { $harf = $eh; $kaynak = 'ayar' }
      elseif ($kh) { $harf = $kh; $kaynak = 'bu bilgisayardaki bağlantı' }
      else { $harf = BosHarf; $kaynak = 'yeni' }
    }
    # geçmiş işlerle kanıtlanmadıysa OTOPASTAL'da bir kerelik bağlantı dosyası çalıştırılmalı (dosya zaten bağlıysa bir şey değiştirmez)
    $sunucudaGerekli = ($kaynak -notin 'geçmiş işler', 'ağdaki müşteri klasörleri')
    if (-not $yedek) { foreach ($x in @($e['surucu'], $e['surucu2'], 'k:', 'z:')) { $x = ("" + $x).ToLowerInvariant(); if ($x -match '^[a-z]:$' -and $x -ne $harf) { $yedek = $x; break } } }
  }
  # paylaşım: OTOPASTAL ayrı bilgisayardaysa ve müşteri klasörleri bu bilgisayarın diskindeyse gerekir
  $pay = ''; $payGerekli = $false
  if ($oto -eq 'ayri' -and $ur.tip -ne 4) { $pay = PaylasimBul $ur.harf; $payGerekli = -not $pay }
  $prog = $null; if ($oto -eq 'ayni') { $prog = KuyrukProgramiBul }
  if (-not $am.yol) { BulNot 'Gerber AccuMark bulunamadı: sadece asorti kurulur.' }
  if ($am.yol -and -not $ur.alan) { BulNot 'AccuMark var ama müşteri klasörü (userroot\storage) bulunamadı ya da boş.' }
  if ($am.yol -and $oto -eq 'yok') { BulNot 'OTOPASTAL (AccuNest kuyruğu) bulunamadı: pastallar Gerber''de oluşturulur, yerleştirmeyi elle yaparsın.' }
  $oneri = [ordered]@{
    gerber = [bool]$am.yol; accumark = $am.yol; userroot = $(if ($ur.sistem) { $ur.sistem } else { 'C:\userroot' }); depo = $ur.depo
    kuyruk = $ku.yol; otopastal = $oto; surucu = $(if ($harf) { $harf } else { 'k:' }); surucu2 = $(if ($yedek) { $yedek } else { 'z:' })
  }
  return [pscustomobject]@{
    zaman = (Get-Date).ToString('s'); bilgisayar = (BulPc); sure_ms = [int]((Get-Date) - $t0).TotalMilliseconds
    accumark = $am; userroot = [pscustomobject]@{ sistem = $ur.sistem; depo = $ur.depo; harf = $ur.harf; tip = $ur.tip; ag = $ur.ag; alan = $ur.alan; depolar = $ur.depolar }
    kuyruk = $ku; otopastal = $oto; otopastal_bilgisayari = $nestPc
    cihaz = [pscustomobject]@{ harf = $harf; yedek = $yedek; kaynak = $kaynak; ogrenilen = $ogr; sunucuda_baglanti_gerekli = $sunucudaGerekli }
    paylasim = [pscustomobject]@{ ad = $pay; gerekli = $payGerekli; bilgisayar = (BulPc) }
    kuyruk_programi = $prog
    notlar = @($script:BulNotlar)
    oneri = [pscustomobject]$oneri
  }
}
