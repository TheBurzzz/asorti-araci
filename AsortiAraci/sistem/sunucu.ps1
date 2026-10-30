# Asorti Araci - yerel sunucu: uygulama penceresini sunar, Gerber koprusunu arka planda calistirir,
# pencere kapaninca kopruyu ve Batch'i de kapatir. GitHub'daki yeni surumu bulur ve tek tusla kurar.
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $Root 'sistem\ortak.ps1'); $A = Ayarlar $Root; $Port = $A.port
$ErrorActionPreference = 'Stop'
$mtx = New-Object Threading.Mutex($false, 'AsortiAraciSunucu')
$sahip = $false; try { $sahip = $mtx.WaitOne(0) } catch [Threading.AbandonedMutexException] { $sahip = $true }
if (-not $sahip) { exit }
New-Item -ItemType Directory -Force -Path (Join-Path $Root 'kopru\log') | Out-Null
$LOG = Join-Path $Root 'kopru\log\sunucu.txt'
function Log($s) { try { Add-Content -Path $LOG -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $s) -Encoding UTF8 } catch {} }

function KopruSurecleri { @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'kopru\\kopru\.ps1' }) }
# baska yerden (eski kurulum) calisan kopru varsa kapat; kopruyu bu sunucu yonetiyor
# (kopru calismiyorsa adli kilidi de yoktur: o zaman yavas olan surec sorgusu hic yapilmaz, pencere daha cabuk acilir)
$kk = $null; if ([Threading.Mutex]::TryOpenExisting('AsortiGerberKopru', [ref]$kk)) { $kk.Dispose(); foreach ($p in KopruSurecleri) { try { Stop-Process -Id $p.ProcessId -Force } catch {} } }
$script:kopru = $null
function KopruBaslat {
  $script:kBas = Get-Date
  $script:kopru = Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -PassThru -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $Root 'kopru\kopru.ps1'))
  Log ('kopru baslatildi, pid ' + $script:kopru.Id)
}
# uygulama penceresi (bu kurulumun profil klasoruyle acilan Edge/Chrome) hala acik mi?
$script:profilDesen = [regex]::Escape((Join-Path $Root 'profil'))
function PencereAcik {
  try { return (@(Get-CimInstance Win32_Process -Filter "Name='msedge.exe' OR Name='chrome.exe'" -ErrorAction Stop | Where-Object { $_.CommandLine -match $script:profilDesen }).Count -gt 0) }
  catch { return $null }   # bilinmiyor
}
# uygulama penceresi (Edge / Chrome, basligi "Asorti Araci")
function UygulamaPencereleri { @(Get-Process -Name msedge, chrome -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle -like 'Asorti Ara*' }) }
# acik uygulama penceresi simge durumundaysa eski boyutuna dondurur (one getirmeyi acilisi baslatan betik yapar)
$script:u32Tanim = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(System.IntPtr h, int c); [DllImport("user32.dll")] public static extern bool IsIconic(System.IntPtr h);'
function PencereOneGetir {
  if (-not ('AsortiPencere.P' -as [type])) {
    if ($script:u32Is) { [void]$script:u32Is.AsyncWaitHandle.WaitOne(8000) }   # arka planda hazirlaniyor: bitmesini bekle
    if (-not ('AsortiPencere.P' -as [type])) { Add-Type -Namespace AsortiPencere -Name P -MemberDefinition $script:u32Tanim }
  }
  foreach ($p in UygulamaPencereleri) { if ([AsortiPencere.P]::IsIconic($p.MainWindowHandle)) { [void][AsortiPencere.P]::ShowWindowAsync($p.MainWindowHandle, 9) } }
}
# one getirme ilk seferde derleme beklemesin: pencere acildiktan bir sure sonra arka planda (ayri is parcaciginda) hazirlanir
function PencereHazirla {
  if ($script:u32Ps -or ('AsortiPencere.P' -as [type])) { return }
  try { $script:u32Ps = [PowerShell]::Create(); [void]$script:u32Ps.AddScript('param($t) Add-Type -Namespace AsortiPencere -Name P -MemberDefinition $t').AddArgument($script:u32Tanim); $script:u32Is = $script:u32Ps.BeginInvoke() } catch { $script:u32Ps = 1 }
}
# acilis ekrani (sistem\acilis.cs): bu bilgisayarda .NET Framework'un kendi derleyicisiyle derlenir -> sistem\AsortiAcilis.exe
# Program acildiktan birkac saniye sonra arka planda (ayri is parcaciginda) yapilir; kaynak degismediyse yeniden derlenmez.
function AcilisDerle([string]$csc = (Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'csc.exe')) {
  $script:derleBakildi = $true
  $cs = Join-Path $PSScriptRoot 'acilis.cs'; if (-not (Test-Path -LiteralPath $cs)) { return }
  $exe = Join-Path $PSScriptRoot 'AsortiAcilis.exe'; $damga = Join-Path $PSScriptRoot 'AsortiAcilis.surum'
  $md5 = (Get-FileHash -Algorithm MD5 -LiteralPath $cs).Hash
  $eski = ''; if (Test-Path -LiteralPath $damga) { $eski = "$(Get-Content -LiteralPath $damga -Raw)".Trim() }
  if ($eski -eq $md5 -and (Test-Path -LiteralPath $exe)) { return }
  if ($eski -eq "HATA $md5" -and ((Get-Date) - (Get-Item -LiteralPath $damga).LastWriteTime).TotalHours -lt 12) { return }   # ayni kaynak az once derlenemedi
  if (-not (Test-Path -LiteralPath $csc)) { Log 'acilis ekrani derlenemedi: csc.exe bulunamadi'; return }
  try {
    $script:derlePs = [PowerShell]::Create()
    [void]$script:derlePs.AddScript({
      param($csc, $cs, $exe, $ico, $damga, $md5, $kayit)
      $yeni = $exe -replace '\.exe$', '_yeni.exe'; $ertele = $false
      Remove-Item -LiteralPath $yeni -Force -ErrorAction SilentlyContinue
      $cikti = (& $csc /nologo /target:winexe /optimize+ "/out:$yeni" "/win32icon:$ico" /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll $cs 2>&1 | Out-String)
      $ok = ($LASTEXITCODE -eq 0) -and (Test-Path -LiteralPath $yeni)
      if ($ok) {
        try { Move-Item -LiteralPath $yeni -Destination $exe -Force -ErrorAction Stop }
        catch { $ok = $false; $ertele = $true; $cikti += "`r`nyerine konamadi (o an acik olabilir), sonra yeniden denenecek: " + $_.Exception.Message }
      }
      if ($ok) { Set-Content -LiteralPath $damga -Value $md5 -Encoding ASCII }
      elseif (-not $ertele) { Set-Content -LiteralPath $damga -Value "HATA $md5" -Encoding ASCII }
      Set-Content -LiteralPath $kayit -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + $(if ($ok) { ' acilis ekrani derlendi' } elseif ($ertele) { ' acilis ekrani derlendi, yerine konamadi' } else { ' ACILIS EKRANI DERLENEMEDI' }) + "`r`n" + $cikti) -Encoding UTF8
    }).AddArgument($csc).AddArgument($cs).AddArgument($exe).AddArgument((Join-Path $PSScriptRoot 'asorti.ico')).AddArgument($damga).AddArgument($md5).AddArgument((Join-Path $Root 'kopru\log\acilis_derleme.txt'))
    $script:derleIs = $script:derlePs.BeginInvoke()
    Log 'acilis ekrani derleniyor'
  } catch { Log ('acilis ekrani derlenemedi: ' + $_.Exception.Message) }
}
function Kapat([string]$neden = 'pencere kapandi') {
  Log "${neden}: kopru ve Batch kapatiliyor"
  try { if ($script:kopru -and -not $script:kopru.HasExited) { Stop-Process -Id $script:kopru.Id -Force } } catch {}
  foreach ($p in KopruSurecleri) { try { Stop-Process -Id $p.ProcessId -Force } catch {} }
  foreach ($b in @(Get-Process -Name batch -ErrorAction SilentlyContinue)) { try { [void]$b.CloseMainWindow() } catch {} }
  Start-Sleep 3
  foreach ($b in @(Get-Process -Name batch -ErrorAction SilentlyContinue)) { try { Stop-Process -Id $b.Id -Force } catch {} }
  try { OnerileriKapat (Join-Path $Root 'profil') } catch {}
}
# tarayicinin "kaydedilen bilgiler" onerilerini (adres / kisisel bilgi doldurma) sadece bu uygulamanin profilinde kapatir.
# Normal Edge'e dokunmaz. Pencere kapandiktan sonra yapilir (Edge acikken ayar dosyasini kendisi yazar).
function OnerileriKapat($profil) {
  $pref = Join-Path $profil 'Default\Preferences'
  if (-not (Test-Path $pref)) { return }
  $metin = [IO.File]::ReadAllText($pref, [Text.Encoding]::UTF8)
  if ($metin -match '"autofill":\{[^{}]*"credit_card_enabled":false' -and $metin -match '"autofill":\{[^{}]*"profile_enabled":false') { return }   # zaten kapali
  try { $kf = [IO.File]::Open((Join-Path $profil 'lockfile'), 'Open', 'ReadWrite', 'None'); $kf.Close() } catch [IO.FileNotFoundException] { } catch { return }   # Edge hala bu profili kullaniyor
  Add-Type -AssemblyName System.Web.Extensions
  $js = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $js.MaxJsonLength = [int]::MaxValue; $js.RecursionLimit = 1000
  $d = $js.DeserializeObject($metin)
  if (-not ($d -is [System.Collections.IDictionary])) { return }
  if ($d.ContainsKey('autofill') -and $d['autofill'] -is [System.Collections.IDictionary]) { $af = $d['autofill'] } else { $af = New-Object 'System.Collections.Generic.Dictionary[string,object]'; $d['autofill'] = $af }
  $deg = $false; foreach ($k in 'profile_enabled', 'credit_card_enabled') { if (-not ($af.ContainsKey($k) -and ($af[$k] -is [bool]) -and -not $af[$k])) { $af[$k] = $false; $deg = $true } }
  if (-not $deg) { return }
  $yeni = $js.Serialize($d); [void]$js.DeserializeObject($yeni)
  Copy-Item -Force $pref ($pref + '.asorti_yedek')
  [IO.File]::WriteAllText($pref, $yeni, (New-Object Text.UTF8Encoding($false))); Log 'tarayici onerileri kapatildi'
}
if ($A.gerber) { KopruBaslat } else { Log 'Gerber kapali (sadece asorti): kopru baslatilmadi' }

