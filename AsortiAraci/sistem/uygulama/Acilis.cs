// Eleman - açılış ekranı: pencerenin içini düz zemin ve ortada Eleman simgesiyle kaplar (X / Twitter'ın açılışı gibi).
// Sayfa da aynı görüntüyle açılır; bu katman kalkınca simge sayfada küçülüp büyüyerek uygulamayı açar (uygulama.html).
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
        readonly Color soluk, iz = Color.FromArgb(46, 120, 120, 128), mavi = Color.FromArgb(245, 176, 0);   // Eleman sarısı (çubuk)
        Size boyut = Size.Empty;

        public AcilisCizim(bool koyu)
        {
            Koyu = koyu;
            Zemin = koyu ? Color.FromArgb(10, 12, 19) : Color.FromArgb(226, 231, 240);   // açık: sistem/eleman_cam.css --bg (#e2e7f0)
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
            Bitmap t = new Bitmap(w, h, PixelFormat.Format32bppPArgb);
            using (Graphics g = Graphics.FromImage(t))
            {
                g.Clear(Zemin);   // düz zemin: sayfanın açılış görüntüsüyle birebir aynı
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
                            int x = cx - iw / 2, y = h / 2 - ih / 2;   // simge tam ortada
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
            int alt = (int)Math.Round(h / 2.0 + 52 * olcek);   // simgenin alt kenarı
            HalR = new Rectangle((int)Math.Round(cx - 60 * olcek), alt + (int)Math.Round(34 * olcek), (int)Math.Round(120 * olcek), Math.Max(2, (int)Math.Round(3 * olcek)));
            NotR = new Rectangle((int)Math.Round(cx - 210 * olcek), alt + (int)Math.Round(53 * olcek), (int)Math.Round(420 * olcek), (int)Math.Round(60 * olcek));
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
            double[] zemin = koyu ? new double[] { 10, 12, 19 } : new double[] { 226, 231, 240 };
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

    // pencerenin içini tam kaplayan, pencereye bağlı saydamlaşabilen katman.
    // Uygulama arkasında açılır ve ekrana çizilir; hazır olunca bu katman yumuşakça solar.
    // Tek parça başlıkta açılış sırasında da pencere düğmeleri (küçült, büyüt, kapat) aynı yerde durur ve pencere üstten tutulup taşınır.
    sealed class AcilisKatmani : Form
    {
        [DllImport("user32.dll")] static extern bool ReleaseCapture();
        [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, int m, IntPtr w, IntPtr l);

        const double OPAK = 0.997;     // tam 1 olunca pencere katmanlı olmaktan çıkar ve bir an titrer
        const double KAYBOL = 140;     // ms (sayfa aynı görüntüyle altta hazır bekliyor)
        readonly Form sahip;
        readonly AcilisCizim cizim;
        readonly System.Windows.Forms.Timer saat = new System.Windows.Forms.Timer();
        readonly Stopwatch sw = Stopwatch.StartNew();
        double kayT = -1;
        string not = "";
        bool cubuk = false;   // ilerleme çubuğu yalnız açılış uzarsa (Yaz) görünür
        public event EventHandler Bitti;
        bool dugmeler, surukle;
        int ustune = -1, basili = -1;   // fare hangi düğmenin üstünde / hangisine basıldı (0 küçült, 1 büyüt, 2 kapat)
        Point basma;
        readonly float yak = 1f;        // sayfanın yakınlaştırması (düğmeler sayfadakiyle aynı yerde olsun)

        public bool Dugmeler
        {
            get { return dugmeler; }
            set { dugmeler = value; if (IsHandleCreated) Invalidate(); }
        }

        public AcilisKatmani(Form sahip, AcilisCizim cizim)
        {
            this.sahip = sahip;
            this.cizim = cizim;
            double z;
            if (double.TryParse(Kullanici.Al("yakinlik"), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out z) && z >= 0.25 && z <= 5) yak = (float)z;
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
            DugmeleriCiz(e.Graphics, e.ClipRectangle);
        }

        // ---------- pencere düğmeleri (sayfadaki üst çubuktakilerle aynı ölçü ve yerde) ----------
        float Bir { get { return cizim.Olcek * yak; } }
        int CubukYuk { get { return (int)Math.Round(54 * Bir); } }

        Rectangle Dugme(int i)
        {
            int w = (int)Math.Round(46 * Bir);
            return new Rectangle(ClientSize.Width - (3 - i) * w, 0, w, CubukYuk);
        }

        int DugmeBul(Point p)
        {
            if (!dugmeler) return -1;
            for (int i = 0; i < 3; i++) if (Dugme(i).Contains(p)) return i;
            return -1;
        }

        void DugmeleriCiz(Graphics g, Rectangle clip)
        {
            if (!dugmeler) return;
            Color yazi = cizim.Koyu ? Color.FromArgb(245, 245, 247) : Color.FromArgb(29, 29, 31);
            bool tam = sahip.WindowState == FormWindowState.Maximized;
            for (int i = 0; i < 3; i++)
            {
                Rectangle r = Dugme(i);
                if (!r.IntersectsWith(clip)) continue;
                Color c = yazi;
                if (i == ustune || i == basili)
                {
                    Color z = i == 2 ? (i == basili ? Color.FromArgb(176, 38, 26) : Color.FromArgb(196, 43, 28))
                                     : (cizim.Koyu ? Color.FromArgb(i == basili ? 31 : 20, 255, 255, 255) : Color.FromArgb(i == basili ? 26 : 15, 0, 0, 0));
                    g.SmoothingMode = SmoothingMode.None;
                    using (SolidBrush b = new SolidBrush(z)) g.FillRectangle(b, r);
                    if (i == 2) c = Color.White;
                }
                float u = Bir, x = r.X + (float)Math.Round((r.Width - 10 * u) / 2), y = r.Y + (float)Math.Round((r.Height - 10 * u) / 2);
                g.PixelOffsetMode = PixelOffsetMode.None;
                g.SmoothingMode = i == 2 ? SmoothingMode.AntiAlias : SmoothingMode.None;
                using (Pen p = new Pen(c, Math.Max(1f, (float)Math.Round(cizim.Olcek))))
                {
                    if (i == 0) g.DrawLine(p, x, y + 5.5f * u, x + 10 * u, y + 5.5f * u);
                    else if (i == 1 && !tam) g.DrawRectangle(p, x + .5f * u, y + .5f * u, 9 * u, 9 * u);
                    else if (i == 1)
                    {
                        g.DrawRectangle(p, x + .5f * u, y + 2.5f * u, 7 * u, 7 * u);
                        g.DrawLines(p, new PointF[] { new PointF(x + 2.5f * u, y + 2.5f * u), new PointF(x + 2.5f * u, y + .5f * u), new PointF(x + 9.5f * u, y + .5f * u), new PointF(x + 9.5f * u, y + 7.5f * u), new PointF(x + 7.5f * u, y + 7.5f * u) });
                    }
                    else
                    {
                        g.DrawLine(p, x + .5f * u, y + .5f * u, x + 9.5f * u, y + 9.5f * u);
                        g.DrawLine(p, x + 9.5f * u, y + .5f * u, x + .5f * u, y + 9.5f * u);
                    }
                }
            }
            g.SmoothingMode = SmoothingMode.None;
        }

        void Buyut()
        {
            sahip.WindowState = sahip.WindowState == FormWindowState.Maximized ? FormWindowState.Normal : FormWindowState.Maximized;
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);
            int u = DugmeBul(e.Location);
            if (u != ustune)
            {
                if (ustune >= 0) Invalidate(Dugme(ustune));
                ustune = u;
                if (u >= 0) Invalidate(Dugme(u));
            }
            Cursor c = dugmeler && e.Y < CubukYuk ? Cursors.Default : Cursors.AppStarting;
            if (Cursor != c) Cursor = c;
            // üst çubuktan tutup biraz çekince pencere taşınır (Windows'un kendi taşıması: ekran kenarına yapıştırma dahil)
            Size ds = SystemInformation.DragSize;
            if (surukle && (e.Button & MouseButtons.Left) != 0 && (Math.Abs(e.X - basma.X) > ds.Width / 2 || Math.Abs(e.Y - basma.Y) > ds.Height / 2))
            {
                surukle = false;
                Point sp = Cursor.Position;
                ReleaseCapture();
                SendMessage(sahip.Handle, 0x00A1, (IntPtr)2, (IntPtr)((sp.Y << 16) | (sp.X & 0xFFFF)));   // WM_NCLBUTTONDOWN, HTCAPTION
            }
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            base.OnMouseLeave(e);
            if (ustune >= 0) { Invalidate(Dugme(ustune)); ustune = -1; }
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            if (e.Button != MouseButtons.Left || !dugmeler) return;
            basili = DugmeBul(e.Location);
            if (basili >= 0) { Invalidate(Dugme(basili)); return; }
            if (e.Y < CubukYuk) { surukle = true; basma = e.Location; }
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            base.OnMouseUp(e);
            surukle = false;
            int b = basili;
            basili = -1;
            if (b < 0) return;
            Invalidate(Dugme(b));
            if (DugmeBul(e.Location) != b) return;
            if (b == 0) sahip.WindowState = FormWindowState.Minimized;
            else if (b == 1) Buyut();
            else sahip.Close();
        }

        protected override void OnMouseDoubleClick(MouseEventArgs e)
        {
            base.OnMouseDoubleClick(e);
            if (dugmeler && e.Button == MouseButtons.Left && e.Y < CubukYuk && DugmeBul(e.Location) < 0) Buyut();
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) saat.Dispose();
            base.Dispose(disposing);
        }
    }
}
