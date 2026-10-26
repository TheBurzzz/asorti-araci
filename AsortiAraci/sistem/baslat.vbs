' Asorti Araci - masaustu kisayolu bunu calistirir (siyah pencere acmadan)
Set fso = CreateObject("Scripting.FileSystemObject")
d = fso.GetParentFolderName(WScript.ScriptFullName)
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & d & "\baslat.ps1""", 0, False
