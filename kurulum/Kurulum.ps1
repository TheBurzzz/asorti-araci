# Asorti Aracı - kurulum sihirbazı
# Paket yapısı:  Kurulum.bat | kurulum\Kurulum.ps1 | AsortiAraci\ (uygulama dosyaları)
# Bilgisayarı kendisi tarar (AccuMark, müşteri klasörleri, OTOPASTAL, sürücü harfi) ve ona göre kurar; soru sormaz.
# İsteyen "Ayarları elle değiştir" ile bulunanları değiştirebilir.
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
$VARSAYILAN_HEDEF = 'C:\AsortiAraci'

# ---------- yardımcılar ----------
$script:logSatir = New-Object System.Collections.ArrayList
function Not($s) { [void]$script:logSatir.Add((Get-Date -Format 'HH:mm:ss') + ' ' + $s) }
function SurucuBaglantisi($harf) {
  $h = "$harf".TrimEnd(':').ToUpperInvariant() + ':'
  try { $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$h'" -ErrorAction Stop; if ($d) { return [pscustomobject]@{ var = $true; yol = "$($d.ProviderName)"; tip = [int]$d.DriveType } } } catch {}
  # bağlantısı kopuk (Kullanılamıyor) ağ sürücüleri yukarıda görünmez; net use listesine de bak
  foreach ($s in @(cmd /c 'net use 2>nul')) { if ($s -match ('\s' + [regex]::Escape($h) + '\s+(\\\\\S+)')) { return [pscustomobject]@{ var = $true; yol = $matches[1]; tip = 4 } } }
  return [pscustomobject]@{ var = $false; yol = ''; tip = 0 }
}
function TarayiciBul {
  @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
}
function UygulamaSurecleri {
  @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    ($_.Name -eq 'powershell.exe' -and $_.CommandLine -match '(sunucu|kopru)\.ps1') -or
    ($_.Name -match '^(AsortiAraci|AsortiAcilis)\.exe$') -or
    ($_.Name -match '^(msedge|chrome|msedgewebview2)\.exe$' -and $_.CommandLine -match '(AccuNest\\uygulama|AsortiAraci)\\profil') })
}
function PortBos([int]$p) { try { $l = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $p); $l.Start(); $l.Stop(); return $true } catch { return $false } }
function UncBilgisayar([string]$y) { if ($y -match '^\\\\([^\\]+)\\') { return $matches[1] }; return '' }
# OTOPASTAL bilgisayarında bir kere çalıştırılacak bağlantı dosyası: sürücüyü bağlar, her oturum açılışında kendiliğinden yeniler.
# Bağlantı zaten çalışıyorsa hiçbir şeye dokunmaz; harf başka bir yere bağlıysa onu bozmaz.
function BaglantiDosyasi([string]$harf, [string]$hedef, [string]$dosyaAdi) {
  $h = $harf.TrimEnd(':').ToUpperInvariant() + ':'
  return @"
@echo off
rem Asorti Araci: OTOPASTAL, $PC bilgisayarindaki pastallara $h surucusuyle ulasir.
rem Bir kere cift tikla. Baglanti her oturum acilisinda kendiliginden yenilenir (Baslangic klasorune kopyalanir).
setlocal
set "HARF=$h"
set "YOL=$hedef"
set "AD=$dosyaAdi"
set "BAS=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\"
if exist "%HARF%\userroot\storage\" goto tamam
if not exist "%YOL%\userroot\storage\" goto ulasilamadi
net use %HARF% 2>nul | find /i "%YOL%" >nul
if not errorlevel 1 goto yenile
net use %HARF% >nul 2>&1
if not errorlevel 1 goto dolu
net use %HARF% "%YOL%" /persistent:yes >nul 2>&1
goto kontrol
:yenile
net use %HARF% /delete /y >nul 2>&1
net use %HARF% "%YOL%" /persistent:yes >nul 2>&1
:kontrol
if exist "%HARF%\userroot\storage\" goto tamam
echo SORUN: %HARF% surucusu %YOL% adresine baglanamadi.
goto son
:ulasilamadi
echo SORUN: %YOL% adresine ulasilamiyor. $PC acik mi, C: diski paylasilmis mi?
goto son
:dolu
echo SORUN: %HARF% harfi baska bir yere bagli, dokunulmadi. Asorti Araci kurulumunda baska bir harf sec.
goto son
:tamam
echo TAMAM: %HARF% = %YOL%
:son
if /i not "%~dp0"=="%BAS%" (
  copy /y "%~f0" "%BAS%%AD%" >nul 2>&1
  echo.
  echo Bu dosya her oturum acilisinda kendiliginden calisacak. Kapatmak icin bir tusa bas.
  pause >nul
)
endlocal
"@ -replace "`r?`n", "`r`n"   # cmd, satırları LF ile biten .bat dosyalarında goto etiketlerini bulamayabilir: CRLF yap
}
# bağlantı dosyasını OTOPASTAL'ın masaüstüne (olmazsa Ortak Belgeler'e) koymayı dener
function SunucuyaKoy([string]$pc, [string]$ad, [string]$icerik) {
  if (-not $pc) { return '' }
  foreach ($k in "\\$pc\Users\Public\Desktop", "\\$pc\Users\Public\Documents", "\\$pc\Public\Desktop", "\\$pc\Public\Documents") {
    try {
      if (-not (Test-Path -LiteralPath $k)) { continue }
      $f = Join-Path $k $ad
      [IO.File]::WriteAllText($f, $icerik, [Text.Encoding]::ASCII)
      if (Test-Path -LiteralPath $f) { return $f }
    } catch {}
  }
  return ''
}

# eski kurulumdan bilinen değerleri al
$eskiAyar = $null
if (Test-Path (Join-Path $VARSAYILAN_HEDEF 'ayarlar.json')) { try { $eskiAyar = Get-Content (Join-Path $VARSAYILAN_HEDEF 'ayarlar.json') -Raw -Encoding UTF8 | ConvertFrom-Json } catch {} }

# ---------- pencere ----------
$F = New-Object Windows.Forms.Form
$F.Text = 'Asorti Aracı - Kurulum'; $F.Size = New-Object Drawing.Size(720, 540); $F.StartPosition = 'CenterScreen'
$F.FormBorderStyle = 'FixedDialog'; $F.MaximizeBox = $false; $F.Font = New-Object Drawing.Font('Segoe UI', 9.5)
$ikon = Join-Path $KAYNAK 'sistem\asorti.ico'; if (Test-Path $ikon) { $F.Icon = New-Object Drawing.Icon($ikon) }

