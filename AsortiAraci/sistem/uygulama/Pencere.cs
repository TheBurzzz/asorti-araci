// Asorti Aracı - uygulama penceresi: sayfayı Windows'un içindeki Edge motoruyla (WebView2) gösterir.
// Pencere tıklanınca hemen açılır; içi önce açılış ekranıdır, sayfa ekrana çizilince açılış ekranı yumuşakça solar.
using System;
using System.Collections;
using System.Collections.Specialized;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace AsortiAraci
{
    sealed class Pencere : Form, IPencere
    {
        [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr h, int ad, ref int deger, int boy);
        [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int k);
        [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
        [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);

        readonly Sunucu sunucu;
        readonly WebView2 wv;
        readonly AcilisCizim cizim;
        AcilisKatmani katman;
        readonly System.Windows.Forms.Timer denetci = new System.Windows.Forms.Timer();
        readonly Stopwatch sw = Stopwatch.StartNew();
        volatile bool acik = true;
        bool kapatOnay, gezindi, hazir, yenilendi, hataYazildi;
        double gezintiT = -1;
        int gezintiHata;
        public bool YenidenBaslatIstendi;

        public Pencere(Sunucu s)
        {
            sunucu = s;
            cizim = new AcilisCizim(Kullanici.Al("tema") == "dark");
            Text = "Asorti Aracı";
            try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
            StartPosition = FormStartPosition.Manual;
            BackColor = cizim.Zemin;
            MinimumSize = new Size(760, 520);
            KeyPreview = false;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
            try { using (Graphics g = Graphics.FromHwnd(IntPtr.Zero)) cizim.Olcek = Math.Max(1f, g.DpiX / 96f); } catch { }
            Yerlestir();
            wv = new WebView2();
            wv.Dock = DockStyle.Fill;
            wv.Visible = false;
            wv.DefaultBackgroundColor = cizim.Zemin;
            Controls.Add(wv);
            denetci.Interval = 250;
            denetci.Tick += Denetle;
        }

        // ---------- pencerenin yeri: son kapandığı yer; ilk açılışta (ya da ekran yoksa) tam ekran ----------
        void Yerlestir()
        {
            Rectangle calisma = Screen.PrimaryScreen.WorkingArea;
            bool tam = true;
            Rectangle r = Rectangle.Empty;
            try
            {
                object p = Json.Al(Kullanici.Oku(), "pencere");
                if (p != null)
                {
                    r = new Rectangle(Sayi(p, "x"), Sayi(p, "y"), Sayi(p, "gen"), Sayi(p, "yuk"));
                    tam = Json.Str(p, "tam") != "False";
                }
                else
                {
                    // Edge'deki eski pencerenin bulunduğu ekran
                    Match m = Regex.Match(Dosya.MetinOku(Yer.Yol("profil", "Default", "Preferences")), "\"localhost_/\"\\s*:\\s*\\{([^{}]*)\\}");
                    if (m.Success)
                    {
                        string s = m.Groups[1].Value;
                        Point orta = new Point((MSayi(s, "left") + MSayi(s, "right")) / 2, (MSayi(s, "top") + MSayi(s, "bottom")) / 2);
                        foreach (Screen e in Screen.AllScreens) if (e.Bounds.Contains(orta)) { calisma = e.WorkingArea; break; }
                    }
                }
            }
            catch { r = Rectangle.Empty; }
            bool gorunur = false;
            if (r.Width >= 400 && r.Height >= 300)
                foreach (Screen e in Screen.AllScreens) { Rectangle k = Rectangle.Intersect(e.WorkingArea, r); if (k.Width >= 200 && k.Height >= 150) { gorunur = true; calisma = e.WorkingArea; break; } }
            if (!gorunur)
            {
                int gw = Math.Min(calisma.Width, Math.Max(1100, calisma.Width * 4 / 5)), gh = Math.Min(calisma.Height, Math.Max(720, calisma.Height * 4 / 5));
                r = new Rectangle(calisma.X + (calisma.Width - gw) / 2, calisma.Y + (calisma.Height - gh) / 2, gw, gh);
                tam = true;
            }
            Bounds = r;
            if (tam) WindowState = FormWindowState.Maximized;
        }

        static int Sayi(object o, string ad) { double d; return double.TryParse(Json.Str(o, ad), NumberStyles.Float, CultureInfo.InvariantCulture, out d) ? (int)d : 0; }
        static int MSayi(string s, string ad) { Match m = Regex.Match(s, "\"" + ad + "\"\\s*:\\s*(-?\\d+)"); return m.Success ? int.Parse(m.Groups[1].Value, CultureInfo.InvariantCulture) : 0; }

        void YerKaydet()
        {
            try
            {
                Rectangle r = WindowState == FormWindowState.Normal ? Bounds : RestoreBounds;
                bool tam = WindowState == FormWindowState.Maximized || (WindowState == FormWindowState.Minimized && Json.Str(Json.Al(Kullanici.Oku(), "pencere"), "tam") != "False");
                Kullanici.Yaz("pencere", Json.H("x", r.X, "y", r.Y, "gen", r.Width, "yuk", r.Height, "tam", tam));
            }
            catch { }
        }

        // ---------- açılış ----------
        protected override void OnLoad(EventArgs e)
        {
            base.OnLoad(e);
            try { cizim.Hazirla(ClientSize, cizim.Olcek); } catch { }
        }

        protected override void OnPaintBackground(PaintEventArgs e) { }

        protected override void OnPaint(PaintEventArgs e)
        {
            try { cizim.Ciz(e.Graphics, e.ClipRectangle, false, null, 0); } catch { }
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            KoyuBaslik(cizim.Koyu);
            try
            {
                katman = new AcilisKatmani(this, cizim);
                katman.Bitti += delegate { katman = null; cizim.Dispose(); Invalidate(); };
                katman.Goster();
            }
            catch (Exception ex) { Kayit.Yaz("acilis ekrani gosterilemedi: " + ex.Message); katman = null; }
            wv.Visible = true;
            denetci.Start();
            WebBaslat();
            sunucu.ArkaPlanBaslat();
            ThreadPool.QueueUserWorkItem(delegate { Kisayol.Guncelle(Application.ExecutablePath); });
        }

        protected override void OnResize(EventArgs e) { base.OnResize(e); if (katman != null) katman.Hizala(); }
        protected override void OnMove(EventArgs e) { base.OnMove(e); if (katman != null) katman.Hizala(); }

        async void WebBaslat()
        {
            try
            {
                CoreWebView2EnvironmentOptions o = new CoreWebView2EnvironmentOptions();
                // pencere arka planda / simge durumundayken de zamanlayıcılar yavaşlamasın (Gerber işlerinin takibi sürsün)
                o.AdditionalBrowserArguments = "--disable-background-timer-throttling --disable-renderer-backgrounding --disable-backgrounding-occluded-windows";
                string udf = Yer.Yol("profil_uygulama");
                if (!Directory.Exists(udf)) await System.Threading.Tasks.Task.Run(delegate { EskiKayitlariAl(udf); });
                CoreWebView2Environment env = await CoreWebView2Environment.CreateAsync(null, udf, o);
                await wv.EnsureCoreWebView2Async(env);
                CoreWebView2 c = wv.CoreWebView2;
                CoreWebView2Settings st = c.Settings;
                st.AreDevToolsEnabled = false;
                st.IsStatusBarEnabled = false;
                st.IsGeneralAutofillEnabled = false;
                st.IsPasswordAutosaveEnabled = false;
                st.IsSwipeNavigationEnabled = false;
                c.NewWindowRequested += YeniPencere;
                c.PermissionRequested += Izin;
                c.ProcessFailed += Coktu;
                c.NavigationCompleted += Gezildi;
                double z;
                if (double.TryParse(Kullanici.Al("yakinlik"), NumberStyles.Float, CultureInfo.InvariantCulture, out z) && z >= 0.25 && z <= 5 && Math.Abs(z - 1) > 0.001) wv.ZoomFactor = z;
                wv.ZoomFactorChanged += delegate { try { Kullanici.Yaz("yakinlik", Math.Round(wv.ZoomFactor, 3)); } catch { } };
                Kayit.Yaz("pencere acildi (Edge motoru " + env.BrowserVersionString + ")");
                Git();
            }
            catch (Exception ex)
            {
                Kayit.Yaz("pencere acilamadi (WebView2): " + ex.Message);
                EskiYolaGec();
            }
        }

        // ilk açılış: eski Edge penceresinin kayıtları (çalışma sayfaları, görünüm) bu pencereye aynen taşınır.
        // Sayfa ayrıca kendi disk yedeğinden (yerel_kayit.json) de geri yükler; bu kopya, o yedek hiç yazılmadan
        // (eski sürümün üstüne doğrudan kurulumla) geçildiğinde işe yarar. Adres aynı olduğu için kayıtlar aynen okunur.
        static void EskiKayitlariAl(string udf)
        {
            try
            {
                string kaynak = Yer.Yol("profil", "Default", "Local Storage", "leveldb");
                if (!Directory.Exists(kaynak)) return;
                string hedef = Path.Combine(Path.Combine(Path.Combine(Path.Combine(udf, "EBWebView"), "Default"), "Local Storage"), "leveldb");
                string gecici = hedef + ".tasiniyor";
                if (Directory.Exists(gecici)) Directory.Delete(gecici, true);
                Directory.CreateDirectory(gecici);
                int n = 0;
                foreach (string f in Directory.GetFiles(kaynak))
                {
                    string ad = Path.GetFileName(f);
                    if (ad.Equals("LOCK", StringComparison.OrdinalIgnoreCase)) continue;
                    File.WriteAllBytes(Path.Combine(gecici, ad), Dosya.PaylasimliOku(f));
                    n++;
                }
                // yarım kopya bırakılmaz: hepsi kopyalandıysa yerine konur
                Directory.Move(gecici, hedef);
                Kayit.Yaz("eski pencerenin kayitlari tasindi (" + n + " dosya)");
            }
            catch (Exception ex)
            {
                Kayit.Yaz("eski pencerenin kayitlari tasinamadi: " + ex.Message);
                try { if (Directory.Exists(udf)) Directory.Delete(udf, true); } catch { }
            }
        }

        void Git()
        {
            try { wv.CoreWebView2.Navigate("http://localhost:" + sunucu.A.Port + "/"); } catch (Exception ex) { Kayit.Yaz("sayfa acilamadi: " + ex.Message); }
        }

        void Gezildi(object s, CoreWebView2NavigationCompletedEventArgs e)
        {
            if (e.IsSuccess) { if (!gezindi) { gezindi = true; gezintiT = sw.Elapsed.TotalMilliseconds; } return; }
            if (gezindi) return;
            gezintiHata++;
            Kayit.Yaz("sayfa yuklenemedi (" + e.WebErrorStatus + "), yeniden deneniyor");
            if (gezintiHata <= 20)
            {
                System.Windows.Forms.Timer t = new System.Windows.Forms.Timer();
                t.Interval = 400;
                t.Tick += delegate { t.Stop(); t.Dispose(); Git(); };
                t.Start();
            }
        }

        // açılış ekranının yedek süreleri: sayfa "hazırım" demese de kullanıcı bekletilmez
        void Denetle(object s, EventArgs e)
        {
            double t = sw.Elapsed.TotalMilliseconds;
            if (katman == null || katman.Kayboluyor) { if (katman == null) denetci.Stop(); return; }
            if (!hazir && gezindi && t - gezintiT > 6000) { Kayit.Yaz("sayfa hazir demedi, acilis ekrani yine de kalkiyor"); HazirOl(); return; }
            if (!yenilendi && !gezindi && t > 25000 && wv.CoreWebView2 != null) { yenilendi = true; Git(); }
            if (t > 10000 && !hataYazildi) katman.Yaz("Hâlâ açılıyor, lütfen bekle…", true);
            if (t > 45000 && !hataYazildi) { hataYazildi = true; katman.Yaz("Açılamadı. Pencereyi kapatıp masaüstündeki simgeden yeniden aç.", false); }
        }

        void HazirOl()
        {
            if (hazir) return;
            hazir = true;
            if (katman == null) return;
            // sayfanın son karesi ekrana gelsin diye çok kısa bekle, sonra açılış ekranı solsun
            System.Windows.Forms.Timer t = new System.Windows.Forms.Timer();
            t.Interval = 90;
            t.Tick += delegate { t.Stop(); t.Dispose(); if (katman != null) katman.Kaybol(); };
            t.Start();
        }

        void EskiYolaGec()
        {
            if (!acik) return;
            acik = false;
            sunucu.Durdur();
            // köprü eski yolun sunucusuna bırakılır (o kendi köprüsünü başlatır)
            try { sunucu.Kopru.Etkin = false; sunucu.Kopru.Durdur(); } catch { }
            Program.EskiYol();
            kapatOnay = true;
            Close();
        }

        void YeniPencere(object s, CoreWebView2NewWindowRequestedEventArgs e)
        {
            e.Handled = true;
            try
            {
                Uri u = new Uri(e.Uri);
                if ((u.Scheme == "http" || u.Scheme == "https") && !u.IsLoopback)
                {
                    ProcessStartInfo si = new ProcessStartInfo(e.Uri);
                    si.UseShellExecute = true;
                    Process.Start(si);
                }
            }
            catch { }
        }

        void Izin(object s, CoreWebView2PermissionRequestedEventArgs e)
        {
            // konum: gün doğumu / batımı saatleri için (bilgisayarda kalır)
            if (e.PermissionKind == CoreWebView2PermissionKind.Geolocation) e.State = CoreWebView2PermissionState.Allow;
        }

        void Coktu(object s, CoreWebView2ProcessFailedEventArgs e)
        {
            Kayit.Yaz("sayfa sureci durdu: " + e.ProcessFailedKind);
            try
            {
                if (e.ProcessFailedKind == CoreWebView2ProcessFailedKind.BrowserProcessExited)
                {
                    // açılır açılmaz duruyorsa yeniden açmayı denemekle vakit geçirilmez: eski yoldan açılır
                    if (sw.Elapsed.TotalSeconds < 20) { EskiYolaGec(); return; }
                    YenidenBaslatIstendi = true; kapatOnay = true; Close();
                }
                else if (e.ProcessFailedKind == CoreWebView2ProcessFailedKind.RenderProcessExited || e.ProcessFailedKind == CoreWebView2ProcessFailedKind.RenderProcessUnresponsive) wv.CoreWebView2.Reload();
            }
            catch { }
        }

        // ---------- koyu görünümde Windows başlık çubuğu da koyu ----------
        void KoyuBaslik(bool koyu)
        {
            try
            {
                int v = koyu ? 1 : 0;
                if (DwmSetWindowAttribute(Handle, 20, ref v, 4) != 0) DwmSetWindowAttribute(Handle, 19, ref v, 4);
            }
            catch { }
        }

        // ---------- kapanış ----------
        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (!kapatOnay && e.CloseReason == CloseReason.UserClosing && wv.CoreWebView2 != null)
            {
                e.Cancel = true;
                KapatmayiSor();
                return;
            }
            acik = false;
            denetci.Stop();
            YerKaydet();
            base.OnFormClosing(e);
        }

        async void KapatmayiSor()
        {
            bool mesgul = false;
            try
            {
                // sayfalar son hallerini kaydetsin, Gerber'e gönderilmiş iş var mı bakılsın
                string r = await wv.CoreWebView2.ExecuteScriptAsync("(function(){try{if(window.kapanmadan)window.kapanmadan()}catch(e){}try{return Object.keys(info).some(function(k){return info[k]&&info[k].busy})}catch(e){return false}})()");
                mesgul = r == "true";
                await System.Threading.Tasks.Task.Delay(250);
                // çalışma sayfalarının disk yedeği beklemeden yazılsın
                await wv.CoreWebView2.ExecuteScriptAsync("(function(){try{return window.yedekAl?window.yedekAl():false}catch(e){return false}})()");
            }
            catch { }
            if (mesgul && MessageBox.Show(this, "Gerber'e gönderilen pastallar var. Pencere kapanırsa uygulama onları izlemeyi bırakır.\n\nYine de kapatılsın mı?", "Asorti Aracı", MessageBoxButtons.YesNo, MessageBoxIcon.Warning, MessageBoxDefaultButton.Button2) != DialogResult.Yes) return;
            kapatOnay = true;
            Close();
        }

        // ---------- sunucunun istekleri (başka iş parçacığından gelir) ----------
        public bool Acik { get { return acik && IsHandleCreated; } }

        void UI(MethodInvoker m)
        {
            try { if (IsHandleCreated && !IsDisposed) BeginInvoke(m); } catch { }
        }

        public void Hazir() { UI(HazirOl); }

        public void OneGetir()
        {
            UI(delegate
            {
                try
                {
                    if (IsIconic(Handle)) ShowWindow(Handle, 9);
                    SetForegroundWindow(Handle);
                    Activate();
                }
                catch { }
            });
        }

        public void Tema(string t) { UI(delegate { KoyuBaslik(t == "dark"); }); }

        public string KlasorSec(string baslangic)
        {
            string sonuc = "";
            if (!IsHandleCreated || IsDisposed) return sonuc;
            Invoke((MethodInvoker)delegate
            {
                try
                {
                    if (IsIconic(Handle)) ShowWindow(Handle, 9);
                    Activate();
                    using (FolderBrowserDialog d = new FolderBrowserDialog())
                    {
                        d.Description = "Excel dosyalarının kaydedileceği klasörü seç";
                        d.ShowNewFolderButton = true;
                        if (!string.IsNullOrEmpty(baslangic) && Directory.Exists(baslangic)) d.SelectedPath = baslangic;
                        if (d.ShowDialog(this) == DialogResult.OK) sonuc = d.SelectedPath ?? "";
                    }
                }
                catch (Exception ex) { Kayit.Yaz("klasor secme penceresi: " + ex.Message); }
            });
            return sonuc;
        }

        public void Guncellendi(bool yenidenBaslat)
        {
            if (!yenidenBaslat) return;
            UI(delegate
            {
                Kayit.Yaz("uygulama yeni surumle yeniden aciliyor");
                YenidenBaslatIstendi = true;
                kapatOnay = true;
                Close();
            });
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) { try { denetci.Dispose(); } catch { } }
            base.Dispose(disposing);
        }
    }
}
