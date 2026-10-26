# Asorti Aracı - kurulum sihirbazı
# Paket yapısı:  Kurulum.bat | kurulum\Kurulum.ps1 | AsortiAraci\ (uygulama dosyaları)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$ErrorActionPreference = 'Stop'
# siyah komut penceresini gizle (sihirbaz kendi penceresinde açılır)
try {
  Add-Type -Name Pencere -Namespace Asorti -MemberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);'
  [void][Asorti.Pencere]::ShowWindow([Asorti.Pencere]::GetConsoleWindow(), 0)
} catch {}
trap { try { [Windows.Forms.MessageBox]::Show("Kurulum sihirbazında beklenmeyen hata:`r`n" + $_.Exception.Message + "`r`n(satır " + $_.InvocationInfo.ScriptLineNumber + ")", 'Asorti Aracı') | Out-Null } catch {}; exit 1 }

$PAKET  = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$KAYNAK = Join-Path $PAKET 'AsortiAraci'
$PC     = $env:COMPUTERNAME
$ESKI   = 'C:\AccuNest'          # ilk denemelerin yapıldığı eski yer

# ---------- yardımcılar ----------
$script:logSatir = New-Object System.Collections.ArrayList
function Not($s) { [void]$script:logSatir.Add((Get-Date -Format 'HH:mm:ss') + ' ' + $s) }
function Paylasimlar { try { @(cmd /c 'net share 2>nul' | ForEach-Object { if ($_ -match '^(\S+)\s+([A-Za-z]:\\\S*)') { [pscustomobject]@{ ad = $matches[1]; yol = $matches[2] } } }) } catch { @() } }
function CPaylasimi { @(Paylasimlar | Where-Object { $_.yol -match '^[Cc]:\\$' -and $_.ad -notmatch '\$$' }) | Select-Object -First 1 }
function SurucuBaglantisi($harf) {
  $h = $harf.TrimEnd(':').ToUpperInvariant() + ':'
  try { $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$h'" -ErrorAction Stop; if ($d) { return [pscustomobject]@{ var = $true; yol = "$($d.ProviderName)"; tip = [int]$d.DriveType } } } catch {}
  # bağlantısı kopuk (Kullanılamıyor) ağ sürücüleri yukarıda görünmez; net use listesine de bak
  foreach ($s in @(cmd /c 'net use 2>nul')) { if ($s -match ('\s' + [regex]::Escape($h) + '\s+(\\\\\S+)')) { return [pscustomobject]@{ var = $true; yol = $matches[1]; tip = 4 } } }
  return [pscustomobject]@{ var = $false; yol = ''; tip = 0 }
}
function AccuMarkBul {
  $aday = @('C:\Program Files\Gerber Technology\AccuMark V12\AccuMark', 'C:\Program Files (x86)\Gerber Technology\AccuMark V12\AccuMark')
  $aday += @(Get-ChildItem 'C:\Program Files\Gerber Technology', 'C:\Program Files (x86)\Gerber Technology' -Directory -ErrorAction SilentlyContinue | ForEach-Object { Join-Path $_.FullName 'AccuMark' })
  foreach ($a in $aday) { if ($a -and (Test-Path (Join-Path $a 'csvimprt.exe'))) { return $a } }
  return ''
}
function TarayiciBul {
  @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
}
function UygulamaSurecleri {
  @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    ($_.Name -eq 'powershell.exe' -and $_.CommandLine -match '(sunucu|kopru)\.ps1') -or
    ($_.Name -match '^(msedge|chrome)\.exe$' -and $_.CommandLine -match '(AccuNest\\uygulama|AsortiAraci)\\profil') })
}

# eski kurulumdan bilinen değerleri al
$eskiAyar = $null
foreach ($f in @('C:\AsortiAraci\ayarlar.json')) { if (Test-Path $f) { try { $eskiAyar = Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json } catch {} } }

# ---------- pencere ----------
$F = New-Object Windows.Forms.Form
$F.Text = 'Asorti Aracı - Kurulum'; $F.Size = New-Object Drawing.Size(700, 520); $F.StartPosition = 'CenterScreen'
$F.FormBorderStyle = 'FixedDialog'; $F.MaximizeBox = $false; $F.Font = New-Object Drawing.Font('Segoe UI', 9.5)
$ikon = Join-Path $KAYNAK 'sistem\asorti.ico'; if (Test-Path $ikon) { $F.Icon = New-Object Drawing.Icon($ikon) }