# ---------- Gerber / OTOPASTAL'i otomatik bulma (ayarlar menusundeki "Otomatik bul") ----------
$script:taramaP = $null; $script:taramaIlkP = $null
$TARAMA = Join-Path $Root 'kopru\log\tarama.json'
$TARAMA_ILK = Join-Path $Root 'kopru\log\tarama_ilk.json'
# "Otomatik bul" (tarama.json) ve acilistaki bilgi taramasi (tarama_ilk.json) ayri sureclerde: biri digerini bekletmez
function TaramaBaslat([string]$cikti, [switch]$Taze) {
  $p = $(if ($Taze) { $script:taramaIlkP } else { $script:taramaP })
  if ($p -and -not $p.HasExited) { return $false }
  if (-not $Taze) { Remove-Item -Force $cikti -ErrorAction SilentlyContinue }   # eski sonuc yeni sanilmasin
  $arg = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $Root 'sistem\tara.ps1') + '"'), '-Cikti', ('"' + $cikti + '"'))
  if ($Taze) { $arg += '-Taze' }
  $p = Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -PassThru -ArgumentList $arg
  if ($Taze) { $script:taramaIlkP = $p } else { $script:taramaP = $p; $script:taramaBas = Get-Date }
  return $true
}
function TaramaOku([string]$f) { if (Test-Path $f) { try { return (Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json) } catch {} }; return $null }
function GerberAyar { [ordered]@{ gerber = [bool]$A.gerber; accumark = "$($A.accumark)"; userroot = "$($A.userroot)"; depo = "$($A.depo)"; kuyruk = "$($A.kuyruk)"; otopastal = "$($A.otopastal)"; surucu = "$($A.surucu)"; surucu2 = "$($A.surucu2)" } }
# taramanin onerisi su anki ayarlarla birlesir: calisan bir ayar bos ya da eksik bir bulguyla asla degismez
function TaramaOneri($r) {
  if (-not $r -or -not $r.oneri) { return $null }
  $o = $r.oneri; $s = [ordered]@{}
  $amSimdi = "$($A.accumark)"; $amOk = $false; if ($amSimdi) { $amOk = Test-Path -LiteralPath (Join-Path $amSimdi 'csvimprt.exe') }
  $s.accumark = $(if ("$($o.accumark)") { "$($o.accumark)" } elseif ($amOk) { $amSimdi } else { '' })
  $s.gerber = [bool]$s.accumark
  $s.userroot = $(if ("$($o.userroot)") { "$($o.userroot)" } else { "$($A.userroot)" })
  $s.depo = $(if ("$($o.depo)" -and $r.userroot -and [int]$r.userroot.alan -gt 0) { "$($o.depo)" } else { "$($A.depo)" })
  $kuSimdi = "$($A.kuyruk)"; $kuOk = $false; if ($kuSimdi) { try { $kuOk = Test-Path -LiteralPath $kuSimdi } catch {} }
  if ("$($o.kuyruk)") { $s.kuyruk = "$($o.kuyruk)"; $s.otopastal = "$($o.otopastal)"; $s.surucu = "$($o.surucu)"; $s.surucu2 = "$($o.surucu2)" }
  elseif ($kuOk) { $s.kuyruk = $kuSimdi; $s.otopastal = "$($A.otopastal)"; $s.surucu = "$($A.surucu)"; $s.surucu2 = "$($A.surucu2)" }
  else { $s.kuyruk = ''; $s.otopastal = 'yok'; $s.surucu = "$($A.surucu)"; $s.surucu2 = "$($A.surucu2)" }
  return $s
}
# bilgi taramasi: bu surumun tarama kodu ilk kez calisiyorsa bir kere (bir sey degistirmez; ileride sorun cikarsa neye bakilacagini gosterir)
$script:ilkEski = TaramaOku $TARAMA_ILK
# uygulama simgesi degistiyse (guncellemeyle yeni simge geldiyse) masaustu / Baslat menusu kisayollari da yenisini gostersin.
# Windows simgeleri dosya yoluna gore onbellekte tuttugu icin ayni yoldaki dosyayi degistirmek yetmez: kisayollar simgenin
# icerigine gore adlandirilmis kopyasina (sistem\simge\asorti-xxxxxxxx.ico) baglanir. Sadece bu kurulumun kisayollarina dokunur.
function SimgeGuncelle {
  $ikon = Join-Path $Root 'sistem\asorti.ico'; if (-not (Test-Path $ikon)) { return }
  $h = (Get-FileHash $ikon -Algorithm MD5).Hash.Substring(0, 8).ToLowerInvariant()
  $sd = Join-Path $Root 'sistem\simge'; $yeni = Join-Path $sd "asorti-$h.ico"
  if (-not (Test-Path $yeni)) { New-Item -ItemType Directory -Force -Path $sd | Out-Null; Copy-Item -Force $ikon $yeni }
  $yerler = @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory'), $Root)
  if ($env:APPDATA) { $yerler += @((Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'), (Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar')) }
  if ($env:OneDrive) { $yerler += (Join-Path $env:OneDrive 'Desktop') }
  $w = $null; $deg = 0
  foreach ($y in @($yerler | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique)) {
    foreach ($l in @(Get-ChildItem -LiteralPath $y -Filter *.lnk -File -ErrorAction SilentlyContinue)) {
      try {
        if (-not $w) { $w = New-Object -ComObject WScript.Shell }
        $k = $w.CreateShortcut($l.FullName); $arg = "$($k.Arguments)"
        if ($arg -notmatch '(?i)baslat\.vbs' -or $arg.IndexOf($Root, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }   # bu kurulumun kisayolu degil
        if ("$($k.IconLocation)".StartsWith($yeni, [StringComparison]::OrdinalIgnoreCase)) { continue }
        $k.IconLocation = "$yeni,0"; $k.Save(); $deg++
      } catch {}
    }
  }
  if ($deg) {
    $ie = Join-Path $env:SystemRoot 'System32\ie4uinit.exe'; if (Test-Path $ie) { try { Start-Process -FilePath $ie -ArgumentList '-show' -WindowStyle Hidden } catch {} }
    Log "kisayol simgesi yenilendi ($deg kisayol)"
  }
}
try { SimgeGuncelle } catch { Log ('kisayol simgesi yenilenemedi: ' + $_.Exception.Message) }
if (-not $script:ilkEski -or -not $script:ilkEski.surum -or ([version]("$($script:ilkEski.surum)") -lt [version]'1.1.17')) { try { if (TaramaBaslat $TARAMA_ILK -Taze) { Log 'bilgisayar taramasi baslatildi (sadece bilgi icin, ayarlara dokunmaz)' } } catch {} }

# ---------- guncelleme ----------
$script:uzak = $null; $script:uzakZaman = [datetime]::MinValue
function Web { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 }
function SurumNo($v) { try { return [version]("$v".Trim()) } catch { return [version]'0.0' } }
function UzakSurum([bool]$taze) {
  if (-not $A.guncelleme) { return $null }
  if (-not $taze -and $script:uzak -and ((Get-Date) - $script:uzakZaman).TotalMinutes -lt 10) { return $script:uzak }
  Web
  $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 8 -Uri ("https://raw.githubusercontent.com/$($A.guncelleme)/main/AsortiAraci/surum.json?t=" + [DateTime]::UtcNow.Ticks)
  $metin = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()).TrimStart([char]0xFEFF)
  $script:uzak = $metin | ConvertFrom-Json; $script:uzakZaman = Get-Date
  return $script:uzak
}
# internet baglantisinin konumu (gun dogumu / batimi icin); bilgisayarin konum hizmeti kapaliysa kullanilir
$script:konum = $null
function IpKonum {
  if ($script:konum) { return $script:konum }
  Web
  foreach ($u in 'https://ipwho.is/', 'https://ipapi.co/json/', 'https://freeipapi.com/api/json') {
    try {
      $j = Invoke-RestMethod -UseBasicParsing -TimeoutSec 6 -Uri $u
      $lat = $j.latitude; $lon = $j.longitude
      if ($null -ne $lat -and $null -ne $lon -and "$lat" -ne '' -and "$lon" -ne '') {
        $sehir = if ($j.city) { "$($j.city)" } elseif ($j.cityName) { "$($j.cityName)" } else { '' }
        $script:konum = @{ lat = [double]$lat; lon = [double]$lon; sehir = $sehir; kaynak = $u }; return $script:konum
      }
    } catch {}
  }
  return $null
}
# Gerber'deki bir pastalin boyu ve verimi: depolama alanindaki mark.ctl -> mark???.mar dosyasindan okunur
# (pastal kaydi icinde: 258 = en, 274 = boy (inc, double), 308 = verim % (double))
function OkuPaylasimli($yol) { $fs = New-Object IO.FileStream($yol, 'Open', 'Read', 'ReadWrite'); try { $ms = New-Object IO.MemoryStream; $fs.CopyTo($ms); return , $ms.ToArray() } finally { $fs.Close() } }
function PastalBilgi([string]$alan, [string]$ad) {
  $dd = Join-Path (Join-Path (Join-Path $A.depo 'storage') $alan) 'data'
  $ctl = Join-Path $dd 'mark.ctl'; if (-not (Test-Path $ctl)) { return @{ var = $false; mesaj = "$alan klasoru bulunamadi" } }
  $c = OkuPaylasimli $ctl; $lat = [Text.Encoding]::GetEncoding(28591); $ad = $ad.ToUpperInvariant(); $kay = $null
  for ($i = 0; $i + 64 -le $c.Length; $i += 64) {
    if ($c[$i + 25] -ne 0) { continue }
    $n = $lat.GetString($c, $i, 20).Split([char]0)[0].Trim()
    if ($n.ToUpperInvariant() -eq $ad) { $kay = @{ ek = $lat.GetString($c, $i + 20, 3); slot = [int]$c[$i + 23] } }
  }
  if (-not $kay) { return @{ var = $false; mesaj = "$ad pastali $alan klasorunde yok" } }
  $mf = Join-Path $dd ('mark' + $kay.ek + '.mar'); $m = OkuPaylasimli $mf
  $o = [BitConverter]::ToUInt32($m, 16 + 64 * $kay.slot); $u = [BitConverter]::ToUInt32($m, 20 + 64 * $kay.slot)
  if ($o + 316 -gt $m.Length -or $u -lt 316) { return @{ var = $false; mesaj = 'pastal kaydi okunamadi' } }
  $en = [BitConverter]::ToDouble($m, $o + 258) * 2.54; $boy = [BitConverter]::ToDouble($m, $o + 274) * 2.54; $ver = [BitConverter]::ToDouble($m, $o + 308)
  if ([double]::IsNaN($boy) -or $boy -lt 0 -or $boy -gt 100000 -or [double]::IsNaN($ver) -or $ver -lt 0 -or $ver -gt 100) { return @{ var = $false; mesaj = 'pastal kaydi tanınmadı' } }
  return @{ var = $true; ad = $ad; en_cm = [math]::Round($en, 2); boy_cm = [math]::Round($boy, 2); verim = [math]::Round($ver, 2) }
}
# ---------- Excel kayit klasoru (kullanici ayari: kurulum klasorundeki kullanici.json; guncelleme ve kurulum dokunmaz) ----------
$KF = Join-Path $Root 'kullanici.json'
function KullaniciOku { $h = [ordered]@{}; try { if (Test-Path $KF) { $j = [IO.File]::ReadAllText($KF, [Text.Encoding]::UTF8) | ConvertFrom-Json; foreach ($p in $j.PSObject.Properties) { $h[$p.Name] = $p.Value } } } catch {}; return $h }
function KullaniciYaz($ad, $deger) { $h = KullaniciOku; $h[$ad] = $deger; [IO.File]::WriteAllText($KF, ($h | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false))) }
function ExcelKlasor { return "$((KullaniciOku)['excel_klasor'])" }
function ExcelDurum { $k = ExcelKlasor; return @{ klasor = $k; var = [bool]($k -and (Test-Path -LiteralPath $k -PathType Container)) } }
function KlasorSec($bas) {
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ('asorti_klasor_' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.txt')
  [IO.File]::WriteAllText($tmp, "$bas", (New-Object Text.UTF8Encoding($false)))
  try {
    Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -Wait -ArgumentList @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $Root 'sistem\klasor_sec.ps1') + '"'), ('"' + $tmp + '"'))
    return ([IO.File]::ReadAllText($tmp, [Text.Encoding]::UTF8)).Trim()
  } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}
