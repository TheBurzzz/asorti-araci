// Asorti Araci - acilis ekrani (masaustu simgesine tiklaninca hemen gorunur).
// Uygulama penceresinin acilacagi yeri uygulamanin kendi gorunumuyle kaplar; uygulama acilip ilk sayfasi
// ekrana cizilince pencereyle birlikte yumusakca solup uygulamaya gecer (uygulama one gelir).
// sunucu.ps1 bunu bu bilgisayarda .NET Framework'un kendi derleyicisiyle (csc.exe) derler: sistem\AsortiAcilis.exe
// C# 5 ile uyumlu yazilmistir; dosya ASCII'dir (Turkce harfler \u ile).
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;

namespace AsortiAraci
{
    static class Program
    {
        [DllImport("user32.dll")]
        static extern bool SetProcessDPIAware();

        [STAThread]
        static void Main(string[] args)
        {
            bool ilk;
            using (Mutex tek = new Mutex(true, "Local\\AsortiAraciAcilis", out ilk))
            {
                if (!ilk) return;   // acilis ekrani zaten gorunuyor
                Thread bekci = new Thread(delegate() { Thread.Sleep(200000); Environment.Exit(0); });
                bekci.IsBackground = true;
                bekci.Start();
                // beklenmedik bir hata olursa hata penceresi cikmasin: acilis ekrani sessizce kapanir (uygulama yine acilir)
                Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
                Application.ThreadException += delegate { try { Application.Exit(); } catch { } };
                AppDomain.CurrentDomain.UnhandledException += delegate { Environment.Exit(0); };
                try { SetProcessDPIAware(); } catch { }
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new Acilis(args));
                GC.KeepAlive(tek);
            }
        }
    }

    sealed class Acilis : Form
    {
        delegate bool PencereGez(IntPtr h, IntPtr l);
        [DllImport("user32.dll")] static extern bool EnumWindows(PencereGez f, IntPtr l);
        [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
        [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
        [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int c);
        [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
        [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr sonra, int x, int y, int cx, int cy, uint bayrak);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);

        // sureler (ms)
        const double BELIR = 180, KAYBOL = 480, EN_AZ = 250, ACIK_YEDEK = 3000, PENCERE_YEDEK = 12000, UZUN = 10000, HATA = 45000, EN_COK = 180000;
        const double OPAK = 0.997;   // tam 1 olunca pencere katmanli olmaktan cikar ve bir an titrer

        readonly string sis, kok, kilit;
        readonly int port = 8642;
        readonly bool koyu;
        readonly Color soluk, izRenk, mavi = Color.FromArgb(10, 132, 255);
        float olcek = 1f;
        Bitmap tuval;
        Rectangle halR, notR;
        Font notYazi;
        string not = "";

        readonly Stopwatch sw = Stopwatch.StartNew();
        readonly System.Windows.Forms.Timer saat = new System.Windows.Forms.Timer();
        volatile int asama;          // 0 beliriyor, 1 bekliyor, 2 kayboluyor, 3 acilamadi
        double asamaT, beklemeT, acikT = -1, pencereT = -1, sonTaze, sonBak, sonPencere;
        bool uzunYazildi;
        volatile int haber = -1;     // arka plandan: -1 cevap yok, 0 pencere yok, 1 pencere acik, 2 sayfa ekranda, 3 eski surum
        volatile bool bitti;

        public Acilis(string[] args)
        {
            sis = Path.GetDirectoryName(Application.ExecutablePath);
            kok = Path.GetDirectoryName(sis);
            kilit = Path.Combine(kok, "kopru\\log\\acilis.txt");
            string tema = null;
            bool portVar = false;
            foreach (string a in args)
            {
                int p;
                if (a.StartsWith("p=") && int.TryParse(a.Substring(2), out p) && p > 0) { port = p; portVar = true; }
                else if (a.StartsWith("t=")) tema = a.Substring(2);
            }
            if (!portVar)
            {
                string ps = Bul(Oku(Path.Combine(kok, "ayarlar.json")), "\"port\"\\s*:\\s*(\\d+)");
                int p;
                if (ps != null && int.TryParse(ps, out p) && p > 0) port = p;
            }
            if (tema == null) tema = Bul(Oku(Path.Combine(kok, "kullanici.json")), "\"tema\"\\s*:\\s*\"(\\w+)\"");
            koyu = tema == "dark";
            soluk = koyu ? Color.FromArgb(161, 161, 166) : Color.FromArgb(110, 110, 115);
            izRenk = Color.FromArgb(46, 120, 120, 128);

            Text = "Asorti Ara\u0131";
            FormBorderStyle = FormBorderStyle.None;
            StartPosition = FormStartPosition.Manual;
            ShowInTaskbar = false;
            TopMost = true;
            KeyPreview = true;
            Cursor = Cursors.AppStarting;
            BackColor = koyu ? Color.FromArgb(10, 12, 19) : Color.FromArgb(238, 240, 246);
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.Opaque, true);
            try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
            Opacity = 0;
            Bounds = Yer();
        }

        // uygulama penceresi nerede acilacaksa orasi: Edge'in sakladigi son yer (hangi ekran), yoksa ana ekran
        Rectangle Yer()
        {
            Screen ekran = Screen.PrimaryScreen;
            try
            {
                Match m = Regex.Match(Oku(Path.Combine(kok, "profil\\Default\\Preferences")), "\"localhost_/\"\\s*:\\s*\\{([^{}]*)\\}");
                if (m.Success)
                {
                    string s = m.Groups[1].Value;
                    int l = Sayi(s, "work_area_left"), t = Sayi(s, "work_area_top"), r = Sayi(s, "work_area_right"), b = Sayi(s, "work_area_bottom");
                    if (r > l && b > t)
                    {
                        Point orta = new Point((l + r) / 2, (t + b) / 2);
                        foreach (Screen e in Screen.AllScreens) if (e.Bounds.Contains(orta)) { ekran = e; break; }
                    }
                }
            }
            catch { }
            return ekran.WorkingArea;
        }

        protected override void OnLoad(EventArgs e)
        {
            base.OnLoad(e);
            try { using (Graphics g = CreateGraphics()) olcek = Math.Max(1f, g.DpiX / 96f); } catch { }
            try { Hazirla(); } catch { tuval = null; }
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            asamaT = beklemeT = sonTaze = sw.Elapsed.TotalMilliseconds;
            // acilisi baslatan betige "gorundum" de: uygulama penceresi bunun arkasinda acilsin
            for (int i = 0; i < 3; i++)
            {
                try { if (File.Exists(kilit)) File.WriteAllText(kilit, "gorundu " + DateTime.Now.ToString("s")); break; }
                catch { Thread.Sleep(30); }
            }
            saat.Interval = 15;
            saat.Tick += Tik;
            saat.Start();
            Thread th = new Thread(Dinle);
            th.IsBackground = true;
            th.Start();
        }

        // sabit kisim bir kez cizilir: arka plan + simge + yazi; her karede sadece ilerleme cubugu yenilenir
        void Hazirla()
        {
            int w = Math.Max(1, ClientSize.Width), h = Math.Max(1, ClientSize.Height);
            tuval = new Bitmap(w, h, PixelFormat.Format32bppPArgb);
            int cx = w / 2;
            int ortaUst = (int)Math.Round(h / 2.0 - 88 * olcek);
            using (Graphics g = Graphics.FromImage(tuval))
            {
                using (Bitmap z = Zemin(w, h, koyu))
                using (ImageAttributes ia = new ImageAttributes())
                {
                    ia.SetWrapMode(WrapMode.TileFlipXY);
                    g.InterpolationMode = InterpolationMode.HighQualityBilinear;
                    g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                    g.DrawImage(z, new Rectangle(0, 0, w, h), 0, 0, z.Width, z.Height, GraphicsUnit.Pixel, ia);
                }
                float resimOlcek;
                string resim = ResimSec(out resimOlcek);
                if (resim != null)
                {
                    try
                    {
                        using (Bitmap im = new Bitmap(resim))
                        {
                            float k = olcek / resimOlcek;
                            int iw = (int)Math.Round(im.Width * k), ih = (int)Math.Round(im.Height * k);
                            int x = (int)Math.Round(cx - 120 * olcek), y = ortaUst - (int)Math.Round(24 * olcek);
                            bool birebir = iw == im.Width && ih == im.Height;
                            g.InterpolationMode = birebir ? InterpolationMode.NearestNeighbor : InterpolationMode.HighQualityBicubic;
                            g.PixelOffsetMode = birebir ? PixelOffsetMode.Half : PixelOffsetMode.HighQuality;
                            g.DrawImage(im, new Rectangle(x, y, iw, ih), 0, 0, im.Width, im.Height, GraphicsUnit.Pixel);
                        }
                    }
                    catch { }
                }
            }
            halR = new Rectangle((int)Math.Round(cx - 60 * olcek), ortaUst + (int)Math.Round(136 * olcek), (int)Math.Round(120 * olcek), Math.Max(2, (int)Math.Round(3 * olcek)));
            notR = new Rectangle((int)Math.Round(cx - 200 * olcek), ortaUst + (int)Math.Round(155 * olcek), (int)Math.Round(400 * olcek), (int)Math.Round(60 * olcek));
            notYazi = new Font("Segoe UI", 12.5f * olcek, FontStyle.Regular, GraphicsUnit.Pixel);
        }

        // ekran olcegine en uygun hazir resim (simge + "Asorti Araci" yazisi, uygulamanin kendi yazi tipiyle)
        string ResimSec(out float resimOlcek)
        {
            int[] olcekler = { 100, 125, 150, 175, 200, 250, 300 };
            string tema = koyu ? "koyu" : "acik";
            string secilen = null, enBuyuk = null;
            resimOlcek = 1f;
            float enBuyukOlcek = 1f;
            foreach (int o in olcekler)
            {
                string f = Path.Combine(sis, "acilis\\orta_" + tema + "_" + o + ".png");
                if (!File.Exists(f)) continue;
                enBuyuk = f; enBuyukOlcek = o / 100f;
                if (secilen == null && o >= olcek * 100 - 1) { secilen = f; resimOlcek = o / 100f; }
            }
            if (secilen == null && enBuyuk != null) { secilen = enBuyuk; resimOlcek = enBuyukOlcek; }
            return secilen;
        }

        // uygulamanin arka plani (renkli yumusak lekeler). Hizli olsun diye yari boyda hesaplanip buyutulerek cizilir;
        // renk gecislerinde bant (basamak) gorunmesin diye Edge'deki gibi cok hafif titrestirilir (dither).
        static Bitmap Zemin(int w, int h, bool koyu)
        {
            const int K = 2;
            int bw = Math.Max(1, (w + K - 1) / K), bh = Math.Max(1, (h + K - 1) / K);
            double[] zemin = koyu ? new double[] { 10, 12, 19 } : new double[] { 238, 240, 246 };
            // her leke: x%, y%, yaricap x (vmax), yaricap y (vmax), r, g, b  (CSS'teki sirayla: ilk yazilan en ustte)
            double[][] leke = koyu
                ? new double[][] { new double[] { .10, .06, 55, 48, 28, 47, 112 }, new double[] { .92, .10, 50, 44, 59, 34, 102 }, new double[] { .78, .98, 56, 50, 23, 63, 82 }, new double[] { .06, .92, 46, 42, 74, 42, 58 } }
                : new double[][] { new double[] { .10, .06, 55, 48, 201, 220, 255 }, new double[] { .92, .10, 50, 44, 228, 214, 255 }, new double[] { .78, .98, 56, 50, 255, 226, 210 }, new double[] { .06, .92, 46, 42, 205, 238, 229 } };
            double vmax = Math.Max(w, h) / 100.0;
            int[] px = new int[bw * bh];
            uint rs = 2463534242u;
            for (int y = 0; y < bh; y++)
            {
                double Y = (y + 0.5) * K;
                for (int x = 0; x < bw; x++)
                {
                    double X = (x + 0.5) * K, r = zemin[0], g = zemin[1], b = zemin[2];
                    for (int i = leke.Length - 1; i >= 0; i--)
                    {
                        double[] L = leke[i];
                        double dx = (X - L[0] * w) / (L[2] * vmax), dy = (Y - L[1] * h) / (L[3] * vmax);
                        double a = 1 - Math.Sqrt(dx * dx + dy * dy) / 0.62;
                        if (a <= 0) continue;
                        r = L[4] * a + r * (1 - a); g = L[5] * a + g * (1 - a); b = L[6] * a + b * (1 - a);
                    }
                    rs ^= rs << 13; rs ^= rs >> 17; rs ^= rs << 5;
                    double n = ((rs & 0xFFFF) + (rs >> 16)) / 65535.0 - 1.0;   // -1..1 arasi ucgen dagilimli gurultu
                    px[y * bw + x] = unchecked((int)0xFF000000) | (Kanal(r + n) << 16) | (Kanal(g + n) << 8) | Kanal(b + n);
                }
            }
            Bitmap bmp = new Bitmap(bw, bh, PixelFormat.Format32bppArgb);
            BitmapData bd = bmp.LockBits(new Rectangle(0, 0, bw, bh), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            try { for (int y = 0; y < bh; y++) Marshal.Copy(px, y * bw, bd.Scan0 + y * bd.Stride, bw); }
            finally { bmp.UnlockBits(bd); }
            return bmp;
        }

        static int Kanal(double v) { int k = (int)Math.Floor(v + 0.5); return k < 0 ? 0 : (k > 255 ? 255 : k); }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            Rectangle c = e.ClipRectangle;
            if (tuval == null) g.Clear(BackColor);
            else
            {
                g.CompositingMode = CompositingMode.SourceCopy;
                g.InterpolationMode = InterpolationMode.NearestNeighbor;
                g.PixelOffsetMode = PixelOffsetMode.Half;
                g.DrawImage(tuval, c, c, GraphicsUnit.Pixel);
                g.CompositingMode = CompositingMode.SourceOver;
            }
            if (asama != 3 && c.IntersectsWith(halR)) Cubuk(g);
            if (not.Length > 0 && c.IntersectsWith(notR) && notYazi != null)
                TextRenderer.DrawText(g, not, notYazi, notR, soluk, TextFormatFlags.HorizontalCenter | TextFormatFlags.Top | TextFormatFlags.WordBreak | TextFormatFlags.NoPadding);
        }

        // ince mavi ilerleme cubugu (uygulamadaki gibi soldan saga kayar)
        void Cubuk(Graphics g)
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            RectangleF iz = new RectangleF(halR.X, halR.Y, halR.Width, halR.Height);
            float r = Math.Min(2f * olcek, iz.Height / 2f);
            using (SolidBrush b = new SolidBrush(izRenk))
            using (GraphicsPath p = Yuvarlak(iz, r)) g.FillPath(b, p);
            double faz = (sw.Elapsed.TotalMilliseconds % 1100.0) / 1100.0;
            float pw = iz.Width * 0.4f;
            float x = iz.X + (float)((-1.10 + 3.90 * Bezier(0.45, 0.05, 0.55, 0.95, faz)) * pw);
            float x0 = Math.Max(x, iz.X), x1 = Math.Min(x + pw, iz.Right);
            if (x1 - x0 < 0.5f) return;
            using (SolidBrush m = new SolidBrush(mavi))
            using (GraphicsPath q = Yuvarlak(new RectangleF(x0, iz.Y, x1 - x0, iz.Height), Math.Min(r, (x1 - x0) / 2f))) g.FillPath(m, q);
        }

        static GraphicsPath Yuvarlak(RectangleF k, float r)
        {
            GraphicsPath p = new GraphicsPath();
            float d = r * 2;
            if (d < 0.01f || k.Width < d || k.Height < d) { p.AddRectangle(k); return p; }
            p.AddArc(k.X, k.Y, d, d, 180, 90);
            p.AddArc(k.Right - d, k.Y, d, d, 270, 90);
            p.AddArc(k.Right - d, k.Bottom - d, d, d, 0, 90);
            p.AddArc(k.X, k.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }

        // CSS cubic-bezier ile ayni egri
        static double Bezier(double x1, double y1, double x2, double y2, double x)
        {
            if (x <= 0) return 0;
            if (x >= 1) return 1;
            double lo = 0, hi = 1, s = x;
            for (int i = 0; i < 30; i++)
            {
                double xs = 3 * (1 - s) * (1 - s) * s * x1 + 3 * (1 - s) * s * s * x2 + s * s * s;
                if (Math.Abs(xs - x) < 1e-6) break;
                if (xs < x) lo = s; else hi = s;
                s = (lo + hi) / 2;
            }
            return 3 * (1 - s) * (1 - s) * s * y1 + 3 * (1 - s) * s * s * y2 + s * s * s;
        }

        void Tik(object sender, EventArgs e)
        {
            if (bitti) return;
            double t = sw.Elapsed.TotalMilliseconds;
            if (t > EN_COK) { Bitir(); return; }
            int hb = haber;
            if (asama == 0)
            {
                double p = Math.Min(1.0, (t - asamaT) / BELIR);
                Opacity = OPAK * (1 - Math.Pow(1 - p, 3));
                if (p >= 1) { asama = 1; asamaT = t; }
            }
            if (asama == 1 || asama == 3)
            {
                if ((hb == 1 || hb == 2) && acikT < 0) acikT = t;
                // program cevap veremese bile: uygulama penceresi uzun suredir aciksa onu bekletme
                if (t - sonPencere > 500)
                {
                    sonPencere = t;
                    if (UygulamaPenceresi() != IntPtr.Zero) { if (pencereT < 0) pencereT = t; } else pencereT = -1;
                }
                bool eski = hb == 3 && t - beklemeT > 2500;
                bool hazir = hb == 2 || (acikT >= 0 && t - acikT > ACIK_YEDEK) || (pencereT >= 0 && t - pencereT > PENCERE_YEDEK) || eski;
                if (hazir && (asama == 3 || t - asamaT >= EN_AZ)) Kaybol(t, !eski);
            }
            if (asama == 1)
            {
                double g = t - beklemeT;
                if (!uzunYazildi && g > UZUN) { uzunYazildi = true; Yaz("H\u00e2l\u00e2 a\u00e7\u0131l\u0131yor, l\u00fctfen bekle\u2026"); }
                if (t - sonTaze > 5000) { sonTaze = t; KilitTazele(); }
                if (g > HATA) Acilamadi();
            }
            else if (asama == 3 && t - sonBak > 500)
            {
                sonBak = t;
                if (File.Exists(kilit)) Bastan(t);   // simgeye yeniden tiklandi: yeniden bekle
            }
            if (asama == 2)
            {
                double q = Math.Min(1.0, (t - asamaT) / KAYBOL);
                Opacity = OPAK * (1 - Bezier(0.4, 0, 0.2, 1, q));
                if (q >= 1) { Bitir(); return; }
            }
            if (asama != 3) Invalidate(halR);
        }

        void Yaz(string s) { not = s; Invalidate(notR); }

        void Kaybol(double t, bool acildi)
        {
            if (asama == 2) return;
            asama = 2; asamaT = t;
            if (!acildi) return;
            KilitSil();
            try
            {
                IntPtr h = UygulamaPenceresi();
                if (h != IntPtr.Zero)
                {
                    if (IsIconic(h)) ShowWindow(h, 9);
                    SetWindowPos(h, IntPtr.Zero, 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0010);   // en uste (bu ekranin hemen arkasina), boyutuna dokunmadan
                    SetForegroundWindow(h);
                }
            }
            catch { }
        }

        void Acilamadi()
        {
            asama = 3; asamaT = sw.Elapsed.TotalMilliseconds;
            KilitSil();   // isaret kalkar: simgeye tekrar tiklaninca bastan acilir
            TopMost = false;
            Yaz("A\u00e7\u0131lamad\u0131. Bu ekrana t\u0131klay\u0131p kapat,\nsonra masa\u00fcst\u00fcndeki simgeden tekrar a\u00e7.");
            Invalidate(halR);
        }

        void Bastan(double t)
        {
            asama = 1; asamaT = beklemeT = sonTaze = t; acikT = -1; pencereT = -1; uzunYazildi = false;
            TopMost = true;
            Yaz("");
            Invalidate();
            try { Activate(); } catch { }
        }

        void Bitir()
        {
            if (bitti) return;
            bitti = true;
            saat.Stop();
            Close();
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            base.OnKeyDown(e);
            if (e.KeyCode == Keys.Escape) Kaybol(sw.Elapsed.TotalMilliseconds, false);
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            base.OnMouseUp(e);
            if (asama == 3) Kaybol(sw.Elapsed.TotalMilliseconds, false);
        }

        // arka planda: uygulama penceresi acildi mi, ilk sayfasi ekrana cizildi mi (program /pencere ile soyler)
        void Dinle()
        {
            string adres = "http://localhost:" + port + "/pencere?a=";
            while (!bitti)
            {
                int sonuc = -1;
                try
                {
                    HttpWebRequest r = (HttpWebRequest)WebRequest.Create(adres + DateTime.Now.Ticks.ToString());
                    r.Proxy = null;
                    r.Timeout = 2500;
                    r.ReadWriteTimeout = 2500;
                    r.KeepAlive = false;
                    using (WebResponse y = r.GetResponse())
                    using (StreamReader sr = new StreamReader(y.GetResponseStream(), Encoding.UTF8))
                    {
                        string j = sr.ReadToEnd();
                        if (j.IndexOf("\"acik\":true", StringComparison.Ordinal) < 0) sonuc = 0;
                        else sonuc = j.IndexOf("\"hazir\":true", StringComparison.Ordinal) < 0 ? 1 : 2;
                    }
                }
                catch (WebException we)
                {
                    HttpWebResponse y = we.Response as HttpWebResponse;
                    if (y != null && y.StatusCode == HttpStatusCode.NotFound) sonuc = 3;
                }
                catch { }
                if (sonuc >= 0) haber = sonuc;
                Thread.Sleep(asama == 3 ? 1000 : 250);
            }
        }

        static IntPtr UygulamaPenceresi()
        {
            IntPtr bulunan = IntPtr.Zero;
            StringBuilder ad = new StringBuilder(256), sinif = new StringBuilder(64);
            EnumWindows(delegate(IntPtr h, IntPtr l)
            {
                if (!IsWindowVisible(h)) return true;
                ad.Length = 0;
                GetWindowText(h, ad, ad.Capacity);
                if (!ad.ToString().StartsWith("Asorti Ara", StringComparison.Ordinal)) return true;
                sinif.Length = 0;
                GetClassName(h, sinif, sinif.Capacity);
                if (!sinif.ToString().StartsWith("Chrome_WidgetWin", StringComparison.Ordinal)) return true;
                bulunan = h;
                return false;
            }, IntPtr.Zero);
            return bulunan;
        }

        void KilitTazele() { try { if (File.Exists(kilit)) File.SetLastWriteTime(kilit, DateTime.Now); } catch { } }
        void KilitSil() { try { if (File.Exists(kilit)) File.Delete(kilit); } catch { } }

        static string Oku(string f) { try { return File.Exists(f) ? File.ReadAllText(f, Encoding.UTF8) : ""; } catch { return ""; } }
        static string Bul(string s, string desen) { Match m = Regex.Match(s, desen); return m.Success ? m.Groups[1].Value : null; }
        static int Sayi(string s, string ad) { string v = Bul(s, "\"" + ad + "\"\\s*:\\s*(-?\\d+)"); int n; return v != null && int.TryParse(v, out n) ? n : 0; }
    }
}