$ust = New-Object Windows.Forms.Panel; $ust.Dock = 'Top'; $ust.Height = 64; $ust.BackColor = [Drawing.Color]::FromArgb(47, 124, 246)
$baslik = New-Object Windows.Forms.Label; $baslik.ForeColor = 'White'; $baslik.Font = New-Object Drawing.Font('Segoe UI', 14, [Drawing.FontStyle]::Bold)
$baslik.Location = New-Object Drawing.Point(20, 8); $baslik.AutoSize = $true; $ust.Controls.Add($baslik)
$altBaslik = New-Object Windows.Forms.Label; $altBaslik.ForeColor = [Drawing.Color]::FromArgb(225, 235, 255); $altBaslik.Location = New-Object Drawing.Point(22, 38); $altBaslik.AutoSize = $true; $ust.Controls.Add($altBaslik)

$alt = New-Object Windows.Forms.Panel; $alt.Dock = 'Bottom'; $alt.Height = 54
$bGeri = New-Object Windows.Forms.Button; $bGeri.Text = '< Geri'; $bGeri.Size = New-Object Drawing.Size(100, 32); $bGeri.Location = New-Object Drawing.Point(378, 11)
$bIleri = New-Object Windows.Forms.Button; $bIleri.Text = 'İleri >'; $bIleri.Size = New-Object Drawing.Size(110, 32); $bIleri.Location = New-Object Drawing.Point(484, 11)
$bIptal = New-Object Windows.Forms.Button; $bIptal.Text = 'İptal'; $bIptal.Size = New-Object Drawing.Size(90, 32); $bIptal.Location = New-Object Drawing.Point(602, 11)
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
  "Ayarları kendisi bulur: Gerber AccuMark nerede, müşteri klasörleri nerede, OTOPASTAL`r`n" +
  "bu bilgisayarda mı başka bir bilgisayarda mı, OTOPASTAL pastallara hangi harfle ulaşıyor.`r`n" +
  "Gerber yoksa sadece asorti kurulur.`r`n`r`n" +
  "Devam etmeden önce açık bir Asorti Aracı penceresi varsa kapat.") 0 0 660 320))

# ---- sayfa 2: tarama ve özet ----
$s2 = New-Object Windows.Forms.Panel; $s2.Dock = 'Fill'
$lTara = Yazi 'Bu bilgisayar inceleniyor…' 0 0 560 20; $s2.Controls.Add($lTara)
$pTara = New-Object Windows.Forms.ProgressBar; $pTara.Location = New-Object Drawing.Point(0, 22); $pTara.Size = New-Object Drawing.Size(660, 10); $pTara.Style = 'Marquee'; $pTara.MarqueeAnimationSpeed = 30; $s2.Controls.Add($pTara)
$liste = New-Object Windows.Forms.ListView; $liste.View = 'Details'; $liste.FullRowSelect = $true; $liste.HeaderStyle = 'Nonclickable'
$liste.Location = New-Object Drawing.Point(0, 40); $liste.Size = New-Object Drawing.Size(660, 216)
[void]$liste.Columns.Add('', 30); [void]$liste.Columns.Add('Ne', 150); [void]$liste.Columns.Add('Bulunan', 460)
$s2.Controls.Add($liste)
$lMod = Yazi '' 0 262 660 22; $lMod.Font = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold); $s2.Controls.Add($lMod)
$lKontrol = Yazi '' 0 286 660 36; $lKontrol.ForeColor = [Drawing.Color]::DimGray; $s2.Controls.Add($lKontrol)
$cSadece = New-Object Windows.Forms.CheckBox; $cSadece.Text = 'Sadece asorti kur (Gerber''e gönderme kapalı olur)'; $cSadece.Location = New-Object Drawing.Point(0, 324); $cSadece.Size = New-Object Drawing.Size(400, 24); $s2.Controls.Add($cSadece)
$bTekrar = New-Object Windows.Forms.Button; $bTekrar.Text = 'Tekrar ara'; $bTekrar.Location = New-Object Drawing.Point(410, 322); $bTekrar.Size = New-Object Drawing.Size(100, 28); $s2.Controls.Add($bTekrar)
$bElle = New-Object Windows.Forms.Button; $bElle.Text = 'Ayarları elle değiştir…'; $bElle.Location = New-Object Drawing.Point(516, 322); $bElle.Size = New-Object Drawing.Size(144, 28); $s2.Controls.Add($bElle)

