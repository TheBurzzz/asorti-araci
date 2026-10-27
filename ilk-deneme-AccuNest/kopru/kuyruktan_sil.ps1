# Asorti Araci - Gerber kopru: bekleyen (henuz baslamamis) isleri OTOPASTAL kuyrugundan siler
param(
  [Parameter(Mandatory=$true)][string]$Requests,   # virgulle: 12,13,14
  [string]$Queue = '\\192.168.2.203\Users\Public\Gerber Technology\Queue\ultramrk.umq'
)
$ErrorActionPreference = 'Stop'
$enc = [Text.Encoding]::GetEncoding(28591)
$want = @($Requests -split ',' | Where-Object { $_ } | ForEach-Object { $_.Trim() })
$fs = $null
for ($i = 0; $i -lt 60; $i++) { try { $fs = [IO.File]::Open($Queue, 'Open', 'ReadWrite', 'None'); break } catch { Start-Sleep -Milliseconds 500 } }
if (-not $fs) { Write-Output "HATA: kuyruk dosyasi acilamadi"; exit 2 }
try {
  $len = [int]$fs.Length; $b = New-Object byte[] $len; $read = 0
  while ($read -lt $len) { $n = $fs.Read($b, $read, $len - $read); if ($n -le 0) { break }; $read += $n }
  if ($len -lt 8) { Write-Output 'TAMAM: kuyruk bos'; exit 0 }
  $state = [BitConverter]::ToUInt32($b, 0); $cnt = [BitConverter]::ToUInt32($b, 4)
  $p = 8; $spans = New-Object System.Collections.ArrayList
  for ($x = 0; $x -lt $cnt; $x++) {
    $start = $p; $tag = [BitConverter]::ToUInt16($b, $p); $p += 2; $body = $p
    if ($tag -eq 0xFFFF) { $p += 2; $ln = [BitConverter]::ToUInt16($b, $p); $p += 2 + $ln; $body = $p }
    $st = [BitConverter]::ToUInt32($b, $p + 4); $np = [BitConverter]::ToUInt32($b, $p + 8); $p += 12; $req = ''
    for ($k = 0; $k -lt 2 * $np; $k++) {
      $L = [int]$b[$p]; $p++; if ($L -eq 255) { $L = [int][BitConverter]::ToUInt16($b, $p); $p += 2 }
      $s = $enc.GetString($b, $p, $L); $p += $L
      if ($k % 2 -eq 0) { $key = $s } elseif ($key -eq 'RequestNum') { $req = $s }
    }
    [void]$spans.Add(@{ body = $body; end = $p; st = $st; req = $req })
  }
  $keep = @($spans | Where-Object { -not ($want -contains $_.req -and $_.st -eq 1) })
  $drop = $spans.Count - $keep.Count
  if ($drop -eq 0) { Write-Output 'TAMAM: silinecek bekleyen is yok'; exit 0 }
  $out = New-Object IO.MemoryStream
  $out.Write([BitConverter]::GetBytes([UInt32]$state), 0, 4); $out.Write([BitConverter]::GetBytes([UInt32]$keep.Count), 0, 4)
  $first = $true
  foreach ($e in $keep) {
    if ($first) { $out.Write([byte[]](0xFF, 0xFF, 1, 0, 11, 0), 0, 6); $nb = $enc.GetBytes('QueJobEntry'); $out.Write($nb, 0, $nb.Length); $first = $false }
    else { $out.Write([byte[]](1, 0x80), 0, 2) }
    $out.Write($b, $e.body, $e.end - $e.body)
  }
  $all = $out.ToArray(); $fs.Position = 0; $fs.SetLength(0); $fs.Write($all, 0, $all.Length); $fs.Flush()
  Write-Output ("TAMAM: {0} bekleyen is kuyruktan silindi" -f $drop)
} finally { $fs.Close() }