# adres satirindaki ?ad=... degerleri (Turkce harfler UTF-8 olarak)
function Sorgu($ctx, $ad) {
  $q = ''; $i = $ctx.Request.RawUrl.IndexOf('?'); if ($i -ge 0) { $q = $ctx.Request.RawUrl.Substring($i + 1) }
  foreach ($p in $q.Split('&')) { $j = $p.IndexOf('='); if ($j -gt 0 -and [Uri]::UnescapeDataString($p.Substring(0, $j)) -eq $ad) { return [Uri]::UnescapeDataString($p.Substring($j + 1).Replace('+', ' ')) } }
  return ''
}
function ExcelAdGecerli($n) { return ($n -and $n.Length -lt 200 -and $n -notmatch '[\\/:*?"<>|]' -and $n -match '(?i)\.xls[xm]$' -and $n -notmatch '^\.') }
function ExcelKaydet($ctx) {
  $ad = Sorgu $ctx 'ad'; $mod = Sorgu $ctx 'mod'; $k = ExcelKlasor
  if (-not (ExcelAdGecerli $ad)) { return @{ hata = 'Dosya adı geçersiz.' } }
  if (-not ($k -and (Test-Path -LiteralPath $k -PathType Container))) { return @{ klasoryok = $true } }
  $ms = New-Object IO.MemoryStream; $ctx.Request.InputStream.CopyTo($ms); $veri = $ms.ToArray()
  if ($veri.Length -lt 100) { return @{ hata = 'Dosya boş geldi.' } }
  $hedef = Join-Path $k $ad
  if (Test-Path -LiteralPath $hedef) {
    if ($mod -eq 'yeni') {
      $kok = [IO.Path]::GetFileNameWithoutExtension($ad); $uz = [IO.Path]::GetExtension($ad); $i = 2
      while (Test-Path -LiteralPath (Join-Path $k ("$kok ($i)$uz"))) { $i++ }
      $ad = "$kok ($i)$uz"; $hedef = Join-Path $k $ad
    } elseif ($mod -ne 'ustune') { return @{ var = $true; ad = $ad; klasor = $k } }
  }
  $gecici = Join-Path $k ('~asorti_' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.tmp')
  try {
    [IO.File]::WriteAllBytes($gecici, $veri)
    if (-not (Test-Path -LiteralPath $hedef)) { [IO.File]::Move($gecici, $hedef) }
    else {
      try { [IO.File]::Replace($gecici, $hedef, $null) }
      catch { if ($_.Exception.Message -match '(?i)being used|kullan|another process|ba.ka bir i.lem') { throw }; [IO.File]::Copy($gecici, $hedef, $true); Remove-Item -LiteralPath $gecici -Force -ErrorAction SilentlyContinue }
    }
  } catch {
    Remove-Item -LiteralPath $gecici -Force -ErrorAction SilentlyContinue
    if ($_.Exception.Message -match '(?i)being used|kullan|another process|ba.ka bir i.lem|access|eri.im') { return @{ kilitli = $true; ad = $ad } }
    return @{ hata = $_.Exception.Message }
  }
  Log "excel kaydedildi: $hedef"
  return @{ ok = $true; ad = $ad; klasor = $k; yol = $hedef }
}
function ExcelAc($ctx) {
  $ad = Sorgu $ctx 'ad'; $nasil = Sorgu $ctx 'nasil'; $k = ExcelKlasor
  if (-not ($k -and (Test-Path -LiteralPath $k -PathType Container))) { return @{ hata = 'Kayıt klasörü yok.' } }
  if ($nasil -eq 'klasor' -and -not $ad) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $k + '"'); return @{ ok = $true } }
  if (-not (ExcelAdGecerli $ad)) { return @{ hata = 'Dosya adı geçersiz.' } }
  $yol = Join-Path $k $ad; if (-not (Test-Path -LiteralPath $yol)) { return @{ hata = 'Dosya bulunamadı.' } }
  if ($nasil -eq 'klasor') { Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"' + $yol + '"') } else { Start-Process -FilePath $yol }
  return @{ ok = $true }
}