$ust = New-Object Windows.Forms.Panel; $ust.Dock = 'Top'; $ust.Height = 64; $ust.BackColor = [Drawing.Color]::FromArgb(47, 124, 246)
$baslik = New-Object Windows.Forms.Label; $baslik.ForeColor = 'White'; $baslik.Font = New-Object Drawing.Font('Segoe UI', 14, [Drawing.FontStyle]::Bold)
$baslik.Location = New-Object Drawing.Point(20, 8); $baslik.AutoSize = $true; $ust.Controls.Add($baslik)
$altBaslik = New-Object Windows.Forms.Label; $altBaslik.ForeColor = [Drawing.Color]::FromArgb(225, 235, 255); $altBaslik.Location = New-Object Drawing.Point(22, 38); $altBaslik.AutoSize = $true; $ust.Controls.Add($altBaslik)

$alt = New-Object Windows.Forms.Panel; $alt.Dock = 'Bottom'; $alt.Height = 54
$bGeri = New-Object Windows.Forms.Button; $bGeri.Text = '< Geri'; $bGeri.Size = New-Object Drawing.Size(100, 32); $bGeri.Location = New-Object Drawing.Point(358, 11)
$bIleri = New-Object Windows.Forms.Button; $bIleri.Text = 'İleri >'; $bIleri.Size = New-Object Drawing.Size(110, 32); $bIleri.Location = New-Object Drawing.Point(464, 11)
$bIptal = New-Object Windows.Forms.Button; $bIptal.Text = 'İptal'; $bIptal.Size = New-Object Drawing.Size(90, 32); $bIptal.Location = New-Object Drawing.Point(582, 11)
$alt.Controls.AddRange(@($bGeri, $bIleri, $bIptal))

$orta = New-Object Windows.Forms.Panel; $orta.Dock = 'Fill'; $orta.Padding = New-Object Windows.Forms.Padding(22, 14, 22, 6)
$F.Controls.Add($orta); $F.Controls.Add($alt); $F.Controls.Add($ust)

function Yazi($metin, $x, $y, $w, $h) { $l = New-Object Windows.Forms.Label; $l.Text = $metin; $l.Location = New-Object Drawing.Point($x, $y); $l.Size = New-Object Drawing.Size($w, $h); return $l }
function Kutu($metin, $x, $y, $w) { $t = New-Object Windows.Forms.TextBox; $t.Text = $metin; $t.Location = New-Object Drawing.Point($x, $y); $t.Width = $w; return $t }

# ---- sayfa 1: hoş geldin ----
$s1 = New-Object Windows.Forms.Panel; $s1.Dock = 'Fill'
$s1.Controls.Add((Yazi ("Bu sihirbaz Asorti Aracı'nı bu bilgisayara kurar:`r`n`r`n" +
  "  •  Asorti Aracı uygulaması (çalışma sayfaları, Excel, yazdırma)`r`n" +
  "  •  Gerber köprüsü: siparişleri Gerber'e alır, Batch ile pastal hazırlar,`r`n" +
  "     OTOPASTAL kuyruğuna gönderir ve sonuçları geri getirir`r`n" +
  "  •  Masaüstü ve Başlat menüsü kısayolu`r`n`r`n" +
  "Uygulama açılınca köprü ve Batch arka planda kendiliğinden çalışır, pencere`r`n" +
  "kapanınca hepsi kapanır. Bilgisayar açılışında hiçbir şey kendi başına çalışmaz.`r`n`r`n" +
  "Devam etmeden önce açık bir Asorti Aracı penceresi varsa kapat.") 0 0 640 300))

