' Asorti Araci - hizli acilis (baslat.vbs calistirir). Basariyla biterse 10 doner; donmezse baslat.vbs eski yoldan acar.
' Tiklar tiklamaz acilis ekrani (AsortiAcilis.exe) uygulama penceresinin acilacagi yeri ayni gorunumle kaplar; arka plandaki
' program ve uygulama penceresi onun arkasinda acilir, ilk sayfa ekrana cizilince acilis ekrani yumusakca solar.
' Uygulama zaten aciksa yeni pencere acmaz, acik olani one getirir (simge durumundaysa eski boyutuna dondurur);
' acilmaktaysa ikinci kez acmaz.
Option Explicit
On Error Resume Next
Const TAMAM = 10
Dim sh, fso, d, kok, ayar, port, tarayici, profil, tema, kilit, k, edge, adaylar, a, url, hazir, acik, mesgul, x, y, t0, st, rt, yas, ad, ekran, i
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
d = fso.GetParentFolderName(WScript.ScriptFullName)
kok = fso.GetParentFolderName(d)
profil = kok & "\profil"
ad = "Asorti Ara" & ChrW(305)   ' uygulama penceresinin (ve acilis ekraninin) basligi

Function Oku(f)
  On Error Resume Next
  Dim t
  Oku = ""
  If fso.FileExists(f) Then
    Set t = fso.OpenTextFile(f, 1, False, 0)
    If Not t.AtEndOfStream Then Oku = t.ReadAll
    t.Close
  End If
End Function

Function Al(metin, anahtar)
  On Error Resume Next
  Dim r, m
  Al = ""
  Set r = New RegExp
  r.IgnoreCase = True
  r.Pattern = """" & anahtar & """\s*:\s*(""((?:[^""\\]|\\.)*)""|(\d+))"
  Set m = r.Execute(metin)
  If m.Count > 0 Then
    If m(0).SubMatches(2) <> "" Then
      Al = m(0).SubMatches(2)
    Else
      Al = Replace(m(0).SubMatches(1), "\\", "\")
    End If
  End If
End Function

' bu baslikta bir pencere varsa one getirir; varsa True
Function Etkin(baslik)
  On Error Resume Next
  Dim r
  r = False
  r = sh.AppActivate(baslik)
  If Err.Number <> 0 Then r = False
  Err.Clear
  Etkin = (r = True)
End Function

' acilis ekrani (bu bilgisayarda derlenmis AsortiAcilis.exe): hemen gorunur, uygulama hazir olunca kendiliginden solar
Function Acilis()
  On Error Resume Next
  Dim e
  Acilis = False
  e = d & "\AsortiAcilis.exe"
  If Not fso.FileExists(e) Then Exit Function
  Err.Clear
  sh.Run """" & e & """ p=" & port & " t=" & tema, 1, False
  If Err.Number = 0 Then Acilis = True
  Err.Clear
End Function

ayar = Oku(kok & "\ayarlar.json")
port = Al(ayar, "port")
If port = "" Then port = "8642"
tarayici = Al(ayar, "tarayici")
tema = Al(Oku(kok & "\kullanici.json"), "tema")
If tema <> "dark" Then tema = "light"

' 1) arka plandaki program calisiyor mu, uygulama penceresi acik mi
hazir = False: acik = False: mesgul = False: st = 0: rt = ""
Err.Clear
t0 = Timer
Set x = CreateObject("MSXML2.ServerXMLHTTP.6.0")
x.setTimeouts 200, 200, 1000, 3000
x.Open "GET", "http://localhost:" & port & "/pencere", False
x.Send
If Err.Number = 0 Then st = x.Status: rt = x.responseText
If Err.Number <> 0 Then
  st = 0
  If Abs(Timer - t0) > 1.5 Then mesgul = True   ' baglandi ama cevap gecikti: program calisiyor, baska bir isle mesgul
End If
Err.Clear
hazir = (st = 200)
acik = hazir And (InStr(1, rt, """acik"":true", 1) > 0)

' 2) zaten acik: yeni pencere acma, acik olani one getir
If acik Then
  Set y = CreateObject("MSXML2.ServerXMLHTTP.6.0")
  y.setTimeouts 200, 200, 1000, 3000
  y.Open "POST", "http://localhost:" & port & "/one-getir", False
  y.Send "{}"
  Err.Clear
  If Etkin(ad) Then WScript.Quit TAMAM
  ' pencere bulunamadi (tarayici beklenmedik kapanmis olabilir): normal acilisa devam
End If
If mesgul Then
  If Etkin(ad) Then WScript.Quit TAMAM
End If

' 3) az once acilmaya baslandiysa ikinci kez acma (acilis ekrani beklerken bu isareti tazeler, pencere acilinca silinir)
kilit = kok & "\kopru\log\acilis.txt"
yas = -1
If fso.FileExists(kilit) Then yas = DateDiff("s", fso.GetFile(kilit).DateLastModified, Now)
If Err.Number <> 0 Then yas = -1
Err.Clear
If yas >= 0 And yas < 25 Then
  If Not Etkin(ad) Then Acilis   ' acilis ekrani kapatilmissa yeniden goster
  WScript.Quit TAMAM
End If
If fso.FolderExists(kok & "\kopru\log") Then
  Set k = fso.CreateTextFile(kilit, True)
  k.WriteLine Now
  k.Close
End If
Err.Clear

' 4) acilis ekrani
ekran = Acilis()

' 5) arka plandaki program (zaten calisiyorsa yenisi kendiliginden kapanir)
If Not hazir Then sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & d & "\sunucu.ps1""", 0, False
Err.Clear

' acilis ekrani gorunene kadar bekle (en cok ~0.8 sn) ki uygulama penceresi onun arkasinda acilsin
If ekran Then
  For i = 1 To 20
    If InStr(1, Oku(kilit), "gorundu", 1) > 0 Then Exit For
    WScript.Sleep 40
  Next
End If
Err.Clear

' 6) uygulama penceresi: program hazirsa dogrudan uygulama, degilse ayni gorunumdeki bekleme sayfasi (program hazir olunca kendiliginden gecer)
edge = ""
adaylar = Array(tarayici, sh.ExpandEnvironmentStrings("%ProgramFiles(x86)%") & "\Microsoft\Edge\Application\msedge.exe", sh.ExpandEnvironmentStrings("%ProgramFiles%") & "\Microsoft\Edge\Application\msedge.exe", _
  sh.ExpandEnvironmentStrings("%ProgramFiles%") & "\Google\Chrome\Application\chrome.exe", sh.ExpandEnvironmentStrings("%ProgramFiles(x86)%") & "\Google\Chrome\Application\chrome.exe", sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Google\Chrome\Application\chrome.exe")
For Each a In adaylar
  If a <> "" And fso.FileExists(a) Then edge = a: Exit For
Next
If edge = "" Then WScript.Quit 3   ' tarayici bulunamadi: baslat.vbs eski yoldan acar
If hazir Then
  url = "http://localhost:" & port & "/"
Else
  url = "file:///" & Replace(Replace(d, "\", "/"), " ", "%20") & "/acilis.html?p=" & port & "&t=" & tema
End If
Err.Clear
sh.Run """" & edge & """ --app=""" & url & """ --user-data-dir=""" & profil & """ --no-first-run --no-default-browser-check --start-maximized --disable-background-timer-throttling --disable-renderer-backgrounding --disable-backgrounding-occluded-windows", 1, False
If Err.Number <> 0 Then WScript.Quit 2
WScript.Quit TAMAM