# ---- sayfa 3: ayarlar (isteyene) ----
$s3 = New-Object Windows.Forms.Panel; $s3.Dock = 'Fill'
$s3.Controls.Add((Yazi 'Kurulum klasörü' 0 0 300 18)); $tHedef = Kutu $VARSAYILAN_HEDEF 0 19 560; $s3.Controls.Add($tHedef)
$s3.Controls.Add((Yazi 'AccuMark program klasörü (içinde csvimprt.exe olan)' 0 50 400 18)); $tAM = Kutu '' 0 69 560; $s3.Controls.Add($tAM)
$bAM = New-Object Windows.Forms.Button; $bAM.Text = 'Gözat…'; $bAM.Location = New-Object Drawing.Point(568, 67); $bAM.Size = New-Object Drawing.Size(88, 26); $s3.Controls.Add($bAM)
$s3.Controls.Add((Yazi 'OTOPASTAL kuyruk dosyası (ultramrk.umq) · boş bırakılırsa OTOPASTAL yok sayılır' 0 100 640 18)); $tKuyruk = Kutu '' 0 119 560; $s3.Controls.Add($tKuyruk)
$bKu = New-Object Windows.Forms.Button; $bKu.Text = 'Gözat…'; $bKu.Location = New-Object Drawing.Point(568, 117); $bKu.Size = New-Object Drawing.Size(88, 26); $s3.Controls.Add($bKu)
$s3.Controls.Add((Yazi 'OTOPASTAL bu bilgisayarın pastallarını hangi sürücü harfiyle görüyor' 0 150 640 18))
$cHarf = New-Object Windows.Forms.ComboBox; $cHarf.DropDownStyle = 'DropDownList'; $cHarf.Location = New-Object Drawing.Point(0, 169); $cHarf.Width = 70
foreach ($h in 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') { [void]$cHarf.Items.Add($h) }; $cHarf.SelectedItem = 'K'; $s3.Controls.Add($cHarf)
$lHarf = Yazi '' 80 172 576 34; $lHarf.ForeColor = [Drawing.Color]::DimGray; $s3.Controls.Add($lHarf)
$s3.Controls.Add((Yazi 'Uygulama bağlantı noktası (değiştirmen gerekmez)' 0 210 400 18)); $tPort = Kutu '8642' 0 229 80; $s3.Controls.Add($tPort)
$cTemiz = New-Object Windows.Forms.CheckBox; $cTemiz.Text = "Eski deneme dosyalarını temizle ($ESKI içindeki Asorti Aracı dosyaları; QueueSubmit dosyalarına dokunulmaz)"
$cTemiz.Location = New-Object Drawing.Point(0, 262); $cTemiz.Size = New-Object Drawing.Size(660, 40); $cTemiz.Checked = (Test-Path (Join-Path $ESKI 'kopru')); $cTemiz.Visible = (Test-Path (Join-Path $ESKI 'kopru')); $s3.Controls.Add($cTemiz)

# ---- sayfa 4: kurulum ----
$s4 = New-Object Windows.Forms.Panel; $s4.Dock = 'Fill'
$ilerleme = New-Object Windows.Forms.ProgressBar; $ilerleme.Location = New-Object Drawing.Point(0, 4); $ilerleme.Size = New-Object Drawing.Size(660, 22); $s4.Controls.Add($ilerleme)
$adimlar = New-Object Windows.Forms.ListBox; $adimlar.Location = New-Object Drawing.Point(0, 36); $adimlar.Size = New-Object Drawing.Size(660, 300); $adimlar.HorizontalScrollbar = $true; $s4.Controls.Add($adimlar)

# ---- sayfa 5: bitti ----
$s5 = New-Object Windows.Forms.Panel; $s5.Dock = 'Fill'
$lBitti = Yazi '' 0 0 660 270; $s5.Controls.Add($lBitti)
$bOtoKopya = New-Object Windows.Forms.Button; $bOtoKopya.Text = 'OTOPASTAL komutunu kopyala'; $bOtoKopya.Location = New-Object Drawing.Point(0, 276); $bOtoKopya.Size = New-Object Drawing.Size(230, 30); $s5.Controls.Add($bOtoKopya)
$cAc = New-Object Windows.Forms.CheckBox; $cAc.Text = "Asorti Aracı'nı şimdi aç"; $cAc.Checked = $true; $cAc.Location = New-Object Drawing.Point(0, 318); $cAc.AutoSize = $true; $s5.Controls.Add($cAc)

$sayfalar = @($s1, $s2, $s3, $s4, $s5)
$basliklar = @(@('Hoş geldin', 'Asorti Aracı kurulumu'), @('Bu bilgisayar', 'Gerber ve OTOPASTAL kendiliğinden bulunuyor'), @('Ayarlar', 'Bulunanları değiştirmek istersen'), @('Kuruluyor', 'Adım adım kuruluyor…'), @('Bitti', 'Kurulum tamamlandı'))
$script:sira = 0; $script:kuruldu = $false; $script:otoKomut = ''; $script:elle = $false

# ---------- tarama (ayrı süreçte; pencere donmasın) ----------
$script:rapor = $null; $script:taraP = $null; $script:taraDosya = ''; $script:taraBas = Get-Date; $script:zorunluTamam = $false
$tm = New-Object Windows.Forms.Timer; $tm.Interval = 500
function TaramaBaslat {
  $liste.Items.Clear(); $lMod.Text = ''; $lKontrol.Text = ''; $bIleri.Enabled = $false; $bTekrar.Enabled = $false; $bElle.Enabled = $false
  $pTara.Visible = $true; $lTara.Text = 'Bu bilgisayar inceleniyor… (AccuMark, müşteri klasörleri, OTOPASTAL)'
  $script:rapor = $null; $script:taraBas = Get-Date
  $script:taraDosya = Join-Path ([IO.Path]::GetTempPath()) ('asorti_tara_' + [guid]::NewGuid().ToString('N') + '.json')
  $arg = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $KAYNAK 'sistem\tara.ps1') + '"'), '-Cikti', ('"' + $script:taraDosya + '"'))
  if (Test-Path (Join-Path $VARSAYILAN_HEDEF 'ayarlar.json')) { $arg += @('-AyarKok', ('"' + $VARSAYILAN_HEDEF + '"')) }
  try { $script:taraP = Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -PassThru -ArgumentList $arg; $tm.Start() }
  catch { $script:taraP = $null; TaramaBitti }
}
$tm.Add_Tick({
  $sn = [int]((Get-Date) - $script:taraBas).TotalSeconds
  $lTara.Text = "Bu bilgisayar ve ağ inceleniyor… $sn sn"
  if ($script:taraP -and -not $script:taraP.HasExited -and $sn -lt 90) { return }
  $tm.Stop()
  if ($script:taraP -and -not $script:taraP.HasExited) { try { $script:taraP.Kill() } catch {} }
  TaramaBitti
})
function TaramaBitti {
  $pTara.Visible = $false
  if ($script:taraDosya -and (Test-Path $script:taraDosya)) { try { $script:rapor = Get-Content $script:taraDosya -Raw -Encoding UTF8 | ConvertFrom-Json } catch {} ; Remove-Item -Force $script:taraDosya -ErrorAction SilentlyContinue }
  $r = $script:rapor
  if ($r -and -not $r.hata) {
    $lTara.Text = 'İnceleme bitti (' + [math]::Round($r.sure_ms / 1000) + ' sn). Bulunanlar:'
    # bulunanları elle değiştirme sayfasına da yaz
    $tAM.Text = "$($r.oneri.accumark)"; $tKuyruk.Text = "$($r.oneri.kuyruk)"
    $h = "$($r.oneri.surucu)".TrimEnd(':').ToUpperInvariant(); if ($cHarf.Items.Contains($h)) { $cHarf.SelectedItem = $h }
  } else {
    $lTara.Text = 'İnceleme tamamlanamadı' + $(if ($r -and $r.hata) { ': ' + $r.hata } else { '' }) + '. Ayarları elle girebilirsin.'
  }
  # tarama bulamadıysa ama eski kurulumdaki yer hâlâ çalışıyorsa onu koru (çalışan bir ayar boş bir bulguyla değişmesin)
  if ($eskiAyar) {
    if (-not $tAM.Text -and "$($eskiAyar.accumark)" -and (Test-Path -LiteralPath (Join-Path "$($eskiAyar.accumark)" 'csvimprt.exe'))) { $tAM.Text = "$($eskiAyar.accumark)" }
    if (-not $tKuyruk.Text -and "$($eskiAyar.kuyruk)") { $ok = $false; try { $ok = Test-Path -LiteralPath "$($eskiAyar.kuyruk)" } catch {}; if ($ok) { $tKuyruk.Text = "$($eskiAyar.kuyruk)" } }
  }
  if (-not $tAM.Text.Trim()) { $script:sessiz = $true; $cSadece.Checked = $true; $script:sessiz = $false }
  if ($eskiAyar -and $eskiAyar.port) { $tPort.Text = "$($eskiAyar.port)" }
  Ozet
  $bTekrar.Enabled = $true; $bElle.Enabled = $true
}