# ---- sayfa 2: kontroller ----
$s2 = New-Object Windows.Forms.Panel; $s2.Dock = 'Fill'
$liste = New-Object Windows.Forms.ListView; $liste.View = 'Details'; $liste.FullRowSelect = $true; $liste.HeaderStyle = 'Nonclickable'
$liste.Location = New-Object Drawing.Point(0, 0); $liste.Size = New-Object Drawing.Size(640, 218)
[void]$liste.Columns.Add('', 34); [void]$liste.Columns.Add('Kontrol', 190); [void]$liste.Columns.Add('Sonuç', 400)
$s2.Controls.Add($liste)
$s2.Controls.Add((Yazi 'AccuMark klasörü:' 0 231 120 20)); $tAM = Kutu '' 125 228 420; $s2.Controls.Add($tAM)
$bAM = New-Object Windows.Forms.Button; $bAM.Text = 'Gözat…'; $bAM.Location = New-Object Drawing.Point(552, 226); $bAM.Size = New-Object Drawing.Size(88, 26); $s2.Controls.Add($bAM)
$bYenile = New-Object Windows.Forms.Button; $bYenile.Text = 'Tekrar kontrol et'; $bYenile.Location = New-Object Drawing.Point(0, 262); $bYenile.Size = New-Object Drawing.Size(140, 28); $s2.Controls.Add($bYenile)
$bPay = New-Object Windows.Forms.Button; $bPay.Text = 'C: paylaşımını oluştur (yönetici izni ister)'; $bPay.Location = New-Object Drawing.Point(150, 262); $bPay.Size = New-Object Drawing.Size(300, 28); $bPay.Visible = $false; $s2.Controls.Add($bPay)
$cSadece = New-Object Windows.Forms.CheckBox; $cSadece.Text = "Bu bilgisayarda Gerber yok: sadece asorti kur (Gerber'e gönderme ve en verimli asorti kapalı olur)"
$cSadece.Location = New-Object Drawing.Point(0, 298); $cSadece.Size = New-Object Drawing.Size(640, 24); $s2.Controls.Add($cSadece)
$lKontrol = Yazi '' 0 328 640 40; $lKontrol.ForeColor = [Drawing.Color]::DimGray; $s2.Controls.Add($lKontrol)

# ---- sayfa 3: ayarlar ----
$s3 = New-Object Windows.Forms.Panel; $s3.Dock = 'Fill'
$s3.Controls.Add((Yazi 'Kurulum klasörü' 0 4 200 20)); $tHedef = Kutu 'C:\AsortiAraci' 0 26 540; $s3.Controls.Add($tHedef)
$lKuyruk = Yazi 'OTOPASTAL kuyruk dosyası (ultramrk.umq)' 0 62 400 20; $s3.Controls.Add($lKuyruk)
$tKuyruk = Kutu '\\192.168.2.203\Users\Public\Gerber Technology\Queue\ultramrk.umq' 0 84 640; $s3.Controls.Add($tKuyruk)
$lHarfB = Yazi 'Sürücü harfi (OTOPASTAL ve bu bilgisayar bu bilgisayarın C: diskini bu harfle görür)' 0 120 640 20; $s3.Controls.Add($lHarfB)
$cHarf = New-Object Windows.Forms.ComboBox; $cHarf.DropDownStyle = 'DropDownList'; $cHarf.Location = New-Object Drawing.Point(0, 142); $cHarf.Width = 70
foreach ($h in 'K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y') { [void]$cHarf.Items.Add($h) }; $cHarf.SelectedItem = 'K'; $s3.Controls.Add($cHarf)
$lHarf = Yazi '' 80 145 560 40; $lHarf.ForeColor = [Drawing.Color]::DimGray; $s3.Controls.Add($lHarf)
$s3.Controls.Add((Yazi 'Uygulama bağlantı noktası (değiştirmen gerekmez)' 0 192 400 20)); $tPort = Kutu '8642' 0 214 80; $s3.Controls.Add($tPort)
$cTemiz = New-Object Windows.Forms.CheckBox; $cTemiz.Text = "Eski deneme dosyalarını temizle ($ESKI içindeki Asorti Aracı dosyaları; QueueSubmit dosyalarına dokunulmaz)"
$cTemiz.Location = New-Object Drawing.Point(0, 254); $cTemiz.Size = New-Object Drawing.Size(640, 40); $cTemiz.Checked = (Test-Path (Join-Path $ESKI 'kopru')); $cTemiz.Visible = (Test-Path (Join-Path $ESKI 'kopru')); $s3.Controls.Add($cTemiz)
if ($eskiAyar) {
  if ("$($eskiAyar.gerber)" -match '^(?i)false$') { $script:sessiz = $true; $cSadece.Checked = $true; $script:sessiz = $false }
  $script:ilkKontrol = $true
  if ($eskiAyar.kuyruk) { $tKuyruk.Text = $eskiAyar.kuyruk }
  if ($eskiAyar.surucu) { $h = "$($eskiAyar.surucu)".TrimEnd(':').ToUpperInvariant(); if ($cHarf.Items.Contains($h)) { $cHarf.SelectedItem = $h } }
  if ($eskiAyar.port) { $tPort.Text = "$($eskiAyar.port)" }
  if ($eskiAyar.accumark -and (Test-Path (Join-Path $eskiAyar.accumark 'csvimprt.exe'))) { $tAM.Text = $eskiAyar.accumark }
}
function GerberAlanlari { $v = -not $cSadece.Checked; foreach ($c in @($lKuyruk, $tKuyruk, $lHarfB, $cHarf, $lHarf)) { $c.Visible = $v } }
function HarfBilgi {
  $b = SurucuBaglantisi $cHarf.SelectedItem; $hedefYol = "\\$PC\" + $(if (CPaylasimi) { (CPaylasimi).ad } else { 'C' })
  if (-not $b.var) { $lHarf.Text = "Boş. Kurulum $($cHarf.SelectedItem): sürücüsünü $hedefYol olarak bağlayacak."; $lHarf.ForeColor = [Drawing.Color]::DimGray }
  elseif ($b.yol -and $b.yol.ToUpperInvariant() -eq $hedefYol.ToUpperInvariant()) { $lHarf.Text = "Zaten $hedefYol olarak bağlı. ✔"; $lHarf.ForeColor = [Drawing.Color]::ForestGreen }
  else { $lHarf.Text = "Bu harf başka bir şeye bağlı ($($b.yol)). Başka bir harf seç."; $lHarf.ForeColor = [Drawing.Color]::Firebrick }
}
$cHarf.Add_SelectedIndexChanged({ HarfBilgi })

