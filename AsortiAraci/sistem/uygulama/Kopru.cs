// Asorti Aracı - Gerber köprüsünü (kopru\kopru.ps1) arka planda çalıştırır, durursa yeniden başlatır,
// uygulama kapanınca köprüyü ve Gerber'in Batch programını kapatır. Ayrıca PowerShell betiklerini (tarama vb.) başlatır.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Threading;
#if !DENEME
using System.Management;
#endif

namespace AsortiAraci
{
    static class Betik
    {
        public static string PowerShell = "powershell.exe";   // denemede başka olabilir

        // gizli pencerede çalışan bir PowerShell betiği
        public static Process Baslat(string betik, string ekArgumanlar)
        {
            ProcessStartInfo si = new ProcessStartInfo();
            si.FileName = PowerShell;
            si.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + betik + "\"" + (string.IsNullOrEmpty(ekArgumanlar) ? "" : " " + ekArgumanlar);
            si.UseShellExecute = true;
            si.WindowStyle = ProcessWindowStyle.Hidden;
            si.WorkingDirectory = Yer.Kok;
            return Process.Start(si);
        }
    }

    // Gerber köprüsü (kopru\kopru.ps1) uygulamanın içinde, Windows PowerShell motoruyla çalışır: ayrı program açılmaz,
    // yeni sipariş gelince hemen uyanır, iş ilerleyince sayfa hemen haberdar olur. İçeride çalışamazsa eskisi gibi ayrı süreçte.
    sealed class Kopru
    {
        readonly object kilit = new object();
        Process p;
        KopruCalisma ic;
        DateTime bas = DateTime.MinValue;
        public bool Etkin = true;   // ayarlarda Gerber kapalıysa false
        public bool Icte = true;    // false: eski yol (ayrı powershell.exe)
        public Action<string> IsDegisti;   // köprü bir işin durumunu yazdı (sonuc\<iş>.json)

        public bool Calisiyor
        {
            get
            {
                lock (kilit)
                {
                    try
                    {
                        if (ic != null) return ic.Calisiyor;
                        return p != null && !p.HasExited;
                    }
                    catch { return false; }
                }
            }
        }

        public bool UygulamaIcinde { get { lock (kilit) return ic != null; } }

        public void Baslat()
        {
            lock (kilit)
            {
                bas = DateTime.Now;
                string betik = Yer.Yol("kopru", "kopru.ps1");
                if (Icte)
                {
                    try
                    {
                        if (ic != null) { ic.Dispose(); ic = null; }
                        ic = KopruCalisma.Baslat(betik, delegate(string ad) { Action<string> d = IsDegisti; if (d != null) d(ad); });
                        Kayit.Yaz("kopru uygulamanin icinde baslatildi");
                        return;
                    }
                    catch (Exception ex)
                    {
                        ic = null;
                        Icte = false;
                        Kayit.Yaz("kopru uygulamanin icinde baslatilamadi (" + ex.Message + "), ayri surec olarak baslatiliyor");
                    }
                }
                try
                {
                    p = Betik.Baslat(betik, null);
                    Kayit.Yaz("kopru baslatildi, pid " + p.Id);
                }
                catch (Exception ex) { p = null; Kayit.Yaz("kopru baslatilamadi: " + ex.Message); }
            }
        }

        // yeni sipariş ya da durdurma isteği geldi: köprü beklemeden baksın
        public void Uyandir()
        {
            lock (kilit) { if (ic != null) ic.Uyandir(); }
        }

        // durmuşsa yeniden başlat (en az 30 sn arayla)
        public void Denetle()
        {
            if (!Etkin) return;
            bool dur;
            lock (kilit)
            {
                if (ic != null) ic.Temizle();
                dur = !CalisiyorKilitli() && (DateTime.Now - bas).TotalSeconds > 30;
            }
            if (dur) { Kayit.Yaz("kopru durmustu, yeniden baslatiliyor"); Baslat(); }
        }

        bool CalisiyorKilitli()
        {
            try
            {
                if (ic != null) return ic.Calisiyor;
                return p != null && !p.HasExited;
            }
            catch { return false; }
        }

        public void Durdur()
        {
            lock (kilit)
            {
                if (ic != null) { try { ic.Dispose(); } catch { } ic = null; }
                try { if (p != null && !p.HasExited) p.Kill(); } catch { }
                p = null;
            }
            BaskaKopruleriKapat(false);
        }

        // başka yerden (eski sürüm sunucu vb.) çalışan köprü varsa kapatır: köprüyü bu uygulama yönetir
        public static void BaskaKopruleriKapat(bool sadeceKilitVarsa)
        {
            if (!Yer.Windows) return;
            try
            {
                if (sadeceKilitVarsa)
                {
                    Mutex m;
                    if (!Mutex.TryOpenExisting("AsortiGerberKopru", out m)) return;   // köprü çalışmıyorsa yavaş süreç sorgusu hiç yapılmaz
                    m.Dispose();
                }
                foreach (int pid in PowerShellSurecleri("kopru\\kopru.ps1")) { try { Process.GetProcessById(pid).Kill(); } catch { } }
            }
            catch (Exception ex) { Kayit.Yaz("eski kopru kapatilamadi: " + ex.Message); }
        }

        // komut satırında verilen parçayı içeren powershell.exe süreçleri
        public static List<int> PowerShellSurecleri(string parca)
        {
            List<int> l = new List<int>();
#if !DENEME
            try
            {
                using (ManagementObjectSearcher s = new ManagementObjectSearcher("SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name='powershell.exe'"))
                using (ManagementObjectCollection c = s.Get())
                {
                    foreach (ManagementBaseObject o in c)
                    {
                        string cl = Convert.ToString(o["CommandLine"]);
                        if (cl != null && cl.IndexOf(parca, StringComparison.OrdinalIgnoreCase) >= 0) l.Add(Convert.ToInt32(o["ProcessId"]));
                        o.Dispose();
                    }
                }
            }
            catch (Exception ex) { Kayit.Yaz("surec listesi alinamadi: " + ex.Message); }
#endif
            return l;
        }

        // Gerber'in Batch programı: önce kibarca kapat, 3 sn sonra hâlâ açıksa zorla
        public static void BatchKapat()
        {
            if (!Yer.Windows) return;
            try
            {
                Process[] b = Process.GetProcessesByName("batch");
                if (b.Length == 0) return;
                foreach (Process x in b) { try { x.CloseMainWindow(); } catch { } }
                Thread.Sleep(3000);
                foreach (Process x in Process.GetProcessesByName("batch")) { try { x.Kill(); } catch { } }
            }
            catch { }
        }
    }
}
