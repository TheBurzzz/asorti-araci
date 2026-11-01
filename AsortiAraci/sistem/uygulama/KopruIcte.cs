// Asorti Aracı - Gerber köprüsünün uygulamanın içindeki çalışma alanı.
// kopru\kopru.ps1 ayrı bir powershell.exe yerine bu programın içinde, Windows'un kendi PowerShell motoruyla çalışır.
// Betiğe $Uygulama verilir: ana döngü onunla bekler (yeni sipariş gelince hemen uyanır) ve bir işin durumu
// değişince uygulamaya haber verir (sayfa beklemeden yeniler, pastallar hazır olunca bildirim çıkar).
using System;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Runtime.CompilerServices;
using System.Threading;

namespace AsortiAraci
{
    // köprü betiğine $Uygulama olarak verilir
    public sealed class KopruAraci
    {
        readonly AutoResetEvent uyan = new AutoResetEvent(false);
        readonly Action<string> degisti;
        volatile bool duruyor;

        public KopruAraci(Action<string> degisti) { this.degisti = degisti; }

        public bool Duruyor { get { return duruyor; } }

        public void Durdur() { duruyor = true; try { uyan.Set(); } catch { } }

        public void Uyandir() { try { uyan.Set(); } catch { } }

        // ana döngü burada bekler; yeni sipariş gelince ya da uygulama kapanırken hemen döner
        public bool Bekle(int ms)
        {
            if (duruyor) return true;
            return uyan.WaitOne(Math.Max(0, Math.Min(ms, 60000)));
        }

        // köprü bir işin durumunu yazdı (kopru\sonuc\<iş>.json)
        public void IsDegisti(string ad)
        {
            if (degisti == null || string.IsNullOrEmpty(ad)) return;
            try { degisti(ad); } catch { }
        }
    }

    sealed class KopruCalisma : IDisposable
    {
        Runspace rs;
        PowerShell ps;
        public readonly KopruAraci Arac;
        int hataSayisi;
        DateTime hataDakika = DateTime.MinValue;

        KopruCalisma(KopruAraci arac) { Arac = arac; }

        [MethodImpl(MethodImplOptions.NoInlining)]
        public static KopruCalisma Baslat(string betik, Action<string> degisti)
        {
            // eski yoldaki "-ExecutionPolicy Bypass" ile aynı: bu programın içindeki betikler imza istemeden çalışır
            Environment.SetEnvironmentVariable("PSExecutionPolicyPreference", "Bypass");
            KopruCalisma k = new KopruCalisma(new KopruAraci(degisti));
            try
            {
                InitialSessionState iss = InitialSessionState.CreateDefault2();
                iss.Variables.Add(new SessionStateVariableEntry("Uygulama", k.Arac, "Asorti Araci uygulamasi (kopru uygulamanin icinde)"));
                k.rs = RunspaceFactory.CreateRunspace(iss);
                try { k.rs.ApartmentState = ApartmentState.STA; } catch { }   // powershell.exe gibi
                k.rs.ThreadOptions = PSThreadOptions.UseNewThread;
                k.rs.Open();
                k.ps = PowerShell.Create();
                k.ps.Runspace = k.rs;
                k.ps.AddCommand(betik).AddCommand("Out-Null");
                k.ps.Streams.Error.DataAdded += k.HataGeldi;
                k.ps.InvocationStateChanged += k.DurumDegisti;
                k.ps.BeginInvoke();
                return k;
            }
            catch
            {
                k.Dispose();
                throw;
            }
        }

        void HataGeldi(object s, DataAddedEventArgs e)
        {
            try
            {
                if ((DateTime.Now - hataDakika).TotalMinutes >= 1) { hataDakika = DateTime.Now; hataSayisi = 0; }
                if (++hataSayisi <= 5) Kayit.Yaz("kopru: " + ps.Streams.Error[e.Index]);
            }
            catch { }
        }

        void DurumDegisti(object s, PSInvocationStateChangedEventArgs e)
        {
            PSInvocationStateInfo d = e.InvocationStateInfo;
            if (d.State == PSInvocationState.Failed) Kayit.Yaz("kopru durdu: " + (d.Reason != null ? d.Reason.Message : "?"));
            else if (d.State == PSInvocationState.Completed && !Arac.Duruyor) Kayit.Yaz("kopru betigi kendiliginden bitti");
        }

        public bool Calisiyor
        {
            get
            {
                PowerShell x = ps;
                if (x == null) return false;
                PSInvocationState s = x.InvocationStateInfo.State;
                return s == PSInvocationState.Running || s == PSInvocationState.NotStarted;
            }
        }

        public void Uyandir() { Arac.Uyandir(); }

        // betiğin hata ve bilgi kayıtları bellekte birikmesin (asıl kayıt kopru\log'da)
        public void Temizle()
        {
            try { if (ps != null) ps.Streams.ClearStreams(); } catch { }
        }

        public void Dispose()
        {
            Arac.Durdur();
            if (ps != null)
            {
                try
                {
                    // betik uyanıp döngüden kendisi çıkar (yarım iş bırakmaz); çıkmazsa durdurulur
                    for (int i = 0; i < 40 && Calisiyor; i++) Thread.Sleep(50);
                    if (Calisiyor)
                    {
                        IAsyncResult r = ps.BeginStop(null, null);
                        r.AsyncWaitHandle.WaitOne(5000);
                    }
                }
                catch { }
                try { ps.Dispose(); } catch { }
                ps = null;
            }
            if (rs != null) { try { rs.Dispose(); } catch { } rs = null; }
        }
    }
}