# ---- sayfa 4: kurulum ----
$s4 = New-Object Windows.Forms.Panel; $s4.Dock = 'Fill'
$ilerleme = New-Object Windows.Forms.ProgressBar; $ilerleme.Location = New-Object Drawing.Point(0, 4); $ilerleme.Size = New-Object Drawing.Size(640, 22); $s4.Controls.Add($ilerleme)
$adimlar = New-Object Windows.Forms.ListBox; $adimlar.Location = New-Object Drawing.Point(0, 36); $adimlar.Size = New-Object Drawing.Size(640, 300); $s4.Controls.Add($adimlar)

# ---- sayfa 5: bitti ----
$s5 = New-Object Windows.Forms.Panel; $s5.Dock = 'Fill'
$lBitti = Yazi '' 0 0 640 250; $s5.Controls.Add($lBitti)
$bOtoKopya = New-Object Windows.Forms.Button; $bOtoKopya.Text = 'OTOPASTAL komutunu kopyala'; $bOtoKopya.Location = New-Object Drawing.Point(0, 256); $bOtoKopya.Size = New-Object Drawing.Size(230, 30); $s5.Controls.Add($bOtoKopya)
$cAc = New-Object Windows.Forms.CheckBox; $cAc.Text = "Asorti Aracı'nı şimdi aç"; $cAc.Checked = $true; $cAc.Location = New-Object Drawing.Point(0, 300); $cAc.AutoSize = $true; $s5.Controls.Add($cAc)

$sayfalar = @($s1, $s2, $s3, $s4, $s5)
$basliklar = @(@('Hoş geldin', 'Asorti Aracı kurulumu'), @('Kontroller', 'Bu bilgisayarda gerekenler var mı?'), @('Ayarlar', 'Nereye kurulsun, OTOPASTAL nerede?'), @('Kuruluyor', 'Adım adım kuruluyor…'), @('Bitti', 'Kurulum tamamlandı'))
$script:sira = 0; $script:kuruldu = $false; $script:otoKomut = ''

