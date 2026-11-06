# Ölçü Tablosu Aracı - tek tuşla tarama (Eleman programı çalıştırır; elle de denenebilir: tarama_dene.bat)
# Windows'un kendi tarama altyapısı (WIA) ile Epson L3260'tan (Wi-Fi) bir sayfa tarar, JPEG olarak kaydeder.
# Sonucu -Cikti dosyasına JSON olarak yazar: {"ok":true,"resim":"...","tur":"image/jpeg",...} ya da {"hata":"...","kod":"0x..."}
# Her ikisinde de "adimlar": ne yapıldı, nerede ne oldu (sorun çıkarsa nedenini görmek için).
#   -Liste : sadece bağlı tarayıcıları listeler {"ok":true,"tarayicilar":[{"id":"...","ad":"..."}]}
param(
  [Parameter(Mandatory = $true)][string]$Cikti,
  [string]$Resim = "",
  [int]$Dpi = 300,
  [ValidateSet("renkli", "gri")][string]$Renk = "renkli",
  [string]$Cihaz = "",
  [string]$CihazB64 = "",      # program cihaz kimliğini base64 ile verir (kimlikte ters bölü var)
  [switch]$Liste
)
$ErrorActionPreference = 'Stop'
if ($CihazB64) { try { $Cihaz = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($CihazB64)) } catch {} }
# dikkat: PowerShell'de değişken adları büyük/küçük harf ayırmaz ($liste = $Liste). Bu yüzden yerel adlar farklı.
$script:adimlar = New-Object System.Collections.Generic.List[string]
function Adim([string]$s) { $script:adimlar.Add($s) }
function Yaz($o) {
  $o['adimlar'] = @($script:adimlar)
  $j = $o | ConvertTo-Json -Compress -Depth 5
  [System.IO.File]::WriteAllText($Cikti, $j, (New-Object System.Text.UTF8Encoding($false)))
}
# COM hatası PowerShell'de sarılı gelir ("Exception calling ..."): asıl hata en içtedir
function IcHata($kayit) { $x = $kayit.Exception; while ($x.InnerException) { $x = $x.InnerException }; return $x }
function HataYazi($x) { return ('{0} (0x{1:X8})' -f $x.Message, $x.HResult) }
# WIA hata kodları -> anlaşılır Türkçe
function HataMetni([int]$hr, [string]$m) {
  switch ('0x{0:X8}' -f $hr) {
    '0x80210006' { return 'Tarayıcı meşgul. Başka bir tarama bitince tekrar bas.' }
    '0x80210005' { return 'Tarayıcı kapalı ya da ağda görünmüyor. Epson açık ve Wi-Fi bağlı mı?' }
    '0x80210015' { return 'Tarayıcı bulunamadı. Epson açık ve bu bilgisayarla aynı ağda mı?' }
    '0x80210003' { return 'Tarayıcıda kağıt yok.' }
    '0x8021000A' { return 'Tarayıcıyla bağlantı koptu. Tekrar dene.' }
    '0x80210064' { return 'Tarama iptal edildi.' }
    '0x80210002' { return 'Tarayıcı kapağı açık ya da kağıt sıkıştı.' }
    default { return "Tarama yapılamadı: $m" }
  }
}
$JPEG = '{B96B3CAE-0728-11D3-9D7B-0000F81EF32E}'
$PNG = '{B96B3CAF-0728-11D3-9D7B-0000F81EF32E}'
$TIFF = '{B96B3CB1-0728-11D3-9D7B-0000F81EF32E}'
try {
  $dm = New-Object -ComObject WIA.DeviceManager
  $cihazlar = @()
  foreach ($di in $dm.DeviceInfos) {
    if ($di.Type -ne 1) { continue }   # 1 = tarayıcı
    $ad = ''
    try { $ad = [string]$di.Properties.Item('Name').Value } catch {}
    $cihazlar += [pscustomobject]@{ id = [string]$di.DeviceID; ad = $ad }
  }
  if ($Liste) { Yaz @{ ok = $true; tarayicilar = @($cihazlar) }; exit 0 }
  if ($cihazlar.Count -eq 0) { Yaz @{ hata = 'Tarayıcı bulunamadı. Epson açık ve bu bilgisayarla aynı ağda mı? (Windows Ayarlar > Yazıcılar ve tarayıcılar listesinde görünmeli.)' }; exit 2 }

  # seçili tarayıcı; yoksa adında EPSON/L3260 geçen; o da yoksa ilki
  $sec = $null
  if ($Cihaz) { $sec = $cihazlar | Where-Object { $_.id -eq $Cihaz } | Select-Object -First 1 }
  if (-not $sec) { $sec = $cihazlar | Where-Object { $_.ad -match 'EPSON|L3260' } | Select-Object -First 1 }
  if (-not $sec) { $sec = $cihazlar[0] }
  Adim ('tarayıcı: ' + $sec.ad)
  $info = $null
  foreach ($di in $dm.DeviceInfos) { if ([string]$di.DeviceID -eq $sec.id) { $info = $di; break } }
  $dev = $info.Connect()
  $oge = $dev.Items.Item(1)          # L3260'ta tek kaynak: cam (flatbed)

  function Ayarla($ozellikler, [int]$no, $deger) {
    foreach ($p in $ozellikler) { if ($p.PropertyID -eq $no) { try { $p.Value = $deger; return 'tamam' } catch { return 'olmadı' } } }
    return 'yok'
  }
  # 6146 niyet (1 renkli, 2 gri) · 6147/6148 çözünürlük · 6149..6152 alan (A4)
  $a1 = Ayarla $oge.Properties 6146 $(if ($Renk -eq 'gri') { 2 } else { 1 })
  $a2 = Ayarla $oge.Properties 6147 $Dpi
  $a3 = Ayarla $oge.Properties 6148 $Dpi
  $a4 = Ayarla $oge.Properties 6149 0
  $a5 = Ayarla $oge.Properties 6150 0
  $a6 = Ayarla $oge.Properties 6151 ([int][math]::Floor(8.27 * $Dpi))
  $a7 = Ayarla $oge.Properties 6152 ([int][math]::Floor(11.69 * $Dpi))
  Adim ("ayarlar: renk=$a1 dpi=$a2/$a3 alan=$a4/$a5/$a6/$a7")

  # 1) tarama: iki yol var — doğrudan aktarım ya da Windows'un tarama penceresiyle aktarım.
  #    Bu bilgisayarda hangisi çalıştıysa hatırlanır, sonraki taramalar doğrudan onunla yapılır (boşuna iki kez taramaz).
  $yontemDosya = ''
  try { $yontemDosya = Join-Path $env:LOCALAPPDATA 'OlcuTablosu\tarama_yontemi.txt' } catch {}
  $once = ''
  try { if ($yontemDosya -and (Test-Path -LiteralPath $yontemDosya)) { $once = ([string](Get-Content -LiteralPath $yontemDosya -Raw)).Trim() } } catch {}
  $sira = @('dogrudan', 'pencere')
  if ($once -eq 'pencere') { $sira = @('pencere', 'dogrudan') }
  $img = $null; $sonHata = $null; $calisan = ''
  foreach ($yol in $sira) {
    try {
      if ($yol -eq 'dogrudan') { $img = $oge.Transfer($JPEG) }
      else { $pencere = New-Object -ComObject WIA.CommonDialog; $img = $pencere.ShowTransfer($oge.PSObject.BaseObject, $JPEG, $false) }
      if ($img) { $calisan = $yol; Adim ("aktarım ($yol): tamam"); break }
    }
    catch { $sonHata = $_; Adim ("aktarım ($yol): " + (HataYazi (IcHata $_))) }
  }
  if (-not $img) { if ($sonHata) { throw $sonHata } else { throw 'Tarayıcıdan resim gelmedi.' } }
  if ($calisan -ne $once -and $yontemDosya) {
    try { New-Item -ItemType Directory -Force -Path (Split-Path $yontemDosya) | Out-Null; Set-Content -LiteralPath $yontemDosya -Value $calisan -Encoding ASCII } catch {}
  }
  # 2) gelen biçim (sürücü JPEG yerine BMP/PNG verebilir)
  $bicim = ''
  try { $bicim = [string]$img.FormatID } catch {}   # -eq büyük/küçük harf ayırmaz
  $uz = '.bmp'
  if ($bicim -eq $JPEG) { $uz = '.jpg' } elseif ($bicim -eq $PNG) { $uz = '.png' } elseif ($bicim -eq $TIFF) { $uz = '.tif' }
  Adim ('gelen biçim: ' + $uz)
  if (-not $Resim) { $Resim = Join-Path $env:TEMP 'olcu_tarama.jpg' }
  if (Test-Path -LiteralPath $Resim) { Remove-Item -LiteralPath $Resim -Force }
  $tur = 'image/jpeg'
  if ($uz -eq '.jpg') {
    $img.SaveFile($Resim)
  }
  else {
    # 3) JPEG değilse: olduğu gibi kaydet, sonra JPEG'e çevir (önce .NET, olmazsa WIA)
    $ham = [System.IO.Path]::ChangeExtension($Resim, $uz)
    if ($ham -eq $Resim) { $ham = $Resim + $uz }
    if (Test-Path -LiteralPath $ham) { Remove-Item -LiteralPath $ham -Force }
    $img.SaveFile($ham)
    $oldu = $false
    try {
      # .NET (System.Drawing) ile; kod ancak gerektiğinde derlenir (System.Drawing olmayan yerde betiği bozmasın)
      $netCevir = [scriptblock]::Create(@'
param($kaynak, $hedef)
Add-Type -AssemblyName System.Drawing
$bm = [System.Drawing.Image]::FromFile($kaynak)
try {
  $kodlayici = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
  $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
  $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]92)
  $bm.Save($hedef, $kodlayici, $ep)
}
finally { $bm.Dispose() }
'@)
      & $netCevir $ham $Resim
      $oldu = $true; Adim 'JPEG''e çevrildi (.NET)'
    }
    catch { Adim ('.NET ile çevirme: ' + (HataYazi (IcHata $_))) }
    if (-not $oldu) {
      try {
        $ip = New-Object -ComObject WIA.ImageProcess
        $ip.Filters.Add($ip.FilterInfos.Item('Convert').FilterID)
        $ip.Filters.Item(1).Properties.Item('FormatID').Value = $JPEG
        $ip.Filters.Item(1).Properties.Item('Quality').Value = 92
        $j = $ip.Apply($img.PSObject.BaseObject)   # COM nesnesi PowerShell sarmalı olmadan verilir
        $j.SaveFile($Resim)
        $oldu = $true; Adim 'JPEG''e çevrildi (WIA)'
      }
      catch { Adim ('WIA ile çevirme: ' + (HataYazi (IcHata $_))) }
    }
    if ($oldu) { Remove-Item -LiteralPath $ham -Force -ErrorAction SilentlyContinue }
    else {
      # çevrilemediyse olduğu gibi gönder (program BMP/PNG'yi de okur)
      $Resim = $ham
      $tur = @{ '.png' = 'image/png'; '.bmp' = 'image/bmp'; '.tif' = 'image/tiff' }[$uz]
      Adim 'çevrilemedi: olduğu gibi gönderiliyor'
    }
  }
  Yaz @{ ok = $true; resim = $Resim; tur = $tur; cihaz = $sec.ad; dpi = $Dpi }
  exit 0
}
catch {
  $x = IcHata $_
  $hr = 0; try { $hr = $x.HResult } catch {}
  Yaz @{ hata = (HataMetni $hr $x.Message); kod = ('0x{0:X8}' -f $hr) }
  exit 1
}
