' Asorti Araci - masaustu kisayolu bunu calistirir (siyah pencere acmadan).
' Once hizli acilisi dener (hizli_ac.vbs); o calismazsa eskisi gibi baslat.ps1 ile acar.
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
d = fso.GetParentFolderName(WScript.ScriptFullName)
rc = 1
If fso.FileExists(d & "\hizli_ac.vbs") Then rc = sh.Run("wscript.exe //B //NoLogo """ & d & "\hizli_ac.vbs""", 0, True)
If rc <> 0 Then sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & d & "\baslat.ps1""", 0, False