# ---------- özet ----------
function Satir($durum, $ad, $sonuc, $zorunlu) {
  $i = New-Object Windows.Forms.ListViewItem($(if ($durum -eq 'ok') { '✔' } elseif ($durum -eq 'hata') { '✖' } else { '!' }))
  [void]$i.SubItems.Add($ad); [void]$i.SubItems.Add($sonuc)
  $i.ForeColor = $(if ($durum -eq 'ok') { [Drawing.Color]::ForestGreen } elseif ($durum -eq 'hata') { [Drawing.Color]::Firebrick } else { [Drawing.Color]::DarkOrange })
  [void]$liste.Items.Add($i); if ($durum -eq 'hata' -and $zorunlu) { $script:hataSay++ }
}
# kurulacak ayarlar: tarama + (açıldıysa) elle değiştirilenler
function Secilen {
  $r = $script:rapor; $o = $(if ($r -and $r.oneri) { $r.oneri } else { $null })
  $ku = $tKuyruk.Text.Trim()
  $oto = 'yok'
  if ($ku) {
    if ($o -and $ku -ieq "$($o.kuyruk)") { $oto = "$($o.otopastal)" }
    elseif ($ku -match '^\\\\' -and (UncBilgisayar $ku).ToUpperInvariant() -notin @($PC.ToUpperInvariant(), 'LOCALHOST', '127.0.0.1')) { $oto = 'ayri' } else { $oto = 'ayni' }
    if ($oto -notin 'ayri', 'ayni') { $oto = 'ayri' }
  }
  $harf = ("$($cHarf.SelectedItem)".ToLowerInvariant() + ':')
  $yedek = $(if ($o -and "$($o.surucu2)" -and "$($o.surucu2)" -ne $harf) { "$($o.surucu2)" } elseif ($harf -ne 'z:') { 'z:' } else { 'k:' })
  return [ordered]@{
    gerber = (-not $cSadece.Checked) -and [bool]$tAM.Text.Trim()
    accumark = $tAM.Text.Trim()
    userroot = $(if ($o -and $o.userroot) { "$($o.userroot)" } else { 'C:\userroot' })
    depo = $(if ($o -and $o.depo) { "$($o.depo)" } else { '' })
    kuyruk = $ku; otopastal = $oto; surucu = $harf; surucu2 = $yedek
  }
}
function Ozet {
  $liste.Items.Clear(); $script:hataSay = 0
  $r = $script:rapor; $s = Secilen
  Satir $(if ($PSVersionTable.PSVersion.Major -ge 5) { 'ok' } else { 'hata' }) 'PowerShell' ("sürüm " + $PSVersionTable.PSVersion) $true
  if (-not (Test-Path $KAYNAK)) { Satir 'hata' 'Paket dosyaları' "AsortiAraci klasörü bulunamadı ($KAYNAK)" $true }
  $tb = TarayiciBul; Satir $(if ($tb) { 'ok' } else { 'hata' }) 'Edge / Chrome' $(if ($tb) { $tb } else { 'bulunamadı (uygulama penceresi için gerekli)' }) $true
  $am = $(if ($r) { $r.accumark } else { $null }); $ur = $(if ($r) { $r.userroot } else { $null })
  if ($s.accumark) { Satir 'ok' 'Gerber AccuMark' ($(if ($am -and $am.yol -ieq $s.accumark -and $am.surum) { "$($am.surum) · " } else { '' }) + $s.accumark) $false }
  else { Satir 'uyari' 'Gerber AccuMark' 'bulunamadı: sadece asorti kurulur (sonradan AccuMark kurulursa uygulamada ⚙ → Gerber bağlantısı → Otomatik bul)' $false }
  if ($s.gerber) {
    if ($ur -and $ur.alan) { Satir 'ok' 'Müşteri klasörleri' ("$($ur.depo)\storage · $($ur.alan) klasör") $false }
    else { Satir 'uyari' 'Müşteri klasörleri' 'bulunamadı ya da boş (Gerber''de müşteri klasörü açınca listede görünür)' $false }
    $nest = $(if ($r -and $r.otopastal_bilgisayari) { "$($r.otopastal_bilgisayari)" } else { UncBilgisayar $s.kuyruk })
    if ($s.otopastal -eq 'ayri') { Satir 'ok' 'OTOPASTAL' ("ayrı bilgisayarda: $nest · kuyruk $($s.kuyruk)") $false }
    elseif ($s.otopastal -eq 'ayni') { Satir 'ok' 'OTOPASTAL' ("bu bilgisayarda · kuyruk $($s.kuyruk)") $false }
    else { Satir 'uyari' 'OTOPASTAL' 'bulunamadı: pastallar Gerber''de oluşturulur, yerleştirmeyi Gerber''de elle yaparsın' $false }
    if ($s.otopastal -eq 'ayri') {
      $H = $s.surucu.ToUpperInvariant(); $ci = $(if ($r) { $r.cihaz } else { $null })
      $kanit = $ci -and $ci.harf -eq $s.surucu -and -not $ci.sunucuda_baglanti_gerekli
      if ($kanit) { Satir 'ok' 'Sürücü harfi' ("OTOPASTAL pastallara $H ile ulaşıyor ($($ci.kaynak)); orada bir şey yapmana gerek yok") $false }
      else { Satir 'uyari' 'Sürücü harfi' ("$H · OTOPASTAL'da bir kerelik bağlantı dosyası çalıştırılacak (kurulum hazırlar)") $false }
      $pa = $(if ($r) { $r.paylasim } else { $null })
      if ($ur -and $ur.tip -eq 4) { }
      elseif ($pa -and $pa.ad) { Satir 'ok' 'Paylaşım' ("\\$PC\$($pa.ad) (OTOPASTAL buradan ulaşır)") $false }
      else { Satir 'uyari' 'Paylaşım' ("bu bilgisayarın $(if ($ur) { $ur.harf } else { 'C' }): diski kurulumda paylaşılacak (yönetici izni sorulur)") $false }
    }
    if ($s.otopastal -eq 'ayni' -and $r -and $r.kuyruk_programi) {
      $kp = $r.kuyruk_programi
      if ($kp.calisiyor) { Satir 'ok' 'OTOPASTAL programı' 'açık' $false } elseif ($kp.exe) { Satir 'ok' 'OTOPASTAL programı' ("kapalıysa köprü açar: $($kp.exe)") $false } else { Satir 'uyari' 'OTOPASTAL programı' 'bulunamadı; pastal gönderirken açık olmalı' $false }
    }
  }
  $lMod.Text = 'Kurulacak: ' + $(if (-not $s.gerber) { 'Sadece asorti' } elseif ($s.otopastal -eq 'ayri') { 'Asorti + Gerber + OTOPASTAL (ayrı bilgisayarda)' } elseif ($s.otopastal -eq 'ayni') { 'Asorti + Gerber + OTOPASTAL (bu bilgisayarda)' } else { 'Asorti + Gerber (OTOPASTAL yok)' })
  $script:zorunluTamam = ($script:hataSay -eq 0)
  $lKontrol.Text = $(if (-not $script:zorunluTamam) { 'Kırmızı (✖) satırlar düzelmeden kurulum yapılamaz.' } elseif ($script:elle) { 'Elle değiştirdiğin ayarlar kullanılacak.' } else { 'Bir şey girmene gerek yok: Kur''a basınca bulunanlarla kurulur. Turuncu (!) satırlar kurulumda halledilir ya da bilgi içindir.' })
  $bIleri.Enabled = $script:zorunluTamam
  if ($script:taraP -and -not $script:taraP.HasExited) { $bIleri.Enabled = $false }   # tarama bitmeden kurma
}
$cSadece.Add_CheckedChanged({ if (-not $script:sessiz) { Ozet } })
$bTekrar.Add_Click({ TaramaBaslat })
$bElle.Add_Click({ $script:elle = $true; $script:sira = 2; Goster })
$bAM.Add_Click({ $d = New-Object Windows.Forms.FolderBrowserDialog; $d.Description = 'AccuMark program klasörünü seç (içinde csvimprt.exe olan)'; if ($d.ShowDialog() -eq 'OK') { $tAM.Text = $d.SelectedPath } })
$bKu.Add_Click({ $d = New-Object Windows.Forms.OpenFileDialog; $d.Filter = 'OTOPASTAL kuyruğu (*.umq)|*.umq|Bütün dosyalar|*.*'; $d.Title = 'OTOPASTAL kuyruk dosyasını seç (ultramrk.umq)'; if ($d.ShowDialog() -eq 'OK') { $tKuyruk.Text = $d.FileName } })
function HarfBilgi {
  $b = SurucuBaglantisi $cHarf.SelectedItem
  if (-not $tKuyruk.Text.Trim()) { $lHarf.Text = 'OTOPASTAL yokken kullanılmaz.'; $lHarf.ForeColor = [Drawing.Color]::DimGray; return }
  if (-not $b.var) { $lHarf.Text = "Bu bilgisayarda boş. Kurulum $($cHarf.SelectedItem): sürücüsünü kendi diskine bağlar; OTOPASTAL için bağlantı dosyası hazırlar."; $lHarf.ForeColor = [Drawing.Color]::DimGray }
  elseif ($b.tip -eq 3) { $lHarf.Text = "Bu bilgisayarın kendi diski. OTOPASTAL aynı bilgisayardaysa doğru harf budur."; $lHarf.ForeColor = [Drawing.Color]::DimGray }
  elseif ($b.yol -and (UncBilgisayar $b.yol).ToUpperInvariant() -eq $PC.ToUpperInvariant()) { $lHarf.Text = "Zaten $($b.yol) olarak bağlı. ✔"; $lHarf.ForeColor = [Drawing.Color]::ForestGreen }
  else { $lHarf.Text = "Bu bilgisayarda başka bir yere bağlı ($($b.yol)); kurulum ona dokunmaz. OTOPASTAL'da bu harf boşsa yine de kullanılabilir."; $lHarf.ForeColor = [Drawing.Color]::DarkOrange }
}
$cHarf.Add_SelectedIndexChanged({ HarfBilgi })
$tKuyruk.Add_TextChanged({ HarfBilgi })

