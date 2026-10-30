' Asorti Araci - hizli acilis (baslat.vbs calistirir; burada bir sorun olursa baslat.vbs eski yoldan acar).
' Hizli acilis: pencere hemen acilir (gerekirse kisa bir "aciliyor" ekraniyla), arka plandaki program ayni anda baslar.
' Uygulama zaten aciksa ya da su an aciliyorsa yeni pencere acmaz, acik olani one getirir.
Option Explicit
On Error Resume Next
Dim sh, fso, d, kok, ayar, port, tarayici, profil, tema, kilit, k, edge, adaylar, a, url, hazir, x, pid
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
d = fso.GetParentFolderName(WScript.ScriptFullName)
kok = fso.GetParentFolderName(d)
profil = kok & "\profil"

Function Oku(f)
  Oku = ""
  If fso.FileExists(f) Then
    Dim t: Set t = fso.OpenTextFile(f, 1, False, 0)
    If Not t.AtEndOfStream Then Oku = t.ReadAll
    t.Close
  End If
End Function
Function Al(metin, anahtar)
  Dim r, m: Al = ""
  Set r = New RegExp: r.IgnoreCase = True
  r.Pattern = """" & anahtar & """\s*:\s*(""((?:[^""\\]|\\.)*)""|(\d+))"
  Set m = r.Execute(metin)
  If m.Count > 0 Then
    If m(0).SubMatches(2) <> "" Then Al = m(0).SubMatches(2) Else Al = Replace(m(0).SubMatches(1), "\\", "\")
  End If
End Function
' bu kurulumun profil klasoruyle acilmis tarayici (ana surec) varsa kimligini dondurur
Function AcikPencere()
  Dim w, ps, p, c: AcikPencere = 0
  Set w = GetObject("winmgmts:\\.\root\cimv2")
  Set ps = w.ExecQuery("SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name='msedge.exe' OR Name='chrome.exe'")
  For Each p In ps
    c = "" & p.CommandLine
    If InStr(1, c, profil, 1) > 0 And InStr(1, c, "--type=", 1) = 0 Then AcikPencere = p.ProcessId: Exit Function
  Next
End Function

' 1) zaten acik: one getir (simge durumundaysa eski boyutuna dondur)
pid = AcikPencere()
If pid <> 0 Then
  sh.AppActivate pid
  If sh.Run("powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & d & "\one_getir.ps1"" -Id " & pid, 0, True) = 0 Then WScript.Quit
End If
' 2) birkac saniye once acilmaya baslandiysa (pencere daha gelmediyse) ikinci kez acma
kilit = kok & "\kopru\log\acilis.txt"
If fso.FileExists(kilit) Then
  If DateDiff("s", fso.GetFile(kilit).DateLastModified, Now) < 8 Then WScript.Quit
End If
If fso.FolderExists(kok & "\kopru\log") Then Set k = fso.CreateTextFile(kilit, True): k.WriteLine Now: k.Close

ayar = Oku(kok & "\ayarlar.json")
port = Al(ayar, "port"): If port = "" Then port = "8642"
tarayici = Al(ayar, "tarayici")
tema = Al(Oku(kok & "\kullanici.json"), "tema"): If tema <> "dark" Then tema = "light"

' 3) arka plandaki program (zaten calisiyorsa yenisi kendiliginden kapanir)
hazir = False
Err.Clear
Set x = CreateObject("MSXML2.ServerXMLHTTP.6.0")
x.setTimeouts 300, 300, 300, 300
x.Open "GET", "http://localhost:" & port & "/ping", False
x.Send
If Err.Number = 0 Then
  If x.Status = 200 Then hazir = True
End If
Err.Clear
If Not hazir Then sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & d & "\sunucu.ps1""", 0, False

' 4) pencere: program hazirsa dogrudan uygulama, degilse "aciliyor" ekrani (program hazir olunca kendiliginden uygulamaya gecer)
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
WScript.Quit 0
