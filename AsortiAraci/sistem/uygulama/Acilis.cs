// Asorti Aracı - açılış ekranı: pencerenin içini uygulamanın kendi görünümüyle kaplar
// (renkli yumuşak lekeler, simge, "Asorti Aracı" yazısı, ince mavi çubuk). Uygulama hazır olunca saydamlaşarak kaybolur.
// Görünüm uygulamanın açılış sayfasıyla (sistem\acilis.html) birebir aynıdır; simge ve yazı uygulamanın yazı tipiyle
// hazır çizilmiş resimlerden (sistem\acilis\orta_*.png) gelir.
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace AsortiAraci
{
    sealed class AcilisCizim : IDisposable
    {
        public readonly bool Koyu;
        public float Olcek = 1f;
        public Bitmap Tuval;
        public Rectangle HalR, NotR;
        public readonly Color Zemin;
        Font notYazi;
        readonly Color soluk, iz = Color.FromArgb(46, 120, 120, 128), mavi = Color.FromArgb(10, 132, 255);
        Size boyut = Size.Empty;

        public AcilisCizim(bool koyu)
        {
            Koyu = koyu;
            Zemin = koyu ? Color.FromArgb(10, 12, 19) : Color.FromArgb(238, 240, 246);
            soluk = koyu ? Color.FromArgb(161, 161, 166) : Color.FromArgb(110, 110, 115);
        }

        // sabit kısım (arka plan + simge + yazı) bir kez çizilir; her karede sadece ilerleme çubuğu yenilenir
        public void Hazirla(Size s, float olcek)
        {
            if (s.Width < 1 || s.Height < 1) return;
            if (s == boyut && Math.Abs(olcek - Olcek) < 0.001f && Tuval != null) return;
            boyut = s;
            Olcek = olcek;
            int w = s.Width, h = s.Height, cx = w / 2;
            int ortaUst = (int)Math.Round(h / 2.0 - 88 * olcek);
            Bitmap t = new Bitmap(w, h, PixelFormat.Format32bppPArgb);
            using (Graphics g = Graphics.FromImage(t))
            {
                using (Bitmap z = ZeminCiz(w, h, Koyu))
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
            if (Tuval != null) Tuval.Dispose();
            Tuval = t;
            HalR = new Rectangle((int)Math.Round(cx - 60 * olcek), ortaUst + (int)Math.Round(136 * olcek), (int)Math.Round(120 * olcek), Math.Max(2, (int)Math.Round(3 * olcek)));
            NotR = new Rectangle((int)Math.Round(cx - 210 * olcek), ortaUst + (int)Math.Round(155 * olcek), (int)Math.Round(420 * olcek), (int)Math.Round(60 * olcek));
            if (notYazi != null) notYazi.Dispose();
            notYazi = new Font("Segoe UI", 12.5f * olcek, FontStyle.Regular, GraphicsUnit.Pixel);
        }

        // ekran ölçeğine en uygun hazır resim
        string ResimSec(out float resimOlcek)
        {
            int[] olcekler = { 100, 125, 150, 175, 200, 250, 300 };
            string tema = Koyu ? "koyu" : "acik";
            string secilen = null, enBuyuk = null;
            resimOlcek = 1f;
            float enBuyukOlcek = 1f;
            foreach (int o in olcekler)
            {
                string f = Path.Combine(Path.Combine(Yer.Sistem, "acilis"), "orta_" + tema + "_" + o + ".png");
                if (!File.Exists(f)) continue;
                enBuyuk = f;
                enBuyukOlcek = o / 100f;
                if (secilen == null && o >= Olcek * 100 - 1) { secilen = f; resimOlcek = o / 100f; }
            }
            if (secilen == null && enBuyuk != null) { secilen = enBuyuk; resimOlcek = enBuyukOlcek; }
            return secilen;
        }

        // uygulamanın arka planı (renkli yumuşak lekeler). Yarı boyda hesaplanıp büyütülür; renk geçişlerinde bant
        // (basamak) görünmesin diye çok hafif titreştirilir.
        static Bitmap ZeminCiz(int w, int h, bool koyu)
        {
            const int K = 2;
            int bw = Math.Max(1, (w + K - 1) / K), bh = Math.Max(1, (h + K - 1) / K);
            double[] zemin = koyu ? new double[] { 10, 12, 19 } : new double[] { 238, 240, 246 };
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
                    double n = ((rs & 0xFFFF) + (rs >> 16)) / 65535.0 - 1.0;
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

        public void Ciz(Graphics g, Rectangle c, bool cubuk, string not, double zaman)
        {
            if (Tuval == null) { using (SolidBrush b = new SolidBrush(Zemin)) g.FillRectangle(b, c); return; }
            g.CompositingMode = CompositingMode.SourceCopy;
            g.InterpolationMode = InterpolationMode.NearestNeighbor;
            g.PixelOffsetMode = PixelOffsetMode.Half;
            g.DrawImage(Tuval, c, c, GraphicsUnit.Pixel);
            g.CompositingMode = CompositingMode.SourceOver;
            if (cubuk && c.IntersectsWith(HalR)) Cubuk(g, zaman);
            if (!string.IsNullOrEmpty(not) && c.IntersectsWith(NotR) && notYazi != null)
                TextRenderer.DrawText(g, not, notYazi, NotR, soluk, TextFormatFlags.HorizontalCenter | TextFormatFlags.Top | TextFormatFlags.WordBreak | TextFormatFlags.NoPadding);
        }

        // ince mavi ilerleme çubuğu (uygulamadaki gibi soldan sağa kayar)
        void Cubuk(Graphics g, double zaman)
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            RectangleF r0 = new RectangleF(HalR.X, HalR.Y, HalR.Width, HalR.Height);
            float r = Math.Min(2f * Olcek, r0.Height / 2f);
            using (SolidBrush b = new SolidBrush(iz))
            using (GraphicsPath p = Yuvarlak(r0, r)) g.FillPath(b, p);
            double faz = (zaman % 1100.0) / 1100.0;
            float pw = r0.Width * 0.4f;
            float x = r0.X + (float)((-1.10 + 3.90 * Bezier(0.45, 0.05, 0.55, 0.95, faz)) * pw);
            float x0 = Math.Max(x, r0.X), x1 = Math.Min(x + pw, r0.Right);
            if (x1 - x0 < 0.5f) return;
            using (SolidBrush m = new SolidBrush(mavi))
            using (GraphicsPath q = Yuvarlak(new RectangleF(x0, r0.Y, x1 - x0, r0.Height), Math.Min(r, (x1 - x0) / 2f))) g.FillPath(m, q);
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

        // CSS cubic-bezier ile aynı eğri
        public static double Bezier(double x1, double y1, double x2, double y2, double x)
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

        public void Dispose()
        {
            if (Tuval != null) { Tuval.Dispose(); Tuval = null; }
            if (notYazi != null) { notYazi.Dispose(); notYazi = null; }
        }
    }

    // pencerenin içini (başlık çubuğu hariç) tam kaplayan, pencereye bağlı saydamlaşabilen katman.
    // Uygulama arkasında açılır ve ekrana çizilir; hazır olunca bu katman yumuşakça solar.
    sealed class AcilisKatmani : Form
    {
        const double OPAK = 0.997;     // tam 1 olunca pencere katmanlı olmaktan çıkar ve bir an titrer
        const double KAYBOL = 480;     // ms
        readonly Form sahip;
        readonly AcilisCizim cizim;
        readonly System.Windows.Forms.Timer saat = new System.Windows.Forms.Timer();
        readonly Stopwatch sw = Stopwatch.StartNew();
        double kayT = -1;
        string not = "";
        bool cubuk = true;
        public event EventHandler Bitti;

        public AcilisKatmani(Form sahip, AcilisCizim cizim)
        {
            this.sahip = sahip;
            this.cizim = cizim;
            FormBorderStyle = FormBorderStyle.None;
            StartPosition = FormStartPosition.Manual;
            ShowInTaskbar = false;
            ControlBox = false;
            Text = "";
            BackColor = cizim.Zemin;
            Cursor = Cursors.AppStarting;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.Opaque, true);
            Opacity = OPAK;
            saat.Interval = 15;
            saat.Tick += Tik;
        }

        protected override bool ShowWithoutActivation { get { return true; } }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                cp.ExStyle |= 0x08000000 | 0x00000080;   // WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW: odak almaz, görev çubuğunda ve Alt+Tab'da görünmez
                return cp;
            }
        }

        public void Goster()
        {
            Hizala();
            Show(sahip);
            saat.Start();
        }

        // pencerenin iç alanının tam üstünde dursun
        public void Hizala()
        {
            if (IsDisposed || sahip.IsDisposed || sahip.WindowState == FormWindowState.Minimized) return;
            Rectangle r = sahip.RectangleToScreen(sahip.ClientRectangle);
            if (r.Width < 1 || r.Height < 1) return;
            cizim.Hazirla(r.Size, cizim.Olcek);
            if (Bounds != r) Bounds = r;
            Invalidate();
        }

        public void Yaz(string s, bool cubukGorunsun)
        {
            not = s ?? "";
            cubuk = cubukGorunsun;
            Invalidate();
        }

        public void Kaybol()
        {
            if (kayT >= 0 || IsDisposed) return;
            kayT = sw.Elapsed.TotalMilliseconds;
        }

        public bool Kayboluyor { get { return kayT >= 0; } }

        void Tik(object sender, EventArgs e)
        {
            double t = sw.Elapsed.TotalMilliseconds;
            if (kayT >= 0)
            {
                double q = Math.Min(1.0, (t - kayT) / KAYBOL);
                Opacity = OPAK * (1 - AcilisCizim.Bezier(0.4, 0, 0.2, 1, q));
                if (q >= 1)
                {
                    saat.Stop();
                    EventHandler b = Bitti;
                    Close();
                    if (b != null) b(this, EventArgs.Empty);
                    return;
                }
            }
            if (cubuk) Invalidate(cizim.HalR);
        }

        protected override void OnPaintBackground(PaintEventArgs e) { }

        protected override void OnPaint(PaintEventArgs e)
        {
            cizim.Ciz(e.Graphics, e.ClipRectangle, cubuk, not, sw.Elapsed.TotalMilliseconds);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) saat.Dispose();
            base.Dispose(disposing);
        }
    }
}
