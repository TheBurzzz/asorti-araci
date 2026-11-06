// Asorti Aracı - uygulama penceresi: sayfayı Windows'un içindeki Edge motoruyla (WebView2) gösterir.
// Pencere tıklanınca hemen açılır; içi önce açılış ekranıdır, sayfa ekrana çizilince açılış ekranı yumuşakça solar.
using System;
using System.Collections;
using System.Collections.Specialized;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.Reflection;
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
        [DllImport("user32.dll")] static extern bool IsZoomed(IntPtr h);
        [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
        [DllImport("user32.dll")] static extern int GetSystemMetrics(int i);
        [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr sonra, int x, int y, int g, int y2, uint b);
        [DllImport("user32.dll")] static extern bool FlashWindowEx(ref FLASHWINFO f);
        [DllImport("user32.dll")] static extern bool AllowSetForegroundWindow(int pid);
        [StructLayout(LayoutKind.Sequential)] struct RECT { public int Sol, Ust, Sag, Alt; }
        [StructLayout(LayoutKind.Sequential)] struct FLASHWINFO { public uint cbSize; public IntPtr hwnd; public uint dwFlags; public uint uCount; public uint dwTimeout; }

        const int WM_NCCALCSIZE = 0x0083, WM_NCHITTEST = 0x0084;
        const int HTCLIENT = 1, HTTOP = 12, HTTOPLEFT = 13, HTTOPRIGHT = 14;

        readonly Sunucu sunucu;
        readonly WebView2 wv;
        readonly AcilisCizim cizim;
        AcilisKatmani katman;
        readonly System.Windows.Forms.Timer denetci = new System.Windows.Forms.Timer();
        readonly Stopwatch sw = Stopwatch.StartNew();
        volatile bool acik = true;
        bool kapatOnay, gezindi, hazir, yenilendi, hataYazildi, acilisBitti;
        double gezintiT = -1;
        int gezintiHata;
        public bool YenidenBaslatIstendi;
        // tek parça başlık: Windows'un başlık satırı yok, küçült / büyüt / kapat uygulamanın üst çubuğunda
        bool ozelBaslik, etkin = true;
        bool koyuTema;   // uyarı pencereleri sayfanın o anki görünümünde açılır
        Color seritRenk;
        NotifyIcon bildirimSimge;
        string bildirimSayfa;
        // pencerenin normal boyuttaki yeri: ekranı kaplamaktan dönünce buraya döner (başlık satırı olmadığı için WinForms'un
        // hatırladığı boy yanlış olabiliyor) ve kapanırken bu kaydedilir
        Rectangle normalYer;
        FormWindowState oncekiDurum = FormWindowState.Normal;
        // Edge motorunun denetçisi ve "odak neden geliyor" bilgisi (WebView2 denetiminin iç alanları; bulunamazsa WinForms odağı kullanılır)
        static readonly FieldInfo fDenetci = typeof(WebView2).GetField("_coreWebView2Controller", BindingFlags.Instance | BindingFlags.NonPublic);
        static readonly FieldInfo fOdakSebebi = typeof(WebView2).GetField("_lastMoveFocusReason", BindingFlags.Instance | BindingFlags.NonPublic);

        public Pencere(Sunucu s)
        {
            sunucu = s;
            cizim = new AcilisCizim(Kullanici.Al("tema") == "dark");
            koyuTema = cizim.Koyu;
            ozelBaslik = Kullanici.Al("pencere_basligi") != "windows";   // "windows": eski tip başlık satırı (gerekirse)
            seritRenk = BarRengi(cizim.Koyu);
            Text = "Eleman";
            // simgenin bütün boyutları (16…256): başlıkta ve görev çubuğunda her ekran ölçeğinde keskin
            try { Icon = new Icon(Simge.Ico); }
            catch { try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { } }
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
            else r = EkranaSigdir(r);   // kaydedilen yer ekrandan taşıyorsa sığdır
            Bounds = r;
            if (tam) WindowState = FormWindowState.Maximized;
        }

        static int Sayi(object o, string ad) { double d; return double.TryParse(Json.Str(o, ad), NumberStyles.Float, CultureInfo.InvariantCulture, out d) ? (int)d : 0; }
        static int MSayi(string s, string ad) { Match m = Regex.Match(s, "\"" + ad + "\"\\s*:\\s*(-?\\d+)"); return m.Success ? int.Parse(m.Groups[1].Value, CultureInfo.InvariantCulture) : 0; }

        void YerKaydet()
        {
            try
            {
                Rectangle r = WindowState == FormWindowState.Normal ? Bounds : (normalYer.Width > 0 ? normalYer : RestoreBounds);
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
            // açılışta pencerenin içi açılış ekranı; sonra sadece üstteki ince boyutlandırma şeridi görünür (üst çubuğun renginde)
            if (!acilisBitti) { try { cizim.Ciz(e.Graphics, e.ClipRectangle, false, null, 0); return; } catch { } }
            using (SolidBrush b = new SolidBrush(seritRenk)) e.Graphics.FillRectangle(b, e.ClipRectangle);
        }

        static Color BarRengi(bool koyu) { return koyu ? Color.FromArgb(26, 28, 35) : Color.FromArgb(245, 246, 249); }

        // ---------- tek parça başlık ----------
        // Windows'un başlık satırı kaldırılır; kenarlar, gölge, ekrana yapıştırma, küçültme / büyütme hareketleri olduğu gibi kalır.
        // Pencere üst çubuğun boş yerinden tutulup taşınır, çift tıklayınca büyür / küçülür, sağ tıklayınca Windows menüsü açılır.
        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            if (ozelBaslik) CerceveYenile();
        }

        void CerceveYenile()
        {
            try { SetWindowPos(Handle, IntPtr.Zero, 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0004 | 0x0010 | 0x0020); } catch { }   // NOSIZE|NOMOVE|NOZORDER|NOACTIVATE|FRAMECHANGED
            SeritAyarla();
        }

        int UstSerit { get { return Math.Max(2, (int)Math.Round(2 * cizim.Olcek)); } }

        // pencere normal boyuttayken en üstte ince bir şerit kalır: oradan yukarı doğru boyutlandırılır
        void SeritAyarla()
        {
            int s = ozelBaslik && WindowState == FormWindowState.Normal ? UstSerit : 0;
            if (Padding.Top != s) Padding = new Padding(0, s, 0, 0);
        }

        protected override void WndProc(ref Message m)
        {
            if (ozelBaslik && m.Msg == WM_NCCALCSIZE && m.WParam != IntPtr.Zero)
            {
                RECT once = (RECT)Marshal.PtrToStructure(m.LParam, typeof(RECT));
                base.WndProc(ref m);
                RECT r = (RECT)Marshal.PtrToStructure(m.LParam, typeof(RECT));
                // başlık satırı yok: iç alan pencerenin en üstünden başlar (ekranı kaplarken ekranın dışına taşan çerçeve kadar aşağıdan)
                r.Ust = once.Ust + (IsZoomed(m.HWnd) ? GetSystemMetrics(33) + GetSystemMetrics(92) : 0);   // SM_CYFRAME + SM_CXPADDEDBORDER
                Marshal.StructureToPtr(r, m.LParam, false);
                m.Result = IntPtr.Zero;
                return;
            }
            base.WndProc(ref m);
            if (ozelBaslik && m.Msg == WM_NCHITTEST && m.Result.ToInt64() == HTCLIENT && WindowState == FormWindowState.Normal)
            {
                long lp = m.LParam.ToInt64();
                Point p = PointToClient(new Point(unchecked((short)(lp & 0xFFFF)), unchecked((short)((lp >> 16) & 0xFFFF))));
                if (p.Y < UstSerit)
                {
                    int k = (int)Math.Round(8 * cizim.Olcek);
                    m.Result = (IntPtr)(p.X < k ? HTTOPLEFT : (p.X >= ClientSize.Width - k ? HTTOPRIGHT : HTTOP));
                }
            }
        }

        // Edge motoru üst çubuğu başlık gibi kullanamıyorsa (çok eski sürüm) Windows'un başlık satırına dönülür
        void BaslikKapat()
        {
            if (!ozelBaslik) return;
            ozelBaslik = false;
            Kayit.Yaz("tek parca baslik kullanilamiyor, Windows basligina donuldu");
            CerceveYenile();
            if (katman != null) katman.Dugmeler = false;
            DurumGonder();
        }

        // sayfaya pencerenin durumu: başlık sayfada mı, ekranı kaplıyor mu, önde mi
        void DurumGonder()
        {
            try
            {
                if (wv == null || wv.CoreWebView2 == null) return;
                wv.CoreWebView2.PostWebMessageAsJson(Json.Yaz(Json.H("t", "pencere", "baslik", ozelBaslik, "tam", WindowState == FormWindowState.Maximized, "etkin", etkin)));
            }
            catch { }
        }

        void SayfayaGonder(OrderedDictionary o)
        {
            try { if (wv != null && wv.CoreWebView2 != null) wv.CoreWebView2.PostWebMessageAsJson(Json.Yaz(o)); } catch { }
        }

        protected override void OnActivated(EventArgs e)
        {
            base.OnActivated(e);
            etkin = true;
            DurumGonder();
            if (bildirimSimge != null) { try { bildirimSimge.Visible = false; } catch { } }   // kullanıcı geri döndü
        }

        protected override void OnDeactivate(EventArgs e)
        {
            base.OnDeactivate(e);
            etkin = false;
            DurumGonder();
        }

        protected override void OnSizeChanged(EventArgs e)
        {
            base.OnSizeChanged(e);
            FormWindowState d = WindowState;
            if (d == FormWindowState.Normal)
            {
                if (oncekiDurum != FormWindowState.Normal && normalYer.Width > 0 && Size != normalYer.Size)
                {
                    // ekranı kaplamaktan (ya da simge durumundan) dönüş: son normal boyuna, ekrana sığacak şekilde
                    oncekiDurum = d;
                    Bounds = EkranaSigdir(new Rectangle(Location, normalYer.Size));
                    return;
                }
                normalYer = Bounds;
            }
            oncekiDurum = d;
            SeritAyarla();
            DurumGonder();
        }

        static Rectangle EkranaSigdir(Rectangle r)
        {
            Rectangle c = Screen.FromRectangle(r).WorkingArea;
            int w = Math.Min(r.Width, c.Width), h = Math.Min(r.Height, c.Height);
            int x = Math.Max(c.Left, Math.Min(r.X, c.Right - w)), y = Math.Max(c.Top, Math.Min(r.Y, c.Bottom - h));
            return new Rectangle(x, y, w, h);
        }

        // ---------- sayfadan gelen istekler ----------
        void MesajGeldi(object s, CoreWebView2WebMessageReceivedEventArgs e)
        {
            object o;
            try { o = Json.Oku(e.WebMessageAsJson); } catch { return; }
            string t = Json.Str(o, "t");
            if (t == "pencere")
            {
                string i = Json.Str(o, "is");
                // Edge motorunun olayından çıktıktan sonra yapılır
                UI(delegate
                {
                    if (i == "kucult") WindowState = FormWindowState.Minimized;
                    else if (i == "buyut") WindowState = WindowState == FormWindowState.Maximized ? FormWindowState.Normal : FormWindowState.Maximized;
                    else if (i == "kapat") Close();
                    else DurumGonder();
                });
            }
            else if (t == "bildirim")
            {
                string b = Json.Str(o, "baslik"), m = Json.Str(o, "metin"), id = Json.Str(o, "id");
                bool hata = Json.Str(o, "tur") == "hata";
                UI(delegate { Bildir(b, m, id, hata); });
            }
        }

        // ---------- bildirim: pastallar hazır olunca (pencere öndeyse sayfadaki bildirim yeter) ----------
        void Bildir(string baslik, string metin, string sayfa, bool hata)
        {
            if (etkin && WindowState != FormWindowState.Minimized) return;
            try
            {
                if (bildirimSimge == null)
                {
                    bildirimSimge = new NotifyIcon();
                    try { bildirimSimge.Icon = new Icon(Simge.Ico, SystemInformation.SmallIconSize); }
                    catch { bildirimSimge.Icon = Icon; }
                    bildirimSimge.Text = "Eleman";
                    bildirimSimge.BalloonTipClicked += delegate { BildirimeGit(); };
                    bildirimSimge.MouseClick += delegate { BildirimeGit(); };
                }
                bildirimSayfa = sayfa;
                string b = Kisalt(baslik, 63), m = Kisalt(metin, 255);
                if (m.Length == 0) { m = b; b = "Eleman"; }
                if (b.Length == 0) b = "Eleman";
                bildirimSimge.Visible = true;
                bildirimSimge.ShowBalloonTip(10000, b, m, hata ? ToolTipIcon.Warning : ToolTipIcon.None);
                // görev çubuğundaki düğme de turuncu yanar (pencereye dönünce söner)
                FLASHWINFO f = new FLASHWINFO();
                f.cbSize = (uint)Marshal.SizeOf(typeof(FLASHWINFO));
                f.hwnd = Handle;
                f.dwFlags = 0x2 | 0xC;   // FLASHW_TRAY | FLASHW_TIMERNOFG
                f.uCount = 3;
                FlashWindowEx(ref f);
                Kayit.Yaz("bildirim: " + baslik);
            }
            catch (Exception ex) { Kayit.Yaz("bildirim gosterilemedi: " + ex.Message); }
        }

        static string Kisalt(string s, int n) { s = (s ?? "").Trim(); return s.Length > n ? s.Substring(0, n - 1) + "…" : s; }

        void BildirimeGit()
        {
            OneGetir();
            string id = bildirimSayfa;
            if (!string.IsNullOrEmpty(id)) UI(delegate { SayfayaGonder(Json.H("t", "git", "id", id)); });
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            KoyuBaslik(cizim.Koyu);
            try
            {
                katman = new AcilisKatmani(this, cizim);
                katman.Dugmeler = ozelBaslik;
                katman.Bitti += delegate { katman = null; acilisBitti = true; cizim.Dispose(); Invalidate(); SayfayaGonder(Json.H("t", "acilis", "v", "bitti")); };
                katman.Goster();
            }
            catch (Exception ex) { Kayit.Yaz("acilis ekrani gosterilemedi: " + ex.Message); katman = null; acilisBitti = true; }
            wv.Visible = true;
            OdakHazirla();   // pencerenin etkin denetimi baştan sayfa: yeniden etkinleşince odak sayfada kaldığı yere döner
            denetci.Start();
            WebBaslat();
            sunucu.ArkaPlanBaslat();
            ThreadPool.QueueUserWorkItem(delegate { Kisayol.Guncelle(Application.ExecutablePath); });
        }

        protected override void OnResize(EventArgs e) { base.OnResize(e); if (katman != null) katman.Hizala(); }
        protected override void OnMove(EventArgs e)
        {
            base.OnMove(e);
            if (katman != null) katman.Hizala();
            if (WindowState == FormWindowState.Normal && oncekiDurum == FormWindowState.Normal && normalYer.Width > 0) normalYer.Location = Location;
        }

        async void WebBaslat()
        {
            try
            {
                CoreWebView2EnvironmentOptions o = new CoreWebView2EnvironmentOptions();
                // pencere arka planda / simge durumundayken de zamanlayıcılar yavaşlamasın (Gerber işlerinin takibi sürsün)
                o.AdditionalBrowserArguments = "--disable-background-timer-throttling --disable-renderer-backgrounding --disable-backgrounding-occluded-windows";
                string udf = Yer.Yol("profil_uygulama");
                if (!Directory.Exists(udf)) await System.Threading.Tasks.Task.Run(new Action(delegate { EskiKayitlariAl(udf); }));
                CoreWebView2Environment env = await CoreWebView2Environment.CreateAsync(null, udf, o);
                await wv.EnsureCoreWebView2Async(env);
                CoreWebView2 c = wv.CoreWebView2;
                CoreWebView2Settings st = c.Settings;
                st.AreDevToolsEnabled = false;
                st.IsStatusBarEnabled = false;
                st.IsGeneralAutofillEnabled = false;
                st.IsPasswordAutosaveEnabled = false;
                st.IsSwipeNavigationEnabled = false;
                // tek parça başlık: sayfadaki üst çubuk pencerenin başlığı gibi davranır (app-region: drag)
                if (ozelBaslik)
                {
                    try { st.IsNonClientRegionSupportEnabled = true; }
                    catch (Exception ex) { Kayit.Yaz("Edge motoru ust cubugu baslik olarak kullanamiyor: " + ex.Message); BaslikKapat(); }
                }
                c.NewWindowRequested += YeniPencere;
                c.PermissionRequested += Izin;
                c.ProcessFailed += Coktu;
                c.NavigationCompleted += Gezildi;
                c.WebMessageReceived += MesajGeldi;
                // sayfanın uyarı / onay kutuları Edge'in "localhost şunu diyor" kutusu yerine uygulamanın kendi penceresiyle
                try { c.ScriptDialogOpening += DiyalogAciliyor; st.AreDefaultScriptDialogsEnabled = false; }
                catch (Exception ex) { Kayit.Yaz("uyari kutulari Edge'in kendi kutusuyla acilacak: " + ex.Message); }
                // sayfa ilk satırından itibaren pencerenin içinde olduğunu bilsin (düğmeler titremeden yerinde çizilsin)
                await c.AddScriptToExecuteOnDocumentCreatedAsync("window.asortiPencere={baslik:" + (ozelBaslik ? "true" : "false") + "};");
                double z;
                string yk = Kullanici.Al("yakinlik");
                if (yk.Length == 0) yk = EskiYakinlik();
                if (double.TryParse(yk, NumberStyles.Float, CultureInfo.InvariantCulture, out z) && z >= 0.25 && z <= 5 && Math.Abs(z - 1) > 0.001) wv.ZoomFactor = z;
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

        // eski Edge penceresinde yakınlaştırma (Ctrl + / -) kullanıldıysa yeni pencere de aynı büyüklükte açılır
        static string EskiYakinlik()
        {
            try
            {
                Match m = Regex.Match(Dosya.MetinOku(Yer.Yol("profil", "Default", "Preferences")), "\"localhost\"\\s*:\\s*(?:\\{[^{}]*?\"zoom_level\"\\s*:\\s*)?(-?[0-9.]+(?:[eE][-+]?[0-9]+)?)");
                double l;
                if (m.Success && double.TryParse(m.Groups[1].Value, NumberStyles.Float, CultureInfo.InvariantCulture, out l) && Math.Abs(l) > 0.001 && Math.Abs(l) < 9)
                {
                    double z = Math.Round(Math.Pow(1.2, l), 3);
                    Kullanici.Yaz("yakinlik", z);
                    Kayit.Yaz("eski pencerenin yakinlastirmasi alindi: %" + Math.Round(z * 100));
                    return z.ToString(CultureInfo.InvariantCulture);
                }
            }
            catch { }
            return "";
        }

        void Git()
        {
            try { wv.CoreWebView2.Navigate("http://localhost:" + sunucu.A.Port + "/"); } catch (Exception ex) { Kayit.Yaz("sayfa acilamadi: " + ex.Message); }
        }

        // sayfa uyarı / onay kutusu açmak istedi: sayfa cevabı bekler, pencere Edge'in olayından çıktıktan sonra açılır
        void DiyalogAciliyor(object s, CoreWebView2ScriptDialogOpeningEventArgs e)
        {
            CoreWebView2Deferral d;
            try { d = e.GetDeferral(); } catch { return; }
            MethodInvoker ac = delegate
            {
                try
                {
                    OdakHazirla();
                    if (e.Kind == CoreWebView2ScriptDialogKind.Alert) { Uyari.Goster(this, e.Message, koyuTema); e.Accept(); }
                    else if (e.Kind == CoreWebView2ScriptDialogKind.Confirm) { if (Uyari.Sor(this, e.Message, "Tamam", "İptal", koyuTema, false)) e.Accept(); }
                    else if (e.Kind == CoreWebView2ScriptDialogKind.Beforeunload)
                    {
                        if (Uyari.Sor(this, "Sayfa yenilensin mi?\n\nGerber'e gönderilen pastalların takibi, sayfa yenilenince kaldığı yerden sürer.", "Yenile", "Vazgeç", koyuTema, false)) e.Accept();
                    }
                }
                catch (Exception ex) { Kayit.Yaz("uyari penceresi acilamadi: " + ex.Message); }
                finally { try { d.Complete(); } catch { } OdagiGeriVer(); }
            };
            // pencere kapanıyorsa sayfa bekletilmez
            try { if (IsHandleCreated && !IsDisposed) { BeginInvoke(ac); return; } } catch { }
            try { d.Complete(); } catch { }
        }

        void Gezildi(object s, CoreWebView2NavigationCompletedEventArgs e)
        {
            if (e.IsSuccess) { DurumGonder(); if (!gezindi) { gezindi = true; gezintiT = sw.Elapsed.TotalMilliseconds; } return; }
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
            if (mesgul)
            {
                OdakHazirla();
                if (!Uyari.Sor(this, "Pencere kapatılsın mı?\n\nGerber'e gönderilen pastallar var. Pencere kapanırsa uygulama onları izlemeyi bırakır.", "Kapat", "Vazgeç", koyuTema, true)) { OdagiGeriVer(); return; }
            }
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

        public void Tema(string t)
        {
            UI(delegate
            {
                koyuTema = t == "dark";
                KoyuBaslik(koyuTema);
                seritRenk = BarRengi(koyuTema);
                if (acilisBitti) Invalidate(new Rectangle(0, 0, ClientSize.Width, Math.Max(UstSerit, 1)));
            });
        }

        // ---------- klavye odağı hep sayfada ----------
        // Pencere yeniden etkinleşince (kendi uyarı kutularımız kapanınca, başka programdan dönünce) WinForms odağı "sıradaki
        // denetime" verirse Edge motoru sayfadaki ilk düğmeye atlıyordu (sayfa en üste kayıyordu) ya da odak sayfadan çıkıyordu
        // (yazı alanlarına yazılamıyor, ancak başka programa geçip dönünce düzeliyordu). Etkin denetim hep sayfadır ve odak
        // sayfaya "en son kalınan yer" olarak döner.
        void OdakHazirla()
        {
            try
            {
                if (wv == null || wv.IsDisposed) return;
                if (fOdakSebebi != null) fOdakSebebi.SetValue(wv, CoreWebView2MoveFocusReason.Programmatic);
                if (ActiveControl != wv) ActiveControl = wv;
            }
            catch { }
        }

        // pencerenin kendi kutusu kapandıktan hemen sonra: odak sayfaya, en son kalınan yere (pencere hâlâ öndeyse)
        void OdagiGeriVer()
        {
            OdakHazirla();
            System.Windows.Forms.Timer t = new System.Windows.Forms.Timer();
            t.Interval = 40;
            t.Tick += delegate
            {
                t.Stop();
                t.Dispose();
                try
                {
                    if (!acik || wv.IsDisposed || wv.CoreWebView2 == null || Form.ActiveForm != this) return;
                    CoreWebView2Controller k = fDenetci != null ? fDenetci.GetValue(wv) as CoreWebView2Controller : null;
                    if (k != null) k.MoveFocus(CoreWebView2MoveFocusReason.Programmatic);
                    else wv.Focus();
                }
                catch (Exception ex) { Kayit.Yaz("odak sayfaya verilemedi: " + ex.Message); }
            };
            t.Start();
        }

        // köprü bir işin durumunu yazdı: o işi bekleyen sayfa beklemeden yenilesin
        public void KopruDegisti(string isAdi) { UI(delegate { SayfayaGonder(Json.H("t", "kopru", "base", isAdi)); }); }

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
                    OdakHazirla();
                    using (FolderBrowserDialog d = new FolderBrowserDialog())
                    {
                        d.Description = "Excel dosyalarının kaydedileceği klasörü seç";
                        d.ShowNewFolderButton = true;
                        if (!string.IsNullOrEmpty(baslangic) && Directory.Exists(baslangic)) d.SelectedPath = baslangic;
                        if (d.ShowDialog(this) == DialogResult.OK) sonuc = d.SelectedPath ?? "";
                    }
                }
                catch (Exception ex) { Kayit.Yaz("klasor secme penceresi: " + ex.Message); }
                OdagiGeriVer();
            });
            return sonuc;
        }

        public void Guncellendi(bool yenidenBaslat)
        {
            if (!yenidenBaslat) return;
            UI(delegate
            {
                Kayit.Yaz("uygulama yeni surumle yeniden aciliyor");
                // kullanıcı şu an bu penceredeyken izin verilir: yeni sürümün penceresi arkada kalmaz, ilk tıklama boşa gitmez
                try { AllowSetForegroundWindow(-1); } catch { }
                YenidenBaslatIstendi = true;
                kapatOnay = true;
                Close();
            });
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                try { denetci.Dispose(); } catch { }
                if (bildirimSimge != null) { try { bildirimSimge.Visible = false; bildirimSimge.Dispose(); } catch { } bildirimSimge = null; }
            }
            base.Dispose(disposing);
        }
    }
}