# ---------- kontroller ----------
$script:zorunluTamam = $false
function Kontrol {
  $liste.Items.Clear(); $hata = 0
  function Satir($ok, $ad, $sonuc, $zorunlu) {
    $i = New-Object Windows.Forms.ListViewItem($(if ($ok) { '✔' } elseif ($zorunlu) { '✖' } else { '!' }))
    [void]$i.SubItems.Add($ad); [void]$i.SubItems.Add($sonuc)
    $i.ForeColor = $(if ($ok) { [Drawing.Color]::ForestGreen } elseif ($zorunlu) { [Drawing.Color]::Firebrick } else { [Drawing.Color]::DarkOrange })
    [void]$liste.Items.Add($i); if (-not $ok -and $zorunlu) { $script:hataSay++ }
  }
  $script:hataSay = 0
  Satir ($PSVersionTable.PSVersion.Major -ge 5) 'PowerShell' ("sürüm " + $PSVersionTable.PSVersion) $true
  if (-not (Test-Path $KAYNAK)) { Satir $false 'Paket dosyaları' "AsortiAraci klasörü bulunamadı ($KAYNAK)" $true }
  $tb = TarayiciBul; Satir ([bool]$tb) 'Edge / Chrome' $(if ($tb) { $tb } else { 'bulunamadı (uygulama penceresi için gerekli)' }) $true
  if (-not $tAM.Text) { $tAM.Text = AccuMarkBul }
  if (-not $script:ilkKontrol) { $script:ilkKontrol = $true; if (-not $tAM.Text -and -not (Test-Path 'C:\userroot\storage')) { $script:sessiz = $true; $cSadece.Checked = $true; $script:sessiz = $false } }
  $g = -not $cSadece.Checked
  $am = $tAM.Text; $eksik = @('csvimprt.exe', 'amsubmit.exe', 'batch.exe', 'amdelete.exe') | Where-Object { -not ($am -and (Test-Path (Join-Path $am $_))) }
  Satir ($am -and -not $eksik) 'AccuMark' $(if (-not $am) { $(if ($g) { 'bulunamadı, Gözat ile seç' } else { 'yok (sadece asorti kurulacak)' }) } elseif ($eksik) { 'eksik: ' + ($eksik -join ', ') } else { $am }) $g
  $ur = 'C:\userroot'; Satir (Test-Path (Join-Path $ur 'storage')) 'Gerber müşteri klasörleri' $(if (Test-Path (Join-Path $ur 'storage')) { (Join-Path $ur 'storage') + ' · ' + @(Get-ChildItem (Join-Path $ur 'storage') -Directory -ErrorAction SilentlyContinue).Count + ' klasör' } else { "$ur\storage bulunamadı" }) $g
  if ($g) {
  $ku = $tKuyruk.Text; $kOk = $false; try { $kOk = Test-Path $ku } catch {}
  Satir $kOk 'OTOPASTAL kuyruğu' $(if ($kOk) { 'erişiliyor' } else { 'erişilemedi: OTOPASTAL açık mı, yol doğru mu? (Ayarlar sayfasında düzeltebilirsin)' }) $false
  $cp = CPaylasimi
  Satir ([bool]$cp) 'Bu bilgisayarın C: paylaşımı' $(if ($cp) { "\\$PC\$($cp.ad)" } else { 'yok: OTOPASTAL bu bilgisayarın pastallarına ulaşamaz' }) $false
  $bPay.Visible = -not $cp
  } else { $bPay.Visible = $false }
  $script:zorunluTamam = ($script:hataSay -eq 0)
  $lKontrol.Text = $(if ($script:zorunluTamam) { 'Gerekenler tamam. Turuncu (!) satırlar kurulumu engellemez ama Gerber''e gönderim için düzeltilmeleri gerekir.' } else { 'Kırmızı (✖) satırlar düzelmeden kurulum yapılamaz.' })
  $bIleri.Enabled = $script:zorunluTamam
}
$bYenile.Add_Click({ Kontrol })
$cSadece.Add_CheckedChanged({ if (-not $script:sessiz) { Kontrol } })
$bAM.Add_Click({ $d = New-Object Windows.Forms.FolderBrowserDialog; $d.Description = 'AccuMark program klasörünü seç (içinde csvimprt.exe olan)'; if ($d.ShowDialog() -eq 'OK') { $tAM.Text = $d.SelectedPath; Kontrol } })
$bPay.Add_Click({
  try {
    $herkes = (New-Object Security.Principal.SecurityIdentifier('S-1-1-0')).Translate([Security.Principal.NTAccount]).Value
    $p = Start-Process -FilePath 'cmd.exe' -Verb RunAs -Wait -PassThru -ArgumentList "/c net share C=C:\ /GRANT:`"$herkes`",FULL"
    Kontrol
  } catch { [Windows.Forms.MessageBox]::Show('Paylaşım oluşturulamadı: ' + $_.Exception.Message, 'Asorti Aracı') | Out-Null }
})

# ---------- kurulum ----------
function Adim($s) { [void]$adimlar.Items.Add($s); $adimlar.TopIndex = [Math]::Max(0, $adimlar.Items.Count - 1); Not $s; [Windows.Forms.Application]::DoEvents() }
function Kur {
  $hedef = $tHedef.Text.TrimEnd('\'); $harf = "$($cHarf.SelectedItem)"; $port = [int]$tPort.Text
  $ilerleme.Maximum = 9; $ilerleme.Value = 0
  try {
    Adim '1/9  Açık Asorti Aracı süreçleri kapatılıyor'
    foreach ($p in UygulamaSurecleri) { try { Stop-Process -Id $p.ProcessId -Force } catch {} }
    Start-Sleep -Milliseconds 800
    $ilerleme.Value = 1

    Adim "2/9  Dosyalar kopyalanıyor → $hedef"
    New-Item -ItemType Directory -Force -Path $hedef | Out-Null
    Copy-Item -Path (Join-Path $KAYNAK '*') -Destination $hedef -Recurse -Force
    foreach ($d in 'gelen', 'isleniyor', 'bitti', 'sonuc', 'log', 'iptal') { New-Item -ItemType Directory -Force -Path (Join-Path $hedef "kopru\$d") | Out-Null }
    $ilerleme.Value = 2

    Adim '3/9  Ayarlar yazılıyor (ayarlar.json)'
    $gerber = -not $cSadece.Checked
    $ayar = [ordered]@{ port = $port; accumark = $tAM.Text; userroot = 'C:\userroot'; kuyruk = $tKuyruk.Text; surucu = ($harf.ToLowerInvariant() + ':'); tarayici = ''; gerber = $gerber }
    ($ayar | ConvertTo-Json) | Set-Content -Path (Join-Path $hedef 'ayarlar.json') -Encoding UTF8
    $ilerleme.Value = 3

    if (-not $gerber) { Adim '4/9  Gerber yok: sürücü bağlantısı atlandı (sadece asorti)' } else {
    Adim "4/9  $($harf): sürücüsü kontrol ediliyor"
    $cp = CPaylasimi; $pay = "\\$PC\" + $(if ($cp) { $cp.ad } else { 'C' })
    $b = SurucuBaglantisi $harf
    if (-not $b.var) { $o = (cmd /c "net use $($harf): $pay /persistent:yes 2>&1" | Out-String).Trim(); Adim "     $($harf): → $pay  ($o)" }
    elseif ($b.yol -and $b.yol.ToUpperInvariant() -eq $pay.ToUpperInvariant()) { Adim "     $($harf): zaten $pay" }
    else { Adim "     UYARI: $($harf): başka bir yere bağlı ($($b.yol)); dokunulmadı" }
    $script:otoKomut = "net use $($harf): $pay /persistent:yes"
    "@echo off`r`nrem Bu dosyayi OTOPASTAL bilgisayarinda calistir (bir kere).`r`n$($script:otoKomut)`r`npause`r`n" | Set-Content -Path (Join-Path $hedef 'OTOPASTAL_icin_baglanti.bat') -Encoding ASCII
    }
    $ilerleme.Value = 4

    Adim '5/9  Eski kurulum ayarları taşınıyor'
    $eskiProfil = Join-Path $ESKI 'uygulama\profil'; $yeniProfil = Join-Path $hedef 'profil'
    if ((Test-Path $eskiProfil) -and -not (Test-Path $yeniProfil)) { Copy-Item -Path $eskiProfil -Destination $yeniProfil -Recurse -Force -ErrorAction SilentlyContinue; Adim '     çalışma sayfaları ve ayarlar eski kurulumdan alındı' }
    $eskiK = Join-Path $ESKI 'kopru'
    foreach ($d in 'isleniyor', 'sonuc') { if (Test-Path (Join-Path $eskiK $d)) { Copy-Item -Path (Join-Path $eskiK "$d\*") -Destination (Join-Path $hedef "kopru\$d") -Force -ErrorAction SilentlyContinue } }
    $ilerleme.Value = 5

    Adim '6/9  Kısayollar oluşturuluyor'
    $w = New-Object -ComObject WScript.Shell
    $vbs = Join-Path $hedef 'sistem\baslat.vbs'; $ico = Join-Path $hedef 'sistem\asorti.ico'
    $masa = @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:USERPROFILE 'Desktop')); if ($env:OneDrive) { $masa += (Join-Path $env:OneDrive 'Desktop') }
    foreach ($m in ($masa | Select-Object -Unique)) { $l = Join-Path $m 'Asorti Araci.lnk'; if (Test-Path $l) { Remove-Item -Force $l -ErrorAction SilentlyContinue } }
    $yerler = @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'))
    foreach ($y in $yerler) {
      if (-not (Test-Path $y)) { continue }
      $k = $w.CreateShortcut((Join-Path $y 'Asorti Araci.lnk')); $k.TargetPath = "$env:WINDIR\System32\wscript.exe"; $k.Arguments = "`"$vbs`""
      $k.WorkingDirectory = $hedef; $k.IconLocation = "$ico,0"; $k.Description = 'Asorti Aracı'; $k.Save(); Adim "     $y"
    }
    $k = $w.CreateShortcut((Join-Path $hedef 'Asorti Araci.lnk')); $k.TargetPath = "$env:WINDIR\System32\wscript.exe"; $k.Arguments = "`"$vbs`""; $k.WorkingDirectory = $hedef; $k.IconLocation = "$ico,0"; $k.Save()
    $ilerleme.Value = 6

    Adim '7/9  Eski otomatik başlatma kaldırılıyor'
    $S = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\asorti_gerber_kopru.bat'
    if (Test-Path $S) { Remove-Item -Force $S; Adim '     kaldırıldı' } else { Adim '     yoktu' }
    $ilerleme.Value = 7

    Adim '8/9  Eski deneme dosyaları'
    if ($cTemiz.Checked -and (Test-Path $ESKI) -and ($hedef.ToUpperInvariant() -ne $ESKI.ToUpperInvariant())) {
      $sil = @('asorti_araci.html', 'uygulama.html', 'uygulama', 'kopru', 'test', 'k_baglan.bat', 'z_baglan.bat', 'z_kontrol.bat', 'z_log.txt', 'kuyruk_ayari.reg', 'Asorti Araci.lnk') + @(Get-ChildItem $ESKI -Filter 'k_log_*.txt' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
      foreach ($x in $sil) { $p = Join-Path $ESKI $x; if (Test-Path $p) { try { Remove-Item -Recurse -Force $p; Adim "     silindi: $p" } catch { Adim "     silinemedi: $p" } } }
    } else { Adim '     atlandı' }
    $ilerleme.Value = 8

    Adim '9/9  Kaldırma dosyası yazılıyor'
    $kal = @'
# Asorti Araci'ni kaldirir
$hedef = Split-Path -Parent $MyInvocation.MyCommand.Path
Add-Type -AssemblyName System.Windows.Forms
if ([Windows.Forms.MessageBox]::Show("Asorti Araci kaldirilsin mi?`r`n$hedef klasoru ve kisayollar silinecek (Excel dosyalarina dokunulmaz).", 'Asorti Araci', 'YesNo', 'Question') -ne 'Yes') { exit }
Get-CimInstance Win32_Process | Where-Object { ($_.Name -eq 'powershell.exe' -and $_.CommandLine -match '(sunucu|kopru)\.ps1') -or ($_.Name -match '^(msedge|chrome)\.exe$' -and $_.CommandLine -match 'AsortiAraci\\profil') } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force } catch {} }
foreach ($y in @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'))) { $l = Join-Path $y 'Asorti Araci.lnk'; if (Test-Path $l) { Remove-Item -Force $l } }
Start-Process cmd.exe -WindowStyle Hidden -ArgumentList "/c timeout /t 2 >nul & rmdir /s /q `"$hedef`""
'@
    $kal | Set-Content -Path (Join-Path $hedef 'sistem\kaldir.ps1') -Encoding UTF8
    "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0sistem\kaldir.ps1`"`r`n" | Set-Content -Path (Join-Path $hedef 'Kaldir.bat') -Encoding ASCII
    $ilerleme.Value = 9
    Adim 'Kurulum tamamlandı.'
    $script:kuruldu = $true
  } catch {
    Adim ('HATA: ' + $_.Exception.Message)
    [Windows.Forms.MessageBox]::Show("Kurulum yarıda kaldı:`r`n" + $_.Exception.Message, 'Asorti Aracı') | Out-Null
  }
  try { $script:logSatir | Set-Content -Path (Join-Path $hedef 'kurulum_log.txt') -Encoding UTF8 } catch {}
  $metin = "Asorti Aracı $hedef klasörüne kuruldu.`r`n`r`n" +
    "Açmak için masaüstündeki 'Asorti Araci' simgesine çift tıkla.`r`n`r`n"
  $bOtoKopya.Visible = [bool]$script:otoKomut
  if (-not $script:otoKomut) { $metin += "Bu bilgisayara sadece asorti kuruldu: asorti hesabı, Excel'e kaydetme ve yazdırma çalışır.`r`nGerber kurulursa Kurulum.bat'ı yeniden çalıştırıp kutunun işaretini kaldırman yeterli.`r`n`r`nKaldırmak istersen kurulum klasöründeki Kaldir.bat'ı çalıştır." }
  else { $metin += "OTOPASTAL'da yapılacak tek şey (bu bilgisayar ilk kez kuruluyorsa):`r`n" +
    "OTOPASTAL bu bilgisayarın C: diskini $($harf): harfiyle görmeli. OTOPASTAL'da bir kere`r`n" +
    "komut satırına şunu yaz (ya da kurulum klasöründeki OTOPASTAL_icin_baglanti.bat'ı orada çalıştır):`r`n`r`n" +
    "     $($script:otoKomut)`r`n`r`n" +
    "Bu bağlantı zaten varsa (eski kurulumdan) bir şey yapmana gerek yok.`r`n" +
    "Kaldırmak istersen kurulum klasöründeki Kaldir.bat'ı çalıştır." }
  $lBitti.Text = $metin
}
$bOtoKopya.Add_Click({ if ($script:otoKomut) { [Windows.Forms.Clipboard]::SetText($script:otoKomut); $bOtoKopya.Text = 'Kopyalandı ✔' } })

