// Asorti Aracı - uyarı ve onay pencereleri. Sayfadaki uyarı / onay kutuları Edge motorunun "localhost:8642 şunu diyor"
// kutusu yerine bu pencereyle açılır: uygulamanın simgesi ve adı, açık / koyu görünüm, ses çıkarmaz, Ctrl+C yazıyı kopyalar.
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace AsortiAraci
{
    sealed class Uyari : Form
    {
        [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr h, int ad, ref int deger, int boy);

        const TextFormatFlags Bicim = TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix | TextFormatFlags.Left | TextFormatFlags.Top | TextFormatFlags.TextBoxControl;

        readonly string metin, baslik, aciklama;
        readonly bool koyu;
        readonly Font fBaslik, fAciklama, fDugme;
        readonly Image simge;
        readonly Rectangle rSimge, rBaslik, rAciklama;
        readonly Color cYazi, cIkinci;

        // soru: "evet" seçilirse true döner. hayir null ise tek düğmeli uyarı.
        // hayirVarsayilan: geri dönüşü olmayan işlerde Enter "hayır"ı seçer (mavi düğme odur)
        public static bool Sor(IWin32Window sahip, string metin, string evet, string hayir, bool koyu, bool hayirVarsayilan)
        {
            using (Uyari u = new Uyari(metin, evet, hayir, koyu, hayirVarsayilan))
            {
                // pencere simge durumundaysa kutu ekranın ortasında açılır
                Form f = sahip as Form;
                if (f == null || !f.Visible || f.WindowState == FormWindowState.Minimized) u.StartPosition = FormStartPosition.CenterScreen;
                return u.ShowDialog(sahip) == DialogResult.OK;
            }
        }

        public static void Goster(IWin32Window sahip, string metin, bool koyu)
        {
            Sor(sahip, metin, "Tamam", null, koyu, false);
        }

        Uyari(string m, string evet, string hayir, bool koyu, bool hayirVarsayilan)
        {
            this.koyu = koyu;
            metin = (m ?? "").Replace("\r\n", "\n").Replace('\r', '\n').Trim();
            Bol(metin.Length > 1500 ? metin.Substring(0, 1500).TrimEnd() + " …" : metin, out baslik, out aciklama);

            float s = 1f;
            try { using (Graphics g = Graphics.FromHwnd(IntPtr.Zero)) s = Math.Max(1f, g.DpiX / 96f); } catch { }

            Text = "Eleman";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            ShowIcon = false;
            ShowInTaskbar = false;
            StartPosition = FormStartPosition.CenterParent;
            AutoScaleMode = AutoScaleMode.None;
            KeyPreview = true;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
            BackColor = koyu ? Color.FromArgb(32, 33, 38) : Color.White;
            cYazi = koyu ? Color.FromArgb(245, 245, 247) : Color.FromArgb(29, 29, 31);
            cIkinci = koyu ? Color.FromArgb(172, 174, 182) : Color.FromArgb(92, 92, 98);
            fBaslik = new Font("Segoe UI Semibold", 10.5f);
            fAciklama = new Font("Segoe UI", 9.75f);
            fDugme = new Font("Segoe UI", 9.75f);
            Font = fAciklama;
            simge = Logo();

            // yerleşim: solda simge, sağında kalın başlık ve açıklama, altta sağa yaslı düğmeler
            int W = O(440, s), pad = O(24, s), ust = O(22, s), ikon = simge != null ? O(32, s) : 0;
            int x = pad + (ikon > 0 ? ikon + O(16, s) : 0), mw = W - x - pad;
            Size alan = new Size(mw, int.MaxValue);
            int satir = TextRenderer.MeasureText("Ag", baslik.Length > 0 ? fBaslik : fAciklama, alan, Bicim).Height;
            int y = ust + Math.Max(0, (ikon - satir) / 2);   // yazının ilk satırı simgenin ortasında
            if (baslik.Length > 0)
            {
                int h = TextRenderer.MeasureText(baslik, fBaslik, alan, Bicim).Height;
                rBaslik = new Rectangle(x, y, mw, h);
                y += h;
            }
            if (aciklama.Length > 0)
            {
                if (baslik.Length > 0) y += O(6, s);
                int h = TextRenderer.MeasureText(aciklama, fAciklama, alan, Bicim).Height;
                rAciklama = new Rectangle(x, y, mw, h);
                y += h;
            }
            if (ikon > 0)
            {
                rSimge = new Rectangle(pad, ust, ikon, ikon);
                y = Math.Max(y, ust + ikon);
            }
            y += O(22, s);

            int bh = O(32, s), sag = W - pad;
            UyariDugme d2 = null;
            if (hayir != null)
            {
                d2 = Dugme(hayir, DialogResult.Cancel, hayirVarsayilan, s, bh);
                d2.Location = new Point(sag - d2.Width, y);
                sag = d2.Left - O(8, s);
            }
            UyariDugme d1 = Dugme(evet, DialogResult.OK, d2 == null || !hayirVarsayilan, s, bh);
            d1.Location = new Point(sag - d1.Width, y);
            Controls.Add(d1);
            if (d2 != null) Controls.Add(d2);
            UyariDugme varsayilan = d2 != null && hayirVarsayilan ? d2 : d1;
            AcceptButton = varsayilan;
            CancelButton = d2 ?? d1;
            ActiveControl = varsayilan;
            ClientSize = new Size(W, y + bh + O(20, s));
        }

        static int O(int v, float s) { return (int)Math.Round(v * s); }

        // ilk paragraf kalın başlık, gerisi açıklama (macOS uyarıları gibi); uzun tek paragraf kalın yazılmaz
        static void Bol(string m, out string b, out string a)
        {
            b = m;
            a = "";
            int i = m.IndexOf("\n\n", StringComparison.Ordinal);
            if (i > 0) { b = m.Substring(0, i).Trim(); a = m.Substring(i + 2).Trim(); }
            else
            {
                int j = m.IndexOf('\n');
                if (j > 0 && j <= 160) { b = m.Substring(0, j).Trim(); a = m.Substring(j + 1).Trim(); }
            }
            if (a.Length == 0 && b.Length > 120) { a = b; b = ""; }
        }

        // uygulamanın simgesi (dosya kilitlenmez: güncelleme sırasında da değiştirilebilir)
        static Image Logo()
        {
            try
            {
                using (MemoryStream ms = new MemoryStream(File.ReadAllBytes(Simge.Png)))
                using (Image i = Image.FromStream(ms))
                    return new Bitmap(i);
            }
            catch { return null; }
        }

        UyariDugme Dugme(string yazi, DialogResult sonuc, bool ana, float s, int bh)
        {
            UyariDugme d = new UyariDugme();
            d.Text = yazi;
            d.Font = fDugme;
            d.DialogResult = sonuc;
            d.Ana = ana;
            d.Koyu = koyu;
            d.Olcek = s;
            int w = TextRenderer.MeasureText(yazi, fDugme).Width + O(32, s);
            d.Size = new Size(Math.Max(O(88, s), w), bh);
            return d;
        }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            if (!koyu) return;
            try { int v = 1; if (DwmSetWindowAttribute(Handle, 20, ref v, 4) != 0) DwmSetWindowAttribute(Handle, 19, ref v, 4); } catch { }
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.Clear(BackColor);
            if (simge != null)
            {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                g.DrawImage(simge, rSimge);
            }
            if (baslik.Length > 0) TextRenderer.DrawText(g, baslik, fBaslik, rBaslik, cYazi, BackColor, Bicim);
            if (aciklama.Length > 0) TextRenderer.DrawText(g, aciklama, fAciklama, rAciklama, cIkinci, BackColor, Bicim);
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.Control && e.KeyCode == Keys.C && metin.Length > 0)
            {
                try { Clipboard.SetText(metin); } catch { }
                e.Handled = true;
                return;
            }
            base.OnKeyDown(e);
        }

        protected override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
            if (!disposing) return;
            fBaslik.Dispose();
            fAciklama.Dispose();
            fDugme.Dispose();
            if (simge != null) simge.Dispose();
        }
    }

    // yuvarlak köşeli düğme: varsayılan olan mavi, diğeri gri; üstüne gelince / basınca tonu değişir
    sealed class UyariDugme : Button
    {
        public bool Ana, Koyu;
        public float Olcek = 1f;
        bool ust, basili;

        public UyariDugme()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            FlatStyle = FlatStyle.Flat;
            FlatAppearance.BorderSize = 0;
            UseVisualStyleBackColor = false;
        }

        protected override void OnMouseEnter(EventArgs e) { ust = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { ust = false; basili = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnMouseDown(MouseEventArgs e) { if (e.Button == MouseButtons.Left) { basili = true; Invalidate(); } base.OnMouseDown(e); }
        protected override void OnMouseUp(MouseEventArgs e) { basili = false; Invalidate(); base.OnMouseUp(e); }
        protected override void OnGotFocus(EventArgs e) { Invalidate(); base.OnGotFocus(e); }
        protected override void OnLostFocus(EventArgs e) { Invalidate(); base.OnLostFocus(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.Clear(Parent != null ? Parent.BackColor : BackColor);
            Color mavi = Koyu ? Color.FromArgb(10, 132, 255) : Color.FromArgb(0, 122, 255);
            Color dolgu, yazi;
            if (Ana)
            {
                dolgu = basili ? (Koyu ? Color.FromArgb(8, 108, 214) : Color.FromArgb(0, 98, 214)) : ust ? (Koyu ? Color.FromArgb(48, 150, 255) : Color.FromArgb(0, 110, 235)) : mavi;
                yazi = Color.White;
            }
            else
            {
                dolgu = basili ? (Koyu ? Color.FromArgb(48, 49, 56) : Color.FromArgb(214, 214, 221)) : ust ? (Koyu ? Color.FromArgb(70, 71, 79) : Color.FromArgb(224, 224, 230)) : (Koyu ? Color.FromArgb(58, 59, 66) : Color.FromArgb(234, 234, 239));
                yazi = Koyu ? Color.FromArgb(245, 245, 247) : Color.FromArgb(29, 29, 31);
            }
            g.SmoothingMode = SmoothingMode.AntiAlias;
            float r = 7f * Olcek;
            RectangleF k = new RectangleF(0.5f, 0.5f, Width - 1f, Height - 1f);
            using (GraphicsPath p = Yol(k, r))
            using (SolidBrush b = new SolidBrush(dolgu))
                g.FillPath(b, p);
            // klavyeyle gezinirken odaktaki düğmenin çevresinde ince halka
            if (Focused && ShowFocusCues)
            {
                float w = Math.Max(1.5f, 2f * Olcek);
                RectangleF ic = RectangleF.Inflate(k, -w / 2f, -w / 2f);
                using (GraphicsPath p = Yol(ic, Math.Max(1f, r - w / 2f)))
                using (Pen kalem = new Pen(Ana ? Color.FromArgb(170, 255, 255, 255) : mavi, w))
                    g.DrawPath(kalem, p);
            }
            TextRenderer.DrawText(g, Text, Font, ClientRectangle, yazi, dolgu, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix);
        }

        static GraphicsPath Yol(RectangleF r, float c)
        {
            float d = Math.Min(c * 2f, Math.Min(r.Width, r.Height));
            GraphicsPath p = new GraphicsPath();
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }
    }
}