function SurenIs { @(Get-ChildItem (Join-Path $Root 'kopru\gelen'), (Join-Path $Root 'kopru\isleniyor') -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.txt' }).Count -gt 0 }
function Guncelle {
  Web
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ('asorti_guncelleme_' + [guid]::NewGuid().ToString('N').Substring(0, 8)); New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  try {
    $zip = Join-Path $tmp 'paket.zip'
    Invoke-WebRequest -UseBasicParsing -TimeoutSec 120 -Uri "https://codeload.github.com/$($A.guncelleme)/zip/refs/heads/main" -OutFile $zip
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, (Join-Path $tmp 'ac'))
    $ic = Get-ChildItem (Join-Path $tmp 'ac') -Directory | Select-Object -First 1
    $src = Join-Path $ic.FullName 'AsortiAraci'
    foreach ($g in 'uygulama.html', 'asorti_araci.html', 'surum.json', 'sistem\sunucu.ps1', 'sistem\ortak.ps1', 'sistem\bul.ps1', 'sistem\tara.ps1', 'kopru\kopru.ps1') { if (-not (Test-Path (Join-Path $src $g))) { throw "indirilen pakette $g yok" } }
    $yeni = (Get-Content (Join-Path $src 'surum.json') -Raw -Encoding UTF8 | ConvertFrom-Json).surum; $eski = (YerelSurum $Root).surum
    # geri donebilmek icin simdiki surumu yedekle (sadece program dosyalari)
    $yd = Join-Path $Root 'yedek'; if (Test-Path $yd) { Remove-Item -Recurse -Force $yd }
    New-Item -ItemType Directory -Force -Path (Join-Path $yd 'sistem'), (Join-Path $yd 'kopru') | Out-Null
    foreach ($f in 'uygulama.html', 'asorti_araci.html', 'surum.json') { if (Test-Path (Join-Path $Root $f)) { Copy-Item (Join-Path $Root $f) $yd } }
    Copy-Item (Join-Path $Root 'sistem\*') (Join-Path $yd 'sistem') -Force
    Copy-Item (Join-Path $Root 'kopru\*.ps1') (Join-Path $yd 'kopru') -Force
    # yeni dosyalari yerine koy (ayarlar, calisma sayfalari, siparis kayitlari pakette yok, dokunulmaz)
    Copy-Item -Path (Join-Path $src '*') -Destination $Root -Recurse -Force
    $kp = Join-Path $ic.FullName 'kurulum'; if (Test-Path $kp) { $hk = Join-Path $Root 'kurulum_paketi'; if (Test-Path $hk) { Remove-Item -Recurse -Force $hk }; New-Item -ItemType Directory -Force -Path $hk | Out-Null; Copy-Item -Path (Join-Path $ic.FullName '*') -Destination $hk -Recurse -Force }
    Log "guncellendi: $eski -> $yeni"
    return $yeni
  } finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
}
function YenidenBaslat {
  Log 'sunucu yeni surumle yeniden baslatiliyor'
  foreach ($p in KopruSurecleri) { try { Stop-Process -Id $p.ProcessId -Force } catch {} }
  try { $L.Stop(); $L.Close() } catch {}
  try { $mtx.ReleaseMutex() } catch {}
  Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $Root 'sistem\sunucu.ps1'))
  exit
}