# ---------- gezinme ----------
function Goster {
  $orta.Controls.Clear(); $orta.Controls.Add($sayfalar[$script:sira])
  $baslik.Text = $basliklar[$script:sira][0]; $altBaslik.Text = $basliklar[$script:sira][1]
  $bGeri.Enabled = ($script:sira -in 1, 2); $bIleri.Enabled = $true; $bIptal.Enabled = ($script:sira -lt 3)
  $bIleri.Text = $(if ($script:sira -eq 2) { 'Kur' } elseif ($script:sira -eq 4) { 'Bitir' } else { 'İleri >' })
  if ($script:sira -eq 1) { Kontrol }
  if ($script:sira -eq 2) { GerberAlanlari; HarfBilgi }
  if ($script:sira -eq 3) { $bIleri.Enabled = $false; $bGeri.Enabled = $false; $F.Refresh(); Kur; $script:sira = 4; Goster }
}
$bIleri.Add_Click({
  if ($script:sira -eq 2) {
    if (-not $tHedef.Text) { [Windows.Forms.MessageBox]::Show('Kurulum klasörünü yaz.', 'Asorti Aracı') | Out-Null; return }
    $pn = 0; if (-not [int]::TryParse($tPort.Text, [ref]$pn) -or $pn -lt 1024 -or $pn -gt 65535) { [Windows.Forms.MessageBox]::Show('Bağlantı noktası 1024 ile 65535 arasında bir sayı olmalı (8642 bırakabilirsin).', 'Asorti Aracı') | Out-Null; return }
    $b = SurucuBaglantisi $cHarf.SelectedItem; $pay = "\\$PC\" + $(if (CPaylasimi) { (CPaylasimi).ad } else { 'C' })
    if (-not $cSadece.Checked -and $b.var -and -not ($b.yol -and $b.yol.ToUpperInvariant() -eq $pay.ToUpperInvariant())) { [Windows.Forms.MessageBox]::Show("$($cHarf.SelectedItem): harfi başka bir yere bağlı. Başka bir harf seç.", 'Asorti Aracı') | Out-Null; return }
  }
  if ($script:sira -eq 4) {
    if ($cAc.Checked -and $script:kuruldu) { Start-Process -FilePath "$env:WINDIR\System32\wscript.exe" -ArgumentList ('"' + (Join-Path $tHedef.Text.TrimEnd('\') 'sistem\baslat.vbs') + '"') }
    $F.Close(); return
  }
  $script:sira++; Goster
})
$bGeri.Add_Click({ if ($script:sira -gt 0) { $script:sira--; Goster } })
$bIptal.Add_Click({ $F.Close() })
Goster
[void]$F.ShowDialog()
