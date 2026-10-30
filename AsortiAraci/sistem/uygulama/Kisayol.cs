// Asorti Aracı - masaüstü ve Başlat menüsündeki bu kurulumun kısayollarını doğrudan uygulamaya bağlar
// (eskiden baslat.vbs'yi açıyorlardı). Böylece tıklayınca uygulama araya hiçbir şey girmeden açılır ve görev çubuğuna
// sabitlenebilir. Başka programların kısayollarına dokunmaz.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;

namespace AsortiAraci
{
    static class Kisayol
    {
        public static void Guncelle(string exe)
        {
            if (!Yer.Windows) return;
            try
            {
                List<string> yerler = new List<string>();
                yerler.Add(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory));
                yerler.Add(Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory));
                yerler.Add(Yer.Kok);
                string ad = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                if (ad.Length > 0)
                {
                    yerler.Add(Path.Combine(ad, @"Microsoft\Windows\Start Menu\Programs"));
                    yerler.Add(Path.Combine(ad, @"Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"));
                }
                string od = Environment.GetEnvironmentVariable("OneDrive");
                if (!string.IsNullOrEmpty(od)) yerler.Add(Path.Combine(od, "Desktop"));
                Type t = Type.GetTypeFromProgID("WScript.Shell");
                if (t == null) return;
                object sh = Activator.CreateInstance(t);
                int n = 0;
                HashSet<string> bakilan = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                try
                {
                    foreach (string y in yerler)
                    {
                        if (string.IsNullOrEmpty(y) || !bakilan.Add(y) || !Directory.Exists(y)) continue;
                        foreach (string l in Directory.GetFiles(y, "*.lnk"))
                        {
                            object k = null;
                            try
                            {
                                k = t.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, sh, new object[] { l });
                                string hedef = Al(k, "TargetPath"), arg = Al(k, "Arguments"), simge = Al(k, "IconLocation");
                                bool vbs = arg.IndexOf("baslat.vbs", StringComparison.OrdinalIgnoreCase) >= 0 && arg.IndexOf(Yer.Kok, StringComparison.OrdinalIgnoreCase) >= 0;
                                bool bizim = string.Equals(hedef, exe, StringComparison.OrdinalIgnoreCase);
                                if (!vbs && !bizim) continue;   // bu kurulumun kısayolu değil
                                if (bizim && arg.Length == 0 && simge.StartsWith(exe, StringComparison.OrdinalIgnoreCase)) continue;   // zaten bağlı
                                Ver(k, "TargetPath", exe);
                                Ver(k, "Arguments", "");
                                Ver(k, "WorkingDirectory", Yer.Sistem);
                                Ver(k, "IconLocation", exe + ",0");
                                t.InvokeMember("Save", BindingFlags.InvokeMethod, null, k, null);
                                n++;
                            }
                            catch { }
                            finally { if (k != null) { try { Marshal.ReleaseComObject(k); } catch { } } }
                        }
                    }
                }
                finally { try { Marshal.ReleaseComObject(sh); } catch { } }
                if (n > 0)
                {
                    try
                    {
                        string ie = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "ie4uinit.exe");
                        if (File.Exists(ie)) { ProcessStartInfo si = new ProcessStartInfo(ie, "-show"); si.UseShellExecute = false; si.CreateNoWindow = true; Process.Start(si); }
                    }
                    catch { }
                    Kayit.Yaz("kisayollar uygulamaya baglandi (" + n + " kisayol)");
                }
            }
            catch (Exception ex) { Kayit.Yaz("kisayollar guncellenemedi: " + ex.Message); }
        }

        static string Al(object o, string ad) { return Convert.ToString(o.GetType().InvokeMember(ad, BindingFlags.GetProperty, null, o, null)) ?? ""; }
        static void Ver(object o, string ad, string v) { o.GetType().InvokeMember(ad, BindingFlags.SetProperty, null, o, new object[] { v }); }
    }
}
