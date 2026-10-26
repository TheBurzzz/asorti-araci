# Paketteki butun PowerShell dosyalarini calistirmadan dil bilgisi yonunden denetler.
$paket = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$log = Join-Path $paket 'kurulum\kontrol_log.txt'
$out = New-Object System.Collections.ArrayList; $hata = 0
[void]$out.Add("PowerShell $($PSVersionTable.PSVersion)  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $env:COMPUTERNAME")
foreach ($f in Get-ChildItem $paket -Recurse -Filter *.ps1) {
  $tok = $null; $err = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tok, [ref]$err)
  if ($err -and $err.Count) {
    $hata += $err.Count
    foreach ($e in $err) { [void]$out.Add("HATA $($f.FullName.Substring($paket.Length)):$($e.Extent.StartLineNumber):$($e.Extent.StartColumnNumber)  $($e.Message)") }
  } else { [void]$out.Add("tamam $($f.FullName.Substring($paket.Length))") }
}
[void]$out.Add("toplam hata: $hata")
$out | Set-Content -Path $log -Encoding UTF8
if ($hata) { $out | Write-Host; exit 1 }
exit 0
