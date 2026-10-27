$L = 'C:\AccuNest\kopru\log\teshis.txt'
function W($s) { Add-Content -Path $L -Value ((Get-Date -Format 'HH:mm:ss.fff') + ' ' + $s); Write-Host $s }
Set-Content -Path $L -Value 'teshis'
$Q = '\\192.168.2.203\Users\Public\Gerber Technology\Queue\ultramrk.umq'
W 'test-path basliyor'; W ('test-path: ' + (Test-Path $Q))
W 'readallbytes basliyor'; try { $b = [IO.File]::ReadAllBytes($Q); W ('okundu bayt: ' + $b.Length) } catch { W ('HATA: ' + $_.Exception.Message) }
W 'copy-item basliyor'; try { Copy-Item -Force $Q 'C:\AccuNest\kopru\log\kuyruk_teshis.umq'; W 'kopyalandi' } catch { W ('HATA: ' + $_.Exception.Message) }
W 'kopru.ps1 icindeki ReadQueue deneniyor'
$src = Get-Content 'C:\AccuNest\kopru\kopru.ps1' -Raw
$i = $src.IndexOf('function ReadQueue'); $j = $src.IndexOf('function BatchTable')
$enc = [Text.Encoding]::GetEncoding(28591); $QUEUE = $Q
Invoke-Expression $src.Substring($i, $j - $i)
try { $E = ReadQueue; W ('ReadQueue kayit: ' + @($E).Count) } catch { W ('HATA: ' + $_.Exception.Message) }
W 'bitti'
