# Asorti Araci - klasor secme penceresi (sunucu cagirir). Dosya: ilk satirda baslangic klasoru; secilen klasor ayni dosyaya yazilir.
param([string]$Dosya)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$bas = ''; try { $bas = [IO.File]::ReadAllText($Dosya, [Text.Encoding]::UTF8).Trim() } catch {}
$d = New-Object System.Windows.Forms.FolderBrowserDialog
$d.Description = 'Excel dosyalarının kaydedileceği klasörü seç'
$d.ShowNewFolderButton = $true
if ($bas -and (Test-Path -LiteralPath $bas -PathType Container)) { $d.SelectedPath = $bas }
# pencere Asorti Araci'nin arkasinda kalmasin diye gorunmez, en ustte duran bir sahip pencere
$f = New-Object System.Windows.Forms.Form
$f.TopMost = $true; $f.ShowInTaskbar = $false; $f.FormBorderStyle = 'None'; $f.Opacity = 0
$f.StartPosition = 'CenterScreen'; $f.Size = New-Object System.Drawing.Size(1, 1)
$f.Show(); $f.Activate()
$sonuc = $d.ShowDialog($f)
$f.Close()
$cikti = if ($sonuc -eq [System.Windows.Forms.DialogResult]::OK) { $d.SelectedPath } else { '' }
[IO.File]::WriteAllText($Dosya, $cikti, (New-Object Text.UTF8Encoding($false)))
