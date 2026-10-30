# Asorti Araci - acik olan uygulama penceresini one getirir (simge durumundaysa eski boyutuna dondurur).
# Pencere bulunursa 0 ile, bulunamazsa (tarayici penceresiz kalmissa) 1 ile cikar: o zaman baslat.vbs yeni pencere acar.
param([int]$Id)
try {
  $p = Get-Process -Id $Id -ErrorAction Stop; $h = $p.MainWindowHandle
  if ($h -eq [IntPtr]::Zero) { exit 1 }
  Add-Type -Namespace AsortiPencere -Name P -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(System.IntPtr h, int c); [DllImport("user32.dll")] public static extern bool SetForegroundWindow(System.IntPtr h); [DllImport("user32.dll")] public static extern bool IsIconic(System.IntPtr h);'
  if ([AsortiPencere.P]::IsIconic($h)) { [void][AsortiPencere.P]::ShowWindowAsync($h, 9) }
  [void][AsortiPencere.P]::SetForegroundWindow($h)
  exit 0
} catch { exit 1 }