# ---------- kurulum ----------
function Adim($s) { [void]$adimlar.Items.Add($s); $adimlar.TopIndex = [Math]::Max(0, $adimlar.Items.Count - 1); Not $s; [Windows.Forms.Application]::DoEvents() }
function Kur {
  $hedef = $tHedef.Text.TrimEnd('\'); $port = 8642; [void][int]::TryParse($tPort.Text, [ref]$port)
  $S = Secilen; $r = $script:rapor
  $ilerleme.Maximum = 10; $ilerleme.Value = 0
  $script:sonNot = New-Object System.Collections.ArrayList
  try {
    Adim '1/10  Açık Asorti Aracı süreçleri kapatılıyor'
    $uyg = @(Get-Process -Name AsortiAraci -ErrorAction SilentlyContinue)
    foreach ($p in $uyg) { try { [void]$p.CloseMainWindow() } catch {} }
    for ($i = 0; $i -lt 30 -and @($uyg | Where-Object { -not $_.HasExited }).Count; $i++) { Start-Sleep -Milliseconds 100 }
    foreach ($p in UygulamaSurecleri) { try { Stop-Process -Id $p.ProcessId -Force } catch {} }
    Start-Sleep -Milliseconds 800
    $ilerleme.Value = 1

    Adim "2/10  Dosyalar kopyalanıyor → $hedef"
    New-Item -ItemType Directory -Force -Path $hedef | Out-Null
    Copy-Item -Path (Join-Path $KAYNAK '*') -Destination $hedef -Recurse -Force
    foreach ($d in 'gelen', 'isleniyor', 'bitti', 'sonuc', 'log', 'iptal') { New-Item -ItemType Directory -Force -Path (Join-Path $hedef "kopru\$d") | Out-Null }
    # uygulamanin kendi penceresi (sistem\AsortiAraci.exe) bu bilgisayarin .NET Framework'uyle derlenir; olmazsa eski yoldan (Edge penceresiyle) acilir
    Adim '     uygulama penceresi hazırlanıyor (AsortiAraci.exe)'
    $exe = Join-Path $hedef 'sistem\AsortiAraci.exe'; $derlendi = $false
    try { . (Join-Path $hedef 'sistem\ortak.ps1'); $derlendi = [bool](UygulamaDerle $hedef) } catch { Not ('derleme: ' + $_.Exception.Message) }
    $exeVar = $derlendi -and (Test-Path -LiteralPath $exe)
    Adim $(if ($exeVar) { '     hazır' } else { '     hazırlanamadı; uygulama eski yoldan (Edge penceresiyle) açılacak (kopru\log\uygulama_derleme.txt)' })
    $ilerleme.Value = 2

    Adim '3/10  Bağlantı noktası'
    if (-not (PortBos $port)) {
      $yeni = 0; for ($q = $port + 1; $q -le $port + 60; $q++) { if (PortBos $q) { $yeni = $q; break } }
      if ($yeni) { Adim "     $port başka bir program tarafından kullanılıyor; $yeni seçildi"; $port = $yeni } else { Adim "     UYARI: $port kullanımda" }
    } else { Adim "     $port" }
    $ilerleme.Value = 3

    Adim '4/10  Ayarlar yazılıyor (ayarlar.json)'
    $ayar = [ordered]@{}
    $af = Join-Path $hedef 'ayarlar.json'
    if (Test-Path $af) { try { (Get-Content $af -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $ayar[$_.Name] = $_.Value } } catch {} }
    $ayar['port'] = $port
    foreach ($k in $S.Keys) { $ayar[$k] = $S[$k] }
    if (-not $ayar.Contains('tarayici')) { $ayar['tarayici'] = '' }
    [IO.File]::WriteAllText($af, ($ayar | ConvertTo-Json), (New-Object Text.UTF8Encoding($true)))
    Adim ('     ' + $(if (-not $S.gerber) { 'sadece asorti' } else { "Gerber: $($S.accumark) · OTOPASTAL: $($S.otopastal)" + $(if ($S.otopastal -ne 'yok') { " · $($S.surucu.ToUpperInvariant())" } else { '' }) }))
    if ($r) { try { ($r | ConvertTo-Json -Depth 7) | Set-Content -Path (Join-Path $hedef 'kopru\log\tarama_kurulum.json') -Encoding UTF8 } catch {} }
    $ilerleme.Value = 4

    Adim '5/10  OTOPASTAL bağlantısı'
    $depoUr = $(if ($S.depo) { $S.depo } else { $S.userroot }); $depoHarf = $depoUr.Substring(0, 1).ToUpperInvariant()
    $depoAg = $(if ($r -and $r.userroot -and $r.userroot.tip -eq 4) { $true } else { $false })
    if (-not $S.gerber -or $S.otopastal -ne 'ayri') { Adim '     gerekmiyor' + $(if ($S.otopastal -eq 'ayni') { ' (OTOPASTAL bu bilgisayarda)' } else { '' }) }
    elseif ($depoAg) { Adim "     müşteri klasörleri ağda ($depoUr): OTOPASTAL'da aynı harf ($($S.surucu.ToUpperInvariant())) bağlı olmalı" }
    else {
      # a) bu bilgisayarın diski paylaşılmış mı (OTOPASTAL pastallara buradan ulaşır)
      $pay = $(if ($r -and $r.paylasim -and $r.paylasim.ad) { "$($r.paylasim.ad)" } else { '' })
      if (-not $pay) {
        try { foreach ($sh in @(Get-CimInstance Win32_Share -ErrorAction Stop)) { if ("$($sh.Path)".TrimEnd('\').ToUpperInvariant() -eq "$($depoHarf):" -and $sh.Name -notmatch '\$$') { $pay = "$($sh.Name)"; break } } } catch {}
      }
      if (-not $pay) {
        Adim "     $($depoHarf): diski paylaşılıyor (yönetici izni sorulacak)"
        try {
          $herkes = (New-Object Security.Principal.SecurityIdentifier('S-1-1-0')).Translate([Security.Principal.NTAccount]).Value
          # yönetici olarak çalışacak küçük betik: diski paylaşır, Windows güvenlik duvarında dosya paylaşımına izin verir
          $yb = Join-Path ([IO.Path]::GetTempPath()) 'asorti_paylasim.ps1'
          $ybIcerik = "& net.exe share `"$depoHarf=$($depoHarf):\`" `"/GRANT:$herkes,FULL`" | Out-Null`r`n" +
                      "try { Enable-NetFirewallRule -Group '@FirewallAPI.dll,-28502' -ErrorAction Stop } catch {}`r`n"
          [IO.File]::WriteAllText($yb, $ybIcerik, (New-Object Text.UTF8Encoding($true)))
          $p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -PassThru -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $yb + '"'))
          Remove-Item -Force $yb -ErrorAction SilentlyContinue
          try { foreach ($sh in @(Get-CimInstance Win32_Share -ErrorAction Stop)) { if ("$($sh.Path)".TrimEnd('\').ToUpperInvariant() -eq "$($depoHarf):" -and $sh.Name -notmatch '\$$') { $pay = "$($sh.Name)"; break } } } catch {}
          Adim $(if ($pay) { "     paylaşıldı: \\$PC\$pay" } else { '     UYARI: paylaşım açılamadı' })
        } catch { Adim ('     UYARI: paylaşım açılamadı (' + $_.Exception.Message + ')') }
      } else { Adim "     paylaşım var: \\$PC\$pay" }
      if (-not $pay) { $pay = $depoHarf; [void]$script:sonNot.Add("Bu bilgisayarın $($depoHarf): diski paylaşılamadı. Paylaşmadan OTOPASTAL pastallara ulaşamaz (Dosya Gezgini → $($depoHarf): → sağ tık → Özellikler → Paylaşım).") }
      $hedefUnc = "\\$PC\$pay"
      # b) aynı harf bu bilgisayarda da kendi diskine bağlanır (AccuNest'in istediği gibi: iki bilgisayarda da aynı harf); harf doluysa dokunulmaz
      $H = $S.surucu.ToUpperInvariant()
      $b = SurucuBaglantisi $H
      if (-not $b.var) { $o = (cmd /c "net use $H $hedefUnc /persistent:yes 2>&1" | Out-String).Trim(); Adim "     $H → $hedefUnc  ($o)" }
      elseif ($b.yol -and $b.yol.ToUpperInvariant() -eq $hedefUnc.ToUpperInvariant()) { Adim "     $H zaten $hedefUnc" }
      else { Adim "     $H bu bilgisayarda başka bir yere bağlı ($($b.yol)); dokunulmadı" }
      # c) OTOPASTAL'da bir kerelik bağlantı dosyası (geçmiş işler bu harfin çalıştığını göstermiyorsa)
      $ci = $(if ($r) { $r.cihaz } else { $null })
      $kanit = $ci -and $ci.harf -eq $S.surucu -and -not $ci.sunucuda_baglanti_gerekli
      $ad = "Asorti_Araci_baglanti_$PC.bat"
      $icerik = BaglantiDosyasi $H $hedefUnc $ad
      [IO.File]::WriteAllText((Join-Path $hedef 'OTOPASTAL_icin_baglanti.bat'), $icerik, [Text.Encoding]::ASCII)
      $script:otoKomut = "net use $H $hedefUnc /persistent:yes"
      if ($kanit) { Adim "     OTOPASTAL pastallara $H ile ulaşıyor (geçmiş işlerden): orada bir şey yapmaya gerek yok" }
      else {
        $nest = $(if ($r -and $r.otopastal_bilgisayari) { "$($r.otopastal_bilgisayari)" } else { UncBilgisayar $S.kuyruk })
        $kondu = SunucuyaKoy $nest $ad $icerik
        if ($kondu) { Adim "     OTOPASTAL'a bağlantı dosyası kondu: $kondu"; [void]$script:sonNot.Add("OTOPASTAL'da yapılacak tek şey: $nest bilgisayarında masaüstündeki (ya da Ortak Belgeler'deki) '$ad' dosyasına bir kere çift tıkla. Bağlantı sonra her açılışta kendiliğinden yenilenir.") }
        else { Adim '     OTOPASTAL''a dosya konamadı; kurulum klasöründe hazır'; [void]$script:sonNot.Add("OTOPASTAL'da yapılacak tek şey: kurulum klasöründeki OTOPASTAL_icin_baglanti.bat dosyasını OTOPASTAL'a götürüp orada bir kere çift tıkla (ya da aşağıdaki komutu orada çalıştır). Bağlantı sonra her açılışta kendiliğinden yenilenir.") }
      }
    }
    $ilerleme.Value = 5

    Adim '6/10  Eski kurulum ayarları taşınıyor'
    $eskiProfil = Join-Path $ESKI 'uygulama\profil'; $yeniProfil = Join-Path $hedef 'profil'
    if ((Test-Path $eskiProfil) -and -not (Test-Path $yeniProfil)) { Copy-Item -Path $eskiProfil -Destination $yeniProfil -Recurse -Force -ErrorAction SilentlyContinue; Adim '     çalışma sayfaları ve ayarlar eski kurulumdan alındı' }
    $eskiK = Join-Path $ESKI 'kopru'
    foreach ($d in 'isleniyor', 'sonuc') { if (Test-Path (Join-Path $eskiK $d)) { Copy-Item -Path (Join-Path $eskiK "$d\*") -Destination (Join-Path $hedef "kopru\$d") -Force -ErrorAction SilentlyContinue } }
    $ilerleme.Value = 6

    Adim '7/10  Kısayollar oluşturuluyor'
    $w = New-Object -ComObject WScript.Shell
    $vbs = Join-Path $hedef 'sistem\baslat.vbs'; $ico = Join-Path $hedef 'sistem\asorti.ico'
    # kisayol uygulamanin kendisini acar (gorev cubuguna sabitlenince ayni dugmede birlesir); derlenemediyse eskisi gibi baslat.vbs'yi
    function KisayolYaz([string]$l) {
      $k = $w.CreateShortcut($l)
      if ($exeVar) { $k.TargetPath = $exe; $k.Arguments = ''; $k.WorkingDirectory = (Join-Path $hedef 'sistem'); $k.IconLocation = "$exe,0" }
      else { $k.TargetPath = "$env:WINDIR\System32\wscript.exe"; $k.Arguments = "`"$vbs`""; $k.WorkingDirectory = $hedef; $k.IconLocation = "$ico,0" }
      $k.Description = 'Asorti Aracı'; $k.Save()
    }
    $masa = @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:USERPROFILE 'Desktop')); if ($env:OneDrive) { $masa += (Join-Path $env:OneDrive 'Desktop') }
    foreach ($m in ($masa | Select-Object -Unique)) { $l = Join-Path $m 'Asorti Araci.lnk'; if (Test-Path $l) { Remove-Item -Force $l -ErrorAction SilentlyContinue } }
    $yerler = @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'))
    foreach ($y in $yerler) {
      if (-not (Test-Path $y)) { continue }
      KisayolYaz (Join-Path $y 'Asorti Araci.lnk'); Adim "     $y"
    }
    KisayolYaz (Join-Path $hedef 'Asorti Araci.lnk')
    $ilerleme.Value = 7

    Adim '8/10  Eski otomatik başlatma kaldırılıyor'
    $S0 = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\asorti_gerber_kopru.bat'
    if (Test-Path $S0) { Remove-Item -Force $S0; Adim '     kaldırıldı' } else { Adim '     yoktu' }
    $ilerleme.Value = 8

    Adim '9/10  Eski deneme dosyaları'
    if ($cTemiz.Checked -and (Test-Path $ESKI) -and ($hedef.ToUpperInvariant() -ne $ESKI.ToUpperInvariant())) {
      $sil = @('asorti_araci.html', 'uygulama.html', 'uygulama', 'kopru', 'test', 'k_baglan.bat', 'z_baglan.bat', 'z_kontrol.bat', 'z_log.txt', 'kuyruk_ayari.reg', 'Asorti Araci.lnk') + @(Get-ChildItem $ESKI -Filter 'k_log_*.txt' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
      foreach ($x in $sil) { $p = Join-Path $ESKI $x; if (Test-Path $p) { try { Remove-Item -Recurse -Force $p; Adim "     silindi: $p" } catch { Adim "     silinemedi: $p" } } }
    } else { Adim '     atlandı' }
    $ilerleme.Value = 9

    Adim '10/10  Kaldırma dosyası yazılıyor'
    $kal = @'
# Asorti Araci'ni kaldirir
$hedef = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Add-Type -AssemblyName System.Windows.Forms
if ([Windows.Forms.MessageBox]::Show("Asorti Araci kaldirilsin mi?`r`n$hedef klasoru ve kisayollar silinecek (Excel dosyalarina dokunulmaz).", 'Asorti Araci', 'YesNo', 'Question') -ne 'Yes') { exit }
Get-CimInstance Win32_Process | Where-Object { ($_.Name -eq 'powershell.exe' -and $_.CommandLine -match '(sunucu|kopru)\.ps1') -or ($_.Name -match '^(AsortiAraci|AsortiAcilis)\.exe$') -or ($_.Name -match '^(msedge|chrome|msedgewebview2)\.exe$' -and $_.CommandLine -match 'AsortiAraci\\profil') } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force } catch {} }
Start-Sleep -Milliseconds 800
foreach ($y in @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'))) { $l = Join-Path $y 'Asorti Araci.lnk'; if (Test-Path $l) { Remove-Item -Force $l } }
Start-Process cmd.exe -WindowStyle Hidden -ArgumentList "/c timeout /t 2 >nul & rmdir /s /q `"$hedef`""
'@
    $kal | Set-Content -Path (Join-Path $hedef 'sistem\kaldir.ps1') -Encoding UTF8
    "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0sistem\kaldir.ps1`"`r`n" | Set-Content -Path (Join-Path $hedef 'Kaldir.bat') -Encoding ASCII
    $ilerleme.Value = 10
    Adim 'Kurulum tamamlandı.'
    $script:kuruldu = $true
  } catch {
    Adim ('HATA: ' + $_.Exception.Message)
    [Windows.Forms.MessageBox]::Show("Kurulum yarıda kaldı:`r`n" + $_.Exception.Message, 'Asorti Aracı') | Out-Null
  }
  try { $script:logSatir | Set-Content -Path (Join-Path $hedef 'kurulum_log.txt') -Encoding UTF8 } catch {}
  $metin = "Asorti Aracı $hedef klasörüne kuruldu. Açmak için masaüstündeki 'Asorti Araci' simgesine çift tıkla.`r`n`r`n"
  if (-not $S.gerber) { $metin += "Bu bilgisayara sadece asorti kuruldu: asorti hesabı, Excel'e kaydetme ve yazdırma çalışır.`r`nAccuMark sonradan kurulursa uygulamada ⚙ → Gerber bağlantısı → Otomatik bul yeterli.`r`n" }
  else {
    $metin += "Gerber: $($S.accumark)`r`n"
    $metin += $(if ($S.otopastal -eq 'ayri') { "OTOPASTAL: ayrı bilgisayarda · pastallara $($S.surucu.ToUpperInvariant()) ile ulaşır`r`n" } elseif ($S.otopastal -eq 'ayni') { "OTOPASTAL: bu bilgisayarda`r`n" } else { "OTOPASTAL: yok · pastallar Gerber'de oluşur, yerleştirmeyi Gerber'de yaparsın; boy ve verimi uygulama Gerber'den okur`r`n" })
  }
  foreach ($n in $script:sonNot) { $metin += "`r`n$n`r`n" }
  if ($script:otoKomut -and $script:sonNot.Count) { $metin += "`r`n     $($script:otoKomut)`r`n" }
  $metin += "`r`nKaldırmak istersen kurulum klasöründeki Kaldir.bat'ı çalıştır."
  $bOtoKopya.Visible = [bool]($script:otoKomut -and $script:sonNot.Count)
  $lBitti.Text = $metin
}
$bOtoKopya.Add_Click({ if ($script:otoKomut) { [Windows.Forms.Clipboard]::SetText($script:otoKomut); $bOtoKopya.Text = 'Kopyalandı ✔' } })

# ---------- gezinme ----------
function Goster {
  $orta.Controls.Clear(); $orta.Controls.Add($sayfalar[$script:sira])
  $baslik.Text = $basliklar[$script:sira][0]; $altBaslik.Text = $basliklar[$script:sira][1]
  $bGeri.Enabled = ($script:sira -in 1, 2); $bIleri.Enabled = $true; $bIptal.Enabled = ($script:sira -lt 3)
  $bIleri.Text = $(if ($script:sira -in 1, 2) { 'Kur' } elseif ($script:sira -eq 4) { 'Bitir' } else { 'İleri >' })
  if ($script:sira -eq 1) { if (-not $script:rapor -and -not ($script:taraP -and -not $script:taraP.HasExited)) { TaramaBaslat } else { Ozet } }
  if ($script:sira -eq 2) { HarfBilgi }
  if ($script:sira -eq 3) { $bIleri.Enabled = $false; $bGeri.Enabled = $false; $F.Refresh(); Kur; $script:sira = 4; Goster }
}
$bIleri.Add_Click({
  if ($script:sira -in 1, 2) {
    if (-not $tHedef.Text) { [Windows.Forms.MessageBox]::Show('Kurulum klasörünü yaz.', 'Asorti Aracı') | Out-Null; return }
    $pn = 0; if (-not [int]::TryParse($tPort.Text, [ref]$pn) -or $pn -lt 1024 -or $pn -gt 65535) { [Windows.Forms.MessageBox]::Show('Bağlantı noktası 1024 ile 65535 arasında bir sayı olmalı (8642 bırakabilirsin).', 'Asorti Aracı') | Out-Null; return }
    if ($script:sira -eq 2) { Ozet; if (-not $script:zorunluTamam) { $script:sira = 1; Goster; return } }
    $script:sira = 3; Goster; return
  }
  if ($script:sira -eq 4) {
    if ($cAc.Checked -and $script:kuruldu) {
      $hk = $tHedef.Text.TrimEnd('\'); $ux = Join-Path $hk 'sistem\AsortiAraci.exe'
      if (Test-Path -LiteralPath $ux) { Start-Process -FilePath $ux -WorkingDirectory (Join-Path $hk 'sistem') }
      else { Start-Process -FilePath "$env:WINDIR\System32\wscript.exe" -ArgumentList ('"' + (Join-Path $hk 'sistem\baslat.vbs') + '"') }
    }
    $F.Close(); return
  }
  $script:sira++; Goster
})
$bGeri.Add_Click({ if ($script:sira -eq 2) { $script:sira = 1; Goster; Ozet } elseif ($script:sira -gt 0) { $script:sira--; Goster } })
$bIptal.Add_Click({ $tm.Stop(); if ($script:taraP -and -not $script:taraP.HasExited) { try { $script:taraP.Kill() } catch {} }; $F.Close() })
$F.Add_FormClosing({ $tm.Stop(); if ($script:taraP -and -not $script:taraP.HasExited) { try { $script:taraP.Kill() } catch {} } })
Goster
[void]$F.ShowDialog()
