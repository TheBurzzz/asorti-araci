# Asorti Araci - Gerber kopru: pastallari AccuNest (OTOPASTAL) kuyruguna ekler
param(
  [Parameter(Mandatory=$true)][string]$Area,
  [Parameter(Mandatory=$true)][string[]]$Markers,
  [string]$Queue = '\\192.168.2.203\Users\Public\Gerber Technology\Queue\ultramrk.umq',
  [string]$Device = 'k:',
  [int]$Minutes = 1
)
$ErrorActionPreference = 'Stop'
$enc = [Text.Encoding]::GetEncoding(28591)
$inv = [Globalization.CultureInfo]::InvariantCulture

# kuyruk dosyasini tek basimiza ac (QueueSubmit de boyle kilitliyor)
$fs = $null
for ($i = 0; $i -lt 60; $i++) {
  try { $fs = [IO.File]::Open($Queue, 'OpenOrCreate', 'ReadWrite', 'None'); break }
  catch { Start-Sleep -Milliseconds 500 }
}
if (-not $fs) { Write-Output "HATA: kuyruk dosyasi acilamadi: $Queue"; exit 2 }
try {
  $len = [int]$fs.Length
  $b = New-Object byte[] $len
  $read = 0; while ($read -lt $len) { $n = $fs.Read($b, $read, $len - $read); if ($n -le 0) { break }; $read += $n }

  if ($len -lt 8) { $b = New-Object byte[] 8; $len = 8 }   # kuyruk dosyasi silinmisse yeni bos kuyruk
  $state = [BitConverter]::ToUInt32($b, 0)
  $cnt = [BitConverter]::ToUInt32($b, 4)
  $script:p = 8; $maxJob = 0; $maxReq = 0
  function ReadStr {
    $L = [int]$b[$script:p]; $script:p++
    if ($L -eq 255) { $L = [int][BitConverter]::ToUInt16($b, $script:p); $script:p += 2 }
    $s = $enc.GetString($b, $script:p, $L); $script:p += $L; return $s
  }
  for ($e = 0; $e -lt $cnt; $e++) {
    $tag = [BitConverter]::ToUInt16($b, $script:p); $script:p += 2
    if ($tag -eq 0xFFFF) { $script:p += 2; $ln = [BitConverter]::ToUInt16($b, $script:p); $script:p += 2 + $ln }
    $job = [BitConverter]::ToUInt32($b, $script:p); $np = [BitConverter]::ToUInt32($b, $script:p + 8); $script:p += 12
    if ($job -gt $maxJob) { $maxJob = $job }
    for ($k = 0; $k -lt $np; $k++) {
      $key = ReadStr; $val = ReadStr
      if ($key -eq 'RequestNum') { $r = [int]$val; if ($r -gt $maxReq) { $maxReq = $r } }
    }
  }
  $end = $script:p

  $ms = New-Object IO.MemoryStream
  $bw = New-Object IO.BinaryWriter($ms)
  function WriteStr([string]$s) {
    $x = $enc.GetBytes($s)
    if ($x.Length -lt 255) { $bw.Write([byte]$x.Length) } else { $bw.Write([byte]255); $bw.Write([UInt16]$x.Length) }
    $bw.Write($x)
  }
  function WriteEntry([UInt32]$job, $d) {
    if ($script:first) {
      $bw.Write([UInt16]0xFFFF); $bw.Write([UInt16]1); $bw.Write([UInt16]11); $bw.Write($enc.GetBytes('QueJobEntry'))
      $script:first = $false
    } else { $bw.Write([UInt16]0x8001) }
    $bw.Write([UInt32]$job); $bw.Write([UInt32]1); $bw.Write([UInt32]$d.Count)
    $keys = [string[]]@($d.Keys); [Array]::Sort($keys, [StringComparer]::Ordinal)
    foreach ($k in $keys) { WriteStr $k; WriteStr ([string]$d[$k]) }
  }
  $script:first = ($cnt -eq 0)
  $station = $env:COMPUTERNAME.ToLowerInvariant()
  $added = 0
  foreach ($m in $Markers) {
    $maxReq++; $init = $maxJob; $fj = $maxJob + 1; $cj = $maxJob + 2; $maxJob = $cj
    $base = @{
      'RequestNum' = [string]$maxReq; 'area' = $Area.ToLowerInvariant(); 'cadsystem' = 'accumark'; 'checkoriglength' = '0';
      'device' = $Device.ToLowerInvariant(); 'disregardunplaced' = '0'; 'goal' = '100'; 'initjobid' = [string]$init;
      'marker' = $m.ToLowerInvariant(); 'mode' = 'full'; 'nest' = '1'; 'override_flags' = '0'; 'packnest' = '0';
      'priority' = 'normal'; 'returnpickedpieces' = '0'; 'station' = $station;
      'submittime' = (Get-Date).ToOADate().ToString('F6', $inv); 'symmetricmatching' = '0';
      'timeunits' = 'minutes'; 'unfixnest' = '1'; 'unit_cost' = '1.000000'
    }
    $f = $base.Clone(); $f['type'] = 'fraun'; $f['timelimit'] = [string]$Minutes; $f['scaletimelimit'] = '0.99'
    $c = $base.Clone(); $c['type'] = 'commit'; $c['timelimit'] = '0'; $c['prereq1'] = [string]$fj; $c['prereqcount'] = '1'
    WriteEntry $fj $f; WriteEntry $cj $c; $added += 2
    Write-Output ("EKLENDI: {0} (is {1}, {2} dk)" -f $m.ToUpperInvariant(), $maxReq, $Minutes)
  }
  $bw.Flush(); $new = $ms.ToArray()

  $out = New-Object IO.MemoryStream
  $out.Write([BitConverter]::GetBytes([UInt32]$state), 0, 4)
  $out.Write([BitConverter]::GetBytes([UInt32]($cnt + $added)), 0, 4)
  $out.Write($b, 8, $end - 8)
  $out.Write($new, 0, $new.Length)
  $all = $out.ToArray()
  $fs.Position = 0; $fs.SetLength(0); $fs.Write($all, 0, $all.Length); $fs.Flush()
  Write-Output ("TAMAM: kuyrukta {0} kayit vardi, {1} eklendi." -f $cnt, $added)
} finally { $fs.Close() }
