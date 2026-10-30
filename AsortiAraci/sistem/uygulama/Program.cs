// Asorti Aracı - uygulamanın başlangıcı.
// Bu programı arka plandaki eski sunucu (sistem\sunucu.ps1) ya da kurulum, bu bilgisayardaki .NET Framework derleyicisiyle derler:
// sistem\AsortiAraci.exe. Windows 10 ve 11'de (64 bit, 32 bit, ARM) çalışır; pencerenin içi Windows'un Edge motorudur (WebView2).
// Edge motoru yoksa ya da açılamazsa uygulama eski yoldan (Edge penceresiyle) açılır.
using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;

[assembly: System.Reflection.AssemblyTitle("Asorti Aracı")]
[assembly: System.Reflection.AssemblyProduct("Asorti Aracı")]
[assembly: System.Reflection.AssemblyDescription("Asorti Aracı")]
[assembly: System.Reflection.AssemblyCompany("Şamil Yeşil")]
[assembly: System.Reflection.AssemblyCopyright("Created by Şamil Yeşil")]
[assembly: System.Reflection.AssemblyVersion("2.0.0.0")]
[assembly: System.Reflection.AssemblyFileVersion("2.0.0.0")]

namespace AsortiAraci
{
    static class Program
    {
        [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
        [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int k);
        [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
        [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);

        [STAThread]
        static void Main(string[] args)
        {
            Mutex tek = null;
            try
            {
                string sistem = Path.GetDirectoryName(Application.ExecutablePath);
                Yer.Ayarla(Path.GetDirectoryName(sistem));
                try { SetProcessDPIAware(); } catch { }
                // görev çubuğu kimliği exe'nin yolundan gelir: sabitlenmiş simge ile açık pencere aynı düğmede birleşir

                // güncellemeden sonra: eski pencere tamamen kapanana kadar bekle
                foreach (string a in args)
                {
                    int pid;
                    if (a.StartsWith("/bekle=") && int.TryParse(a.Substring(7), out pid))
                    {
                        try { Process.GetProcessById(pid).WaitForExit(20000); } catch { }
                    }
                }

                // tek pencere: zaten açıksa onu öne getir
                bool ilk;
                tek = new Mutex(true, "Local\\AsortiAraciUygulama", out ilk);
                if (!ilk) { AcikOlaniOneGetir(); return; }

                // güncellemeden bekleyen dosyalar; uygulamanın kendisi yenilendiyse hemen yeni haliyle aç
                string yeniExe = Path.Combine(Yer.Sistem, "AsortiAraci.yeni.exe");
                if (File.Exists(yeniExe))
                {
                    Derleyici.YeniDosyalariYerlestir();
                    if (!File.Exists(yeniExe))
                    {
                        tek.ReleaseMutex();
                        tek.Dispose();
                        tek = null;
                        Process.Start(Path.Combine(Yer.Sistem, Derleyici.ExeAd), "/bekle=" + Process.GetCurrentProcess().Id);
                        return;
                    }
                    // yerine konamadı: şimdiki haliyle açılır (bir sonraki açılışta yine denenir)
                    Kayit.Yaz("uygulamanin yeni hali yerine konamadi, simdiki haliyle aciliyor");
                }
                Derleyici.YeniDosyalariYerlestir();
                Derleyici.EskileriSil();

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
                Application.ThreadException += delegate(object o, ThreadExceptionEventArgs ev) { Kayit.Yaz("hata: " + ev.Exception); };
                AppDomain.CurrentDomain.UnhandledException += delegate(object o, UnhandledExceptionEventArgs ev) { Kayit.Yaz("beklenmedik hata: " + ev.ExceptionObject); };

                string wv = WebView2Surum();
                if (wv == null) { Kayit.Yaz("Edge motoru (WebView2) bulunamadi: eski yoldan aciliyor"); MotoruKur(); EskiYol(); return; }

                Sunucu s = new Sunucu();
                if (!s.Baslat())
                {
                    bool eskiPencere;
                    if (EskiSunucuyuKapat(s.A.Port, out eskiPencere) && s.Baslat()) { }
                    else
                    {
                        if (eskiPencere) { EskiPencereyiOneGetir(s.A.Port); return; }
                        MessageBox.Show("Asorti Aracı açılamadı: " + s.A.Port + " numaralı adres başka bir program tarafından kullanılıyor.\n\nBilgisayarı yeniden başlatıp tekrar dene.", "Asorti Aracı", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                        return;
                    }
                }
                bool yeniden = Calistir(s);
                s.Durdur();
                if (EskiyeGecildi) { Kayit.Yaz("uygulama eski yoldan acilmak uzere kapandi"); return; }
                // kapanış: köprü ve Gerber'in Batch programı da kapanır (pencere görünmezken yapılır)
                s.Kopru.Etkin = false;
                s.Kopru.Durdur();
                Kopru.BatchKapat();
                Kayit.Yaz("uygulama kapandi");
                if (yeniden)
                {
                    Derleyici.YeniDosyalariYerlestir();
                    if (tek != null) { try { tek.ReleaseMutex(); } catch { } tek.Dispose(); tek = null; }
                    Process.Start(Path.Combine(Yer.Sistem, Derleyici.ExeAd), "/bekle=" + Process.GetCurrentProcess().Id);
                }
            }
            catch (Exception ex)
            {
                Kayit.Yaz("acilis hatasi: " + ex);
                try { EskiYol(); } catch { }
            }
            finally { if (tek != null) { try { tek.Dispose(); } catch { } } }
        }

        [MethodImpl(MethodImplOptions.NoInlining)]
        static bool Calistir(Sunucu s)
        {
            Pencere p = new Pencere(s);
            s.Pencere = p;
            Application.Run(p);
            s.Pencere = null;
            return p.YenidenBaslatIstendi;
        }

        // Edge motorunun (WebView2) sürümü; yoksa null. Bilgisayarın türüne uygun yükleyici (x64 / x86 / ARM64) seçilir.
        [MethodImpl(MethodImplOptions.NoInlining)]
        static string WebView2Surum()
        {
            try
            {
                string mimari = (Environment.GetEnvironmentVariable("PROCESSOR_ARCHITECTURE") ?? "").ToUpperInvariant();
                string k = mimari == "ARM64" ? "arm64" : (Environment.Is64BitProcess ? "x64" : "x86");
                CoreWebView2Environment.SetLoaderDllFolderPath(Path.Combine(Path.Combine(Yer.Sistem, "wv2"), k));
                return CoreWebView2Environment.GetAvailableBrowserVersionString(null);
            }
            catch (Exception ex)
            {
                Kayit.Yaz("WebView2: " + ex.Message);
                return null;
            }
        }

        // Edge motoru bu bilgisayarda yoksa: Microsoft'un resmi kurulumu (imzası denetlenerek) arka planda, sessizce, bir kez kurulur.
        // Bu sefer uygulama eski yoldan açılır; kurulum bitince sonraki açılışlar uygulamanın kendi penceresiyle olur.
        const string MotorBetik =
            "$ErrorActionPreference = 'Stop'\n" +
            "$k = '{K}'\n" +
            "try {\n" +
            "  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12\n" +
            "  $f = Join-Path $env:TEMP ('MicrosoftEdgeWebview2Setup_' + [guid]::NewGuid().ToString('N').Substring(0, 6) + '.exe')\n" +
            "  Invoke-WebRequest -UseBasicParsing -TimeoutSec 120 -Uri 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile $f\n" +
            "  $s = Get-AuthenticodeSignature -LiteralPath $f\n" +
            "  if ($s.Status -ne 'Valid' -or \"$($s.SignerCertificate.Subject)\" -notmatch 'O=Microsoft Corporation') { throw ('imza gecersiz: ' + $s.Status) }\n" +
            "  $p = Start-Process -FilePath $f -ArgumentList '/silent', '/install' -Wait -PassThru\n" +
            "  Add-Content -LiteralPath $k -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' bitti, cikis kodu ' + $p.ExitCode)\n" +
            "  Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue\n" +
            "} catch { Add-Content -LiteralPath $k -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' kurulamadi: ' + $_.Exception.Message) }\n";

        static void MotoruKur()
        {
            try
            {
                string isaret = Path.Combine(Yer.Log, "webview2_kurulum.txt");
                if (File.Exists(isaret) && (DateTime.Now - File.GetLastWriteTime(isaret)).TotalDays < 3) return;   // az önce denendi
                Directory.CreateDirectory(Yer.Log);
                File.WriteAllText(isaret, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " Edge motoru (WebView2) kuruluyor\r\n", Dosya.Utf8);
                string betik = MotorBetik.Replace("{K}", isaret.Replace("'", "''"));
                ProcessStartInfo si = new ProcessStartInfo("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand " + Convert.ToBase64String(Encoding.Unicode.GetBytes(betik)));
                si.UseShellExecute = false;
                si.CreateNoWindow = true;
                Process.Start(si);
                Kayit.Yaz("Edge motoru (WebView2) arka planda kuruluyor");
            }
            catch (Exception ex) { Kayit.Yaz("Edge motoru kurulamadi: " + ex.Message); }
        }

        // eski yol: Edge penceresi + PowerShell sunucusu (hizli_ac.vbs "eski" ile bu programı atlar)
        public static bool EskiyeGecildi;
        public static void EskiYol()
        {
            EskiyeGecildi = true;
            ProcessStartInfo si = new ProcessStartInfo("wscript.exe", "//B //NoLogo \"" + Path.Combine(Yer.Sistem, "hizli_ac.vbs") + "\" eski");
            si.UseShellExecute = true;
            Process.Start(si);
        }

        static void AcikOlaniOneGetir()
        {
            int ben = Process.GetCurrentProcess().Id;
            foreach (Process p in Process.GetProcessesByName(Path.GetFileNameWithoutExtension(Application.ExecutablePath)))
            {
                try
                {
                    if (p.Id == ben) continue;
                    IntPtr h = p.MainWindowHandle;
                    if (h == IntPtr.Zero) continue;
                    if (IsIconic(h)) ShowWindow(h, 9);
                    SetForegroundWindow(h);
                    return;
                }
                catch { }
            }
        }

        // önceki sürümün PowerShell sunucusu adresi tutuyorsa: penceresi açık değilse kapanmasını iste, olmazsa kapat
        static bool EskiSunucuyuKapat(int port, out bool pencereAcik)
        {
            pencereAcik = false;
            try
            {
                string j = Istek("POST", "http://localhost:" + port + "/sunucu-kapat", 3000);
                if (j.Contains("\"acik\":true")) { pencereAcik = true; return false; }
            }
            catch { }
            for (int i = 0; i < 30; i++) { if (AdresBos(port)) return true; Thread.Sleep(150); }
            try
            {
                string j = Istek("GET", "http://localhost:" + port + "/pencere", 2000);
                if (j.Contains("\"acik\":true")) { pencereAcik = true; return false; }
            }
            catch { }
            foreach (int pid in Kopru.PowerShellSurecleri("sistem\\sunucu.ps1")) { try { Process.GetProcessById(pid).Kill(); } catch { } }
            for (int i = 0; i < 30; i++) { if (AdresBos(port)) return true; Thread.Sleep(150); }
            return false;
        }

        static void EskiPencereyiOneGetir(int port)
        {
            try { Istek("POST", "http://localhost:" + port + "/one-getir", 3000); } catch { }
            foreach (string ad in new string[] { "msedge", "chrome" })
            {
                foreach (Process p in Process.GetProcessesByName(ad))
                {
                    try
                    {
                        if (p.MainWindowHandle != IntPtr.Zero && p.MainWindowTitle.StartsWith("Asorti Ara", StringComparison.Ordinal))
                        {
                            if (IsIconic(p.MainWindowHandle)) ShowWindow(p.MainWindowHandle, 9);
                            SetForegroundWindow(p.MainWindowHandle);
                            return;
                        }
                    }
                    catch { }
                }
            }
        }

        static bool AdresBos(int port)
        {
            HttpListener l = new HttpListener();
            try { l.Prefixes.Add("http://localhost:" + port + "/"); l.Start(); l.Stop(); return true; }
            catch { return false; }
            finally { try { l.Close(); } catch { } }
        }

        static string Istek(string yontem, string url, int zaman)
        {
            HttpWebRequest r = (HttpWebRequest)WebRequest.Create(url);
            r.Method = yontem;
            r.Timeout = zaman;
            r.ReadWriteTimeout = zaman;
            r.Proxy = null;
            if (yontem == "POST") { r.ContentLength = 2; using (Stream s = r.GetRequestStream()) s.Write(new byte[] { 123, 125 }, 0, 2); }
            using (WebResponse y = r.GetResponse())
            using (StreamReader sr = new StreamReader(y.GetResponseStream(), Encoding.UTF8)) return sr.ReadToEnd();
        }
    }
}