$L = New-Object Net.HttpListener
$L.Prefixes.Add("http://localhost:$Port/")
$L.Start(); Log "sunucu acildi: http://localhost:$Port/"
$tipler = @{ '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.json' = 'application/json; charset=utf-8'; '.txt' = 'text/plain; charset=windows-1254'; '.png' = 'image/png'; '.ico' = 'image/x-icon'; '.css' = 'text/css; charset=utf-8'; '.woff2' = 'font/woff2' }
$script:sunucuId = "$PID-" + (Get-Date).Ticks   # sayfa, sunucu yeniden basladiginda (guncelleme) bunu degismis gorup kendini tazeler
$son = $null; $basla = Get-Date; $script:sonBak = [datetime]::MinValue; $script:kapanis = $null
foreach ($eskiDosya in 'acilis.hta', 'one_getir.ps1') { Remove-Item -LiteralPath (Join-Path $PSScriptRoot $eskiDosya) -Force -ErrorAction SilentlyContinue }   # artik kullanilmayan eski dosyalar
function JsonYanit($ctx, $obj) { Yanit $ctx 200 ($utf8.GetBytes(($obj | ConvertTo-Json -Depth 5 -Compress))) 'application/json; charset=utf-8' }
function Yanit($ctx, [int]$kod, [byte[]]$veri, [string]$tip, [string]$onbellek = 'no-store') {
  $r = $ctx.Response; $r.StatusCode = $kod; $r.Headers['Cache-Control'] = $onbellek
  if ($tip) { $r.ContentType = $tip }
  if ($veri) { $r.ContentLength64 = $veri.Length; $r.OutputStream.Write($veri, 0, $veri.Length) }
  $r.OutputStream.Close()
}
$utf8 = New-Object Text.UTF8Encoding($false)
try {
  while ($true) {
    $t = $L.GetContextAsync()
    while (-not $t.Wait(1000)) {
      $simdi = Get-Date
      # pencere "kapaniyorum" dediyse birkac saniye sonra (yenileme degilse) kapat
      if ($script:kapanis -and $simdi -gt $script:kapanis) { $script:kapanis = $null; if ((PencereAcik) -ne $true) { Kapat; $L.Stop(); exit } }
      # pencere simge durumunda / arka planda iken nabiz gecikebilir: kapatmadan once pencerenin gercekten kapandigina bak
      $sessiz = if ($son) { ($simdi - $son).TotalSeconds } else { ($simdi - $basla).TotalSeconds }
      if ($sessiz -gt 45 -and ($simdi - $script:sonBak).TotalSeconds -ge 15) {
        $script:sonBak = $simdi; $acik = PencereAcik
        if ($acik -eq $false -and ($son -or $sessiz -gt 180)) { Kapat $(if ($son) { 'pencere kapandi' } else { 'pencere hic acilmadi' }); $L.Stop(); exit }
        if ($null -eq $acik -and $sessiz -gt 900) { Kapat 'pencereden 15 dakikadir haber yok'; $L.Stop(); exit }
      }
      if ($script:acildiT -and -not $script:u32Ps -and ($simdi - $script:acildiT).TotalSeconds -gt 20) { PencereHazirla }
      if (-not $script:derleBakildi -and ($simdi - $basla).TotalSeconds -gt 3) { AcilisDerle }   # guncellemeden sonra bir kez gerekir
      if ($A.gerber -and $script:kopru.HasExited -and ((Get-Date) - $script:kBas).TotalSeconds -gt 30) { Log 'kopru durmustu, yeniden baslatiliyor'; KopruBaslat }
    }
    $ctx = $t.Result
    try {
      $yol = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
      $m = $ctx.Request.HttpMethod
      if ($yol -eq 'kapaniyor') { $script:kapanis = (Get-Date).AddSeconds(6); $script:hazirT = $null; Yanit $ctx 200 $null $null; continue }
      if ($yol -eq 'hazir' -and $m -eq 'POST') { $script:hazirT = Get-Date; Yanit $ctx 200 $null $null; continue }   # ilk sayfa ekrana cizildi: acilis ekrani kaybolabilir
      if ($yol -eq 'nabiz') { $son = Get-Date; $script:kapanis = $null; if (-not $script:acildi) { $script:acildi = $true; $script:acildiT = Get-Date; Remove-Item -LiteralPath (Join-Path $Root 'kopru\log\acilis.txt') -Force -ErrorAction SilentlyContinue }   # pencere acildi: yeniden acma kilidi kalksin
        JsonYanit $ctx @{ kopru = [bool]($script:kopru -and -not $script:kopru.HasExited); gerber = [bool]$A.gerber; otopastal = "$($A.otopastal)"; id = $script:sunucuId }; continue }
      if ($yol -eq 'excel/klasor' -and $m -eq 'GET') { JsonYanit $ctx (ExcelDurum); continue }
      if ($yol -eq 'excel/klasor-sec' -and $m -eq 'POST') {
        $sec = ''; try { $sec = KlasorSec (ExcelKlasor) } catch { Log ('klasor secilemedi: ' + $_.Exception.Message) }
        if ($sec -and (Test-Path -LiteralPath $sec -PathType Container)) { KullaniciYaz 'excel_klasor' $sec; Log "excel klasoru: $sec"; JsonYanit $ctx (ExcelDurum) } else { $d0 = ExcelDurum; $d0.iptal = $true; JsonYanit $ctx $d0 }
        continue
      }
      if ($yol -eq 'excel/kaydet' -and $m -eq 'POST') { JsonYanit $ctx (ExcelKaydet $ctx); continue }
      if ($yol -eq 'excel/ac' -and $m -eq 'POST') { JsonYanit $ctx (ExcelAc $ctx); continue }
      if ($yol -eq 'pastal') {
        $al = "$($ctx.Request.QueryString['alan'])"; $pa = "$($ctx.Request.QueryString['ad'])"
        if ($al -notmatch '^[^\\/:*?"<>|]+$' -or $al -match '\.\.' -or $pa -notmatch '^[^\\/:*?"<>|]+$') { JsonYanit $ctx @{ var = $false; mesaj = 'gecersiz ad' }; continue }
        try { JsonYanit $ctx (PastalBilgi $al $pa) } catch { JsonYanit $ctx @{ var = $false; mesaj = $_.Exception.Message } }; continue
      }
      if ($yol -eq 'gerber/tara') {
        if ($m -eq 'POST') { $b0 = $false; try { $b0 = TaramaBaslat $TARAMA } catch { Log ('tarama baslatilamadi: ' + $_.Exception.Message) }; JsonYanit $ctx @{ basladi = [bool]$b0 }; continue }
        $kb = Join-Path $Root 'kurulum_paketi\Kurulum.bat'
        $calis = [bool]($script:taramaP -and -not $script:taramaP.HasExited); $r0 = $(if ($calis) { $null } else { TaramaOku $TARAMA })
        JsonYanit $ctx @{ calisiyor = $calis; sure = $(if ($calis -and $script:taramaBas) { [int]((Get-Date) - $script:taramaBas).TotalSeconds } else { 0 }); rapor = $r0; oneri = (TaramaOneri $r0); ayar = (GerberAyar); kurulum = $(if (Test-Path $kb) { $kb } else { '' }) }; continue
      }
      if ($yol -eq 'gerber/uygula' -and $m -eq 'POST') {
        $r0 = TaramaOku $TARAMA; $deg = TaramaOneri $r0
        if (-not $deg) { JsonYanit $ctx @{ hata = 'Önce "Otomatik bul" ile ara.' }; continue }
        if (SurenIs) { JsonYanit $ctx @{ hata = 'Gerber''de süren bir iş var. Pastallar bitince dene.' }; continue }
        try { AyarYaz $Root $deg } catch { JsonYanit $ctx @{ hata = 'Ayarlar yazılamadı: ' + $_.Exception.Message }; continue }
        $A = Ayarlar $Root
        Remove-Item -Force (Join-Path $Root 'kopru\surucu.txt') -ErrorAction SilentlyContinue
        try { if ($script:kopru -and -not $script:kopru.HasExited) { Stop-Process -Id $script:kopru.Id -Force } } catch {}
        foreach ($p in KopruSurecleri) { try { Stop-Process -Id $p.ProcessId -Force } catch {} }
        if ($A.gerber) { KopruBaslat } else { $script:kopru = $null }
        Log ('gerber ayarlari otomatik bulunanlarla degisti: ' + (($deg.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' '))
        JsonYanit $ctx @{ ok = $true; ayar = (GerberAyar) }; continue
      }
      if ($yol -eq 'pencere') {   # masaustu simgesi / acilis ekrani soruyor: uygulama penceresi acik mi
        $ac = [bool]($son -and -not $script:kapanis)
        if ($ac -and ((Get-Date) - $son).TotalSeconds -ge 9) { $ac = @(UygulamaPencereleri).Count -gt 0 }   # nabiz gecikmis olabilir (simge durumunda): pencere gercekten var mi
        if ($script:kapanis) { $script:kapanis = (Get-Date).AddSeconds(15) }   # pencere az once kapandi ama yeniden aciliyor: program kapanmasin
        JsonYanit $ctx @{ acik = $ac; hazir = [bool]($ac -and $script:hazirT) }; continue
      }
      if ($yol -eq 'one-getir' -and $m -eq 'POST') { try { PencereOneGetir } catch { Log ('pencere one getirilemedi: ' + $_.Exception.Message) }; Yanit $ctx 200 $null $null; continue }
      if ($yol -eq 'tema' -and $m -eq 'POST') { $tv = "$($ctx.Request.QueryString['v'])"; if ($tv -in @('dark', 'light') -and (KullaniciOku)['tema'] -ne $tv) { try { KullaniciYaz 'tema' $tv } catch {} }; Yanit $ctx 200 $null $null; continue }
      if ($yol -eq 'konum') { $k = IpKonum; if ($k) { JsonYanit $ctx $k } else { JsonYanit $ctx @{ hata = 'konum bulunamadi' } }; continue }
      if ($yol -eq 'surum') { $y = YerelSurum $Root; JsonYanit $ctx @{ surum = "$($y.surum)"; tarih = "$($y.tarih)"; gerber = [bool]$A.gerber; otopastal = "$($A.otopastal)"; guncelleme = [bool]$A.guncelleme }; continue }
      if ($yol -eq 'guncelleme') {
        $y = YerelSurum $Root
        try { $u = UzakSurum ($ctx.Request.QueryString['taze'] -eq '1') } catch { JsonYanit $ctx @{ hata = 'Güncelleme sunucusuna ulaşılamadı: ' + $_.Exception.Message; yerel = "$($y.surum)" }; continue }
        if (-not $u) { JsonYanit $ctx @{ var = $false; yerel = "$($y.surum)"; kapali = $true }; continue }
        JsonYanit $ctx @{ var = ((SurumNo $u.surum) -gt (SurumNo $y.surum)); yerel = "$($y.surum)"; yeni = "$($u.surum)"; tarih = "$($u.tarih)"; notlar = @($u.notlar) }; continue
      }
      if ($yol -eq 'guncelle' -and $m -eq 'POST') {
        if (-not $A.guncelleme) { JsonYanit $ctx @{ hata = 'Güncelleme adresi ayarlı değil.' }; continue }
        if (SurenIs) { JsonYanit $ctx @{ hata = 'Gerber''de süren bir iş var. Pastallar bitince güncelle.' }; continue }
        try { $yeni = Guncelle } catch { Log ('guncelleme hatasi: ' + $_.Exception.Message); JsonYanit $ctx @{ hata = 'Güncellenemedi: ' + $_.Exception.Message }; continue }
        JsonYanit $ctx @{ ok = $true; surum = "$yeni" }
        YenidenBaslat
      }
      if ($yol -eq 'ping') { Yanit $ctx 200 ($utf8.GetBytes('ok')) 'text/plain'; continue }
      if ($yol -eq '') { $yol = 'uygulama.html' }
      if ($yol -match '\.\.' -or $yol -match ':') { Yanit $ctx 400 $null $null; continue }
      $dosya = Join-Path $Root ($yol -replace '/', '\')
      if ($m -eq 'GET') {
        if ((Test-Path $dosya -PathType Leaf) -and $tipler.ContainsKey([IO.Path]::GetExtension($dosya).ToLowerInvariant())) {
          $ext = [IO.Path]::GetExtension($dosya).ToLowerInvariant()
          $veri = $null; for ($i = 0; $i -lt 10 -and $null -eq $veri; $i++) { try { $fs = New-Object IO.FileStream($dosya, 'Open', 'Read', 'ReadWrite'); try { $ms = New-Object IO.MemoryStream; $fs.CopyTo($ms); $veri = $ms.ToArray() } finally { $fs.Close() } } catch { Start-Sleep -Milliseconds 100 } }
          if ($null -eq $veri) { Yanit $ctx 503 $null $null } elseif ($ext -eq '.woff2') { Yanit $ctx 200 $veri $tipler[$ext] 'max-age=31536000, immutable' } else { Yanit $ctx 200 $veri $tipler[$ext] }   # yazı tipi değişmez: her sayfa açılışında yeniden yüklenmesin
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
