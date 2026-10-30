// Asorti Aracı - uygulamanın arka plandaki programı (eskiden sistem\sunucu.ps1).
// Pencerenin içindeki sayfayı ve sayfanın istediği her şeyi (Excel kaydetme, Gerber, güncelleme...) yerel adresten sunar.
using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;

namespace AsortiAraci
{
    // sunucunun pencereden istedikleri (pencere yoksa / denemede boş olabilir)
    interface IPencere
    {
        bool Acik { get; }
        void Hazir();                       // görünen sayfa ekrana çizildi
        void OneGetir();
        void Tema(string tema);             // "dark" | "light"
        string KlasorSec(string baslangic); // iptal: ""
        void Guncellendi(bool yenidenBaslat);
    }

    sealed partial class Sunucu
    {
        public volatile Ayarlar A;
        public volatile string Id;
        public IPencere Pencere;
        public readonly Kopru Kopru = new Kopru();
        HttpListener L;
        volatile bool calisiyor;
        readonly object kilit = new object();
        public volatile bool HazirGeldi;
        bool ilkNabiz;
        Timer denetci;

        static readonly Dictionary<string, string> Tipler = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { ".html", "text/html; charset=utf-8" }, { ".js", "text/javascript; charset=utf-8" }, { ".json", "application/json; charset=utf-8" },
            { ".txt", "text/plain; charset=windows-1254" }, { ".png", "image/png" }, { ".ico", "image/x-icon" }, { ".css", "text/css; charset=utf-8" },
            { ".woff2", "font/woff2" }, { ".svg", "image/svg+xml" }
        };

        public Sunucu()
        {
            A = Ayarlar.Oku(Yer.Kok);
            Id = YeniId();
            Kopru.Etkin = A.Gerber;
        }

        static string YeniId() { return Process.GetCurrentProcess().Id + "-" + DateTime.Now.Ticks; }

        // dinlemeye başlar; adres kullanılıyorsa false
        public bool Baslat()
        {
            try
            {
                L = new HttpListener();
                L.Prefixes.Add("http://localhost:" + A.Port + "/");
                L.Start();
            }
            catch (Exception ex)
            {
                Kayit.Yaz("sunucu acilamadi (" + A.Port + "): " + ex.Message);
                try { if (L != null) L.Close(); } catch { }
                L = null;
                return false;
            }
            calisiyor = true;
            Thread t = new Thread(Dinle);
            t.IsBackground = true;
            t.Name = "sunucu";
            t.Start();
            Kayit.Yaz("sunucu acildi: http://localhost:" + A.Port + "/");
            return true;
        }

        // ağır olmayan ama açılışı geciktirmesin diye pencere açıldıktan sonra yapılan işler
        public void ArkaPlanBaslat()
        {
            ThreadPool.QueueUserWorkItem(delegate
            {
                try
                {
                    Kopru.BaskaKopruleriKapat(true);
                    if (A.Gerber) Kopru.Baslat(); else Kayit.Yaz("Gerber kapali (sadece asorti): kopru baslatilmadi");
                    IlkTarama();
                }
                catch (Exception ex) { Kayit.Yaz("arka plan isleri: " + ex.Message); }
            });
            denetci = new Timer(delegate { try { Kopru.Denetle(); } catch { } }, null, 10000, 5000);
        }

        public void Durdur()
        {
            calisiyor = false;
            try { if (denetci != null) denetci.Dispose(); } catch { }
            try { if (L != null) { L.Stop(); L.Close(); } } catch { }
        }

        void Dinle()
        {
            while (calisiyor)
            {
                HttpListenerContext ctx;
                try { ctx = L.GetContext(); }
                catch { if (!calisiyor) return; Thread.Sleep(50); continue; }
                ThreadPool.QueueUserWorkItem(delegate(object o) { Isle((HttpListenerContext)o); }, ctx);
            }
        }

        // ---------- yanıt ----------
        static void Yanit(HttpListenerContext ctx, int kod, byte[] veri, string tip, string onbellek)
        {
            HttpListenerResponse r = ctx.Response;
            try
            {
                r.StatusCode = kod;
                r.Headers["Cache-Control"] = onbellek ?? "no-store";
                if (tip != null) r.ContentType = tip;
                if (veri != null)
                {
                    r.ContentLength64 = veri.Length;
                    r.OutputStream.Write(veri, 0, veri.Length);
                }
            }
            finally { try { r.OutputStream.Close(); } catch { } }
        }

        static void Yanit(HttpListenerContext ctx, int kod) { Yanit(ctx, kod, null, null, null); }

        static void JsonYanit(HttpListenerContext ctx, object o)
        {
            Yanit(ctx, 200, Dosya.Utf8.GetBytes(Json.Yaz(o)), "application/json; charset=utf-8", null);
        }

        static byte[] Govde(HttpListenerContext ctx)
        {
            using (MemoryStream ms = new MemoryStream())
            {
                ctx.Request.InputStream.CopyTo(ms);
                return ms.ToArray();
            }
        }

        // adres satırındaki ?ad=... değeri (Türkçe harfler UTF-8)
        static string Sorgu(HttpListenerContext ctx, string ad)
        {
            string raw = ctx.Request.RawUrl ?? "";
            int i = raw.IndexOf('?');
            if (i < 0) return "";
            foreach (string p in raw.Substring(i + 1).Split('&'))
            {
                int j = p.IndexOf('=');
                if (j <= 0) continue;
                try
                {
                    if (Uri.UnescapeDataString(p.Substring(0, j)) == ad) return Uri.UnescapeDataString(p.Substring(j + 1).Replace('+', ' '));
                }
                catch { }
            }
            return "";
        }

        // ---------- istekler ----------
        void Isle(HttpListenerContext ctx)
        {
            string yol = "", m = "";
            try
            {
                yol = Uri.UnescapeDataString(ctx.Request.Url.AbsolutePath).TrimStart('/');
                m = ctx.Request.HttpMethod;
                switch (yol)
                {
                    case "nabiz": Nabiz(ctx); return;
                    case "kapaniyor": HazirGeldi = false; Yanit(ctx, 200); return;
                    case "hazir":
                        if (m != "POST") break;
                        HazirGeldi = true;
                        Yanit(ctx, 200);
                        if (Pencere != null) Pencere.Hazir();
                        return;
                    case "pencere":
                        {
                            bool ac = Pencere != null && Pencere.Acik;
                            JsonYanit(ctx, Json.H("acik", ac, "hazir", ac && HazirGeldi));
                            return;
                        }
                    case "one-getir":
                        if (m != "POST") break;
                        Yanit(ctx, 200);
                        if (Pencere != null) Pencere.OneGetir();
                        return;
                    case "ping": Yanit(ctx, 200, Dosya.Utf8.GetBytes("ok"), "text/plain", null); return;
                    case "surum":
                        {
                            IDictionary y = Surum.Yerel();
                            Ayarlar a = A;
                            JsonYanit(ctx, Json.H("surum", Json.Str(y, "surum"), "tarih", Json.Str(y, "tarih"), "gerber", a.Gerber, "otopastal", a.Otopastal, "guncelleme", a.Guncelleme.Length > 0));
                            return;
                        }
                    case "tema":
                        if (m != "POST") break;
                        {
                            string tv = Sorgu(ctx, "v");
                            if (tv == "dark" || tv == "light")
                            {
                                if (Kullanici.Al("tema") != tv) { try { Kullanici.Yaz("tema", tv); } catch { } }
                                if (Pencere != null) Pencere.Tema(tv);
                            }
                            Yanit(ctx, 200);
                            return;
                        }
                    case "konum":
                        {
                            OrderedDictionary k = IpKonum();
                            JsonYanit(ctx, k != null ? (object)k : Json.H("hata", "konum bulunamadi"));
                            return;
                        }
                    case "excel/klasor":
                        if (m != "GET") break;
                        JsonYanit(ctx, ExcelDurum());
                        return;
                    case "excel/klasor-sec":
                        if (m != "POST") break;
                        ExcelKlasorSec(ctx);
                        return;
                    case "excel/kaydet":
                        if (m != "POST") break;
                        JsonYanit(ctx, ExcelKaydet(ctx));
                        return;
                    case "excel/ac":
                        if (m != "POST") break;
                        JsonYanit(ctx, ExcelAc(ctx));
                        return;
                    case "pastal": Pastal(ctx); return;
                    case "gerber/tara": GerberTara(ctx, m); return;
                    case "gerber/uygula":
                        if (m != "POST") break;
                        JsonYanit(ctx, GerberUygula());
                        return;
                    case "guncelleme": JsonYanit(ctx, GuncellemeVarMi(Sorgu(ctx, "taze") == "1")); return;
                    case "guncelle":
                        if (m != "POST") break;
                        GuncelleIstek(ctx);
                        return;
                    case "yerel-kayit": YerelKayit(ctx, m); return;
                }
                DosyaIstek(ctx, yol, m);
            }
            catch (Exception ex)
            {
                Kayit.Yaz("istek hatasi (" + m + " /" + yol + "): " + ex.Message);
                try { Yanit(ctx, 500); } catch { }
            }
        }

        void Nabiz(HttpListenerContext ctx)
        {
            if (!ilkNabiz)
            {
                ilkNabiz = true;
                try { File.Delete(Yer.Yol("kopru", "log", "acilis.txt")); } catch { }   // eski açılışın "açılıyor" işareti
            }
            Ayarlar a = A;
            JsonYanit(ctx, Json.H("kopru", Kopru.Calisiyor, "gerber", a.Gerber, "otopastal", a.Otopastal, "id", Id));
        }

        // ---------- dosyalar ve köprü klasörleri ----------
        void DosyaIstek(HttpListenerContext ctx, string yol, string m)
        {
            if (yol.Length == 0) yol = "uygulama.html";
            if (yol.Contains("..") || yol.Contains(":") || yol.Contains("\\")) { Yanit(ctx, 400); return; }
            string dosya = Path.Combine(Yer.Kok, yol.Replace('/', Path.DirectorySeparatorChar));
            if (m == "GET" || m == "HEAD")
            {
                string ext = Path.GetExtension(dosya);
                // sayfanın okuduğu yerler: kendi .html dosyaları, sistem\ ve köprü klasörü (ayarlar, kullanıcı bilgileri, sayfa yedeği verilmez)
                int bolu = yol.IndexOf('/');
                string ilk = bolu < 0 ? "" : yol.Substring(0, bolu);
                bool izinli = bolu < 0 ? ext.Equals(".html", StringComparison.OrdinalIgnoreCase) : (ilk == "sistem" || ilk == "kopru");
                if (!izinli || !File.Exists(dosya) || !Tipler.ContainsKey(ext)) { Yanit(ctx, 404); return; }
                byte[] veri = null;
                for (int i = 0; i < 10 && veri == null; i++)
                {
                    try { veri = Dosya.PaylasimliOku(dosya); }
                    catch { Thread.Sleep(100); }
                }
                if (veri == null) { Yanit(ctx, 503); return; }
                // yazı tipi değişmez: her açılışta yeniden yüklenmesin
                Yanit(ctx, 200, m == "HEAD" ? null : veri, Tipler[ext], ext.Equals(".woff2", StringComparison.OrdinalIgnoreCase) ? "max-age=31536000, immutable" : null);
                return;
            }
            if ((m == "PUT" || m == "POST") && Regex.IsMatch(yol, "^kopru/(gelen|iptal)/[A-Za-z0-9._\\-]+$"))
            {
                byte[] veri = Govde(ctx);
                Directory.CreateDirectory(Path.GetDirectoryName(dosya));
                string gecici = dosya + ".yaziliyor";
                File.WriteAllBytes(gecici, veri);
                if (File.Exists(dosya)) File.Delete(dosya);
                File.Move(gecici, dosya);
                Yanit(ctx, 200);
                return;
            }
            if (m == "DELETE" && Regex.IsMatch(yol, "^kopru/gelen/[A-Za-z0-9._\\-]+$"))
            {
                if (File.Exists(dosya)) { File.Delete(dosya); Yanit(ctx, 200); } else Yanit(ctx, 404);
                return;
            }
            Yanit(ctx, 405);
        }

        // ---------- Excel ----------
        static string ExcelKlasor() { return Kullanici.Al("excel_klasor"); }

        static OrderedDictionary ExcelDurum()
        {
            string k = ExcelKlasor();
            return Json.H("klasor", k, "var", k.Length > 0 && Directory.Exists(k));
        }

        void ExcelKlasorSec(HttpListenerContext ctx)
        {
            string sec = "";
            try { if (Pencere != null) sec = Pencere.KlasorSec(ExcelKlasor()); }
            catch (Exception ex) { Kayit.Yaz("klasor secilemedi: " + ex.Message); }
            if (sec.Length > 0 && Directory.Exists(sec))
            {
                Kullanici.Yaz("excel_klasor", sec);
                Kayit.Yaz("excel klasoru: " + sec);
                JsonYanit(ctx, ExcelDurum());
            }
            else
            {
                OrderedDictionary d = ExcelDurum();
                d["iptal"] = true;
                JsonYanit(ctx, d);
            }
        }

        static bool ExcelAdGecerli(string n)
        {
            return n.Length > 0 && n.Length < 200 && !Regex.IsMatch(n, "[\\\\/:*?\"<>|]") && Regex.IsMatch(n, "\\.xls[xm]$", RegexOptions.IgnoreCase) && !n.StartsWith(".");
        }

        static bool KilitliMi(Exception ex)
        {
            int h = System.Runtime.InteropServices.Marshal.GetHRForException(ex) & 0xFFFF;
            if (h == 32 || h == 33) return true;   // dosya başka programda açık / kilitli
            return Regex.IsMatch(ex.Message ?? "", "being used|kullan|another process|ba.ka bir i.lem", RegexOptions.IgnoreCase);
        }

        OrderedDictionary ExcelKaydet(HttpListenerContext ctx)
        {
            string ad = Sorgu(ctx, "ad"), mod = Sorgu(ctx, "mod"), k = ExcelKlasor();
            if (!ExcelAdGecerli(ad)) return Json.H("hata", "Dosya adı geçersiz.");
            if (!(k.Length > 0 && Directory.Exists(k))) return Json.H("klasoryok", true);
            byte[] veri = Govde(ctx);
            if (veri.Length < 100) return Json.H("hata", "Dosya boş geldi.");
            string hedef = Path.Combine(k, ad);
            if (File.Exists(hedef))
            {
                if (mod == "yeni")
                {
                    string kok = Path.GetFileNameWithoutExtension(ad), uz = Path.GetExtension(ad);
                    int i = 2;
                    while (File.Exists(Path.Combine(k, kok + " (" + i + ")" + uz))) i++;
                    ad = kok + " (" + i + ")" + uz;
                    hedef = Path.Combine(k, ad);
                }
                else if (mod != "ustune") return Json.H("var", true, "ad", ad, "klasor", k);
            }
            string gecici = Path.Combine(k, "~asorti_" + Guid.NewGuid().ToString("N").Substring(0, 8) + ".tmp");
            try
            {
                File.WriteAllBytes(gecici, veri);
                if (!File.Exists(hedef)) File.Move(gecici, hedef);
                else
                {
                    try { File.Replace(gecici, hedef, null); }
                    catch (Exception ex)
                    {
                        if (KilitliMi(ex)) throw;
                        File.Copy(gecici, hedef, true);
                        try { File.Delete(gecici); } catch { }
                    }
                }
            }
            catch (Exception ex)
            {
                try { File.Delete(gecici); } catch { }
                if (KilitliMi(ex) || ex is UnauthorizedAccessException || Regex.IsMatch(ex.Message ?? "", "access|eri.im", RegexOptions.IgnoreCase)) return Json.H("kilitli", true, "ad", ad);
                return Json.H("hata", ex.Message);
            }
            Kayit.Yaz("excel kaydedildi: " + hedef);
            return Json.H("ok", true, "ad", ad, "klasor", k, "yol", hedef);
        }

        static OrderedDictionary ExcelAc(HttpListenerContext ctx)
        {
            string ad = Sorgu(ctx, "ad"), nasil = Sorgu(ctx, "nasil"), k = ExcelKlasor();
            if (!(k.Length > 0 && Directory.Exists(k))) return Json.H("hata", "Kayıt klasörü yok.");
            if (nasil == "klasor" && ad.Length == 0) { Process.Start("explorer.exe", "\"" + k + "\""); return Json.H("ok", true); }
            if (!ExcelAdGecerli(ad)) return Json.H("hata", "Dosya adı geçersiz.");
            string yol = Path.Combine(k, ad);
            if (!File.Exists(yol)) return Json.H("hata", "Dosya bulunamadı.");
            if (nasil == "klasor") Process.Start("explorer.exe", "/select,\"" + yol + "\"");
            else
            {
                ProcessStartInfo si = new ProcessStartInfo(yol);
                si.UseShellExecute = true;
                Process.Start(si);
            }
            return Json.H("ok", true);
        }

        // ---------- Gerber pastalı: boy, en, verim (depolama alanındaki mark.ctl -> mark???.mar) ----------
        void Pastal(HttpListenerContext ctx)
        {
            string al = Sorgu(ctx, "alan"), pa = Sorgu(ctx, "ad");
            if (!Regex.IsMatch(al, "^[^\\\\/:*?\"<>|]+$") || al.Contains("..") || !Regex.IsMatch(pa, "^[^\\\\/:*?\"<>|]+$")) { JsonYanit(ctx, Json.H("var", false, "mesaj", "gecersiz ad")); return; }
            try { JsonYanit(ctx, PastalBilgi(al, pa)); }
            catch (Exception ex) { JsonYanit(ctx, Json.H("var", false, "mesaj", ex.Message)); }
        }

        OrderedDictionary PastalBilgi(string alan, string ad)
        {
            string dd = Path.Combine(Path.Combine(Path.Combine(A.Depo, "storage"), alan), "data");
            string ctl = Path.Combine(dd, "mark.ctl");
            if (!File.Exists(ctl)) return Json.H("var", false, "mesaj", alan + " klasoru bulunamadi");
            byte[] c = Dosya.PaylasimliOku(ctl);
            Encoding lat = Encoding.GetEncoding(28591);
            ad = ad.ToUpperInvariant();
            string ek = null;
            int slot = 0;
            for (int i = 0; i + 64 <= c.Length; i += 64)
            {
                if (c[i + 25] != 0) continue;   // silinmiş kayıt
                string n = lat.GetString(c, i, 20).Split('\0')[0].Trim();
                if (n.ToUpperInvariant() == ad) { ek = lat.GetString(c, i + 20, 3); slot = c[i + 23]; }
            }
            if (ek == null) return Json.H("var", false, "mesaj", ad + " pastali " + alan + " klasorunde yok");
            byte[] mm = Dosya.PaylasimliOku(Path.Combine(dd, "mark" + ek + ".mar"));
            long o = BitConverter.ToUInt32(mm, 16 + 64 * slot), u = BitConverter.ToUInt32(mm, 20 + 64 * slot);
            if (o + 316 > mm.Length || u < 316) return Json.H("var", false, "mesaj", "pastal kaydi okunamadi");
            double en = BitConverter.ToDouble(mm, (int)o + 258) * 2.54, boy = BitConverter.ToDouble(mm, (int)o + 274) * 2.54, ver = BitConverter.ToDouble(mm, (int)o + 308);
            if (double.IsNaN(boy) || boy < 0 || boy > 100000 || double.IsNaN(ver) || ver < 0 || ver > 100) return Json.H("var", false, "mesaj", "pastal kaydi tanınmadı");
            return Json.H("var", true, "ad", ad, "en_cm", Math.Round(en, 2), "boy_cm", Math.Round(boy, 2), "verim", Math.Round(ver, 2));
        }

        // ---------- Gerber / OTOPASTAL'ı otomatik bulma (sistem\tara.ps1 ayrı süreçte arar) ----------
        Process taramaP, taramaIlkP;
        DateTime taramaBas;
        string TaramaDosya { get { return Yer.Yol("kopru", "log", "tarama.json"); } }
        string TaramaIlkDosya { get { return Yer.Yol("kopru", "log", "tarama_ilk.json"); } }

        bool TaramaBaslat(string cikti, bool taze)
        {
            lock (kilit)
            {
                Process p = taze ? taramaIlkP : taramaP;
                try { if (p != null && !p.HasExited) return false; } catch { }
                if (!taze) { try { File.Delete(cikti); } catch { } }   // eski sonuç yeni sanılmasın
                p = Betik.Baslat(Yer.Yol("sistem", "tara.ps1"), "-Cikti \"" + cikti + "\"" + (taze ? " -Taze" : ""));
                if (taze) taramaIlkP = p; else { taramaP = p; taramaBas = DateTime.Now; }
                return true;
            }
        }

        static object TaramaOku(string f)
        {
            try { if (File.Exists(f)) return Json.Oku(File.ReadAllText(f, Encoding.UTF8)); } catch { }
            return null;
        }

        // bilgi taraması: bu sürümün tarama kodu ilk kez çalışıyorsa bir kere (hiçbir ayarı değiştirmez)
        void IlkTarama()
        {
            object eski = TaramaOku(TaramaIlkDosya);
            string s = Json.Str(eski, "surum");
            if (eski == null || s.Length == 0 || Surum.No(s) < new Version(1, 1, 17))
            {
                try { if (TaramaBaslat(TaramaIlkDosya, true)) Kayit.Yaz("bilgisayar taramasi baslatildi (sadece bilgi icin, ayarlara dokunmaz)"); } catch { }
            }
        }

        // taramanın önerisi şu anki ayarlarla birleşir: çalışan bir ayar boş ya da eksik bir bulguyla asla değişmez
        OrderedDictionary TaramaOneri(object r)
        {
            object o = Json.Al(r, "oneri");
            if (r == null || o == null) return null;
            Ayarlar a = A;
            OrderedDictionary s = new OrderedDictionary(StringComparer.Ordinal);
            string amSimdi = a.AccuMark;
            bool amOk = amSimdi.Length > 0 && File.Exists(Path.Combine(amSimdi, "csvimprt.exe"));
            s["accumark"] = Json.Str(o, "accumark").Length > 0 ? Json.Str(o, "accumark") : (amOk ? amSimdi : "");
            s["gerber"] = ((string)s["accumark"]).Length > 0;
            s["userroot"] = Json.Str(o, "userroot").Length > 0 ? Json.Str(o, "userroot") : a.Userroot;
            object ur = Json.Al(r, "userroot");
            double alan = 0;
            double.TryParse(Json.Str(ur, "alan"), NumberStyles.Float, CultureInfo.InvariantCulture, out alan);
            s["depo"] = (Json.Str(o, "depo").Length > 0 && ur != null && alan > 0) ? Json.Str(o, "depo") : a.Depo;
            string kuSimdi = a.Kuyruk;
            bool kuOk = false;
            try { kuOk = kuSimdi.Length > 0 && (File.Exists(kuSimdi) || Directory.Exists(kuSimdi)); } catch { }
            if (Json.Str(o, "kuyruk").Length > 0) { s["kuyruk"] = Json.Str(o, "kuyruk"); s["otopastal"] = Json.Str(o, "otopastal"); s["surucu"] = Json.Str(o, "surucu"); s["surucu2"] = Json.Str(o, "surucu2"); }
            else if (kuOk) { s["kuyruk"] = kuSimdi; s["otopastal"] = a.Otopastal; s["surucu"] = a.Surucu; s["surucu2"] = a.Surucu2; }
            else { s["kuyruk"] = ""; s["otopastal"] = "yok"; s["surucu"] = a.Surucu; s["surucu2"] = a.Surucu2; }
            return s;
        }

        void GerberTara(HttpListenerContext ctx, string m)
        {
            if (m == "POST")
            {
                bool b = false;
                try { b = TaramaBaslat(TaramaDosya, false); } catch (Exception ex) { Kayit.Yaz("tarama baslatilamadi: " + ex.Message); }
                JsonYanit(ctx, Json.H("basladi", b));
                return;
            }
            string kb = Yer.Yol("kurulum_paketi", "Kurulum.bat");
            bool calis = false;
            lock (kilit) { try { calis = taramaP != null && !taramaP.HasExited; } catch { } }
            object r0 = calis ? null : TaramaOku(TaramaDosya);
            JsonYanit(ctx, Json.H("calisiyor", calis, "sure", calis ? (int)(DateTime.Now - taramaBas).TotalSeconds : 0, "rapor", r0, "oneri", TaramaOneri(r0), "ayar", A.GerberAyar(), "kurulum", File.Exists(kb) ? kb : ""));
        }

        static bool SurenIs()
        {
            foreach (string k in new string[] { Yer.Yol("kopru", "gelen"), Yer.Yol("kopru", "isleniyor") })
            {
                try { if (Directory.Exists(k) && Directory.GetFiles(k, "*.txt").Length > 0) return true; } catch { }
            }
            return false;
        }

        OrderedDictionary GerberUygula()
        {
            lock (kilit)
            {
                OrderedDictionary deg = TaramaOneri(TaramaOku(TaramaDosya));
                if (deg == null) return Json.H("hata", "Önce \"Otomatik bul\" ile ara.");
                if (SurenIs()) return Json.H("hata", "Gerber'de süren bir iş var. Pastallar bitince dene.");
                try { Ayarlar.Yaz(Yer.Kok, deg); }
                catch (Exception ex) { return Json.H("hata", "Ayarlar yazılamadı: " + ex.Message); }
                A = Ayarlar.Oku(Yer.Kok);
                try { File.Delete(Yer.Yol("kopru", "surucu.txt")); } catch { }
                Kopru.Durdur();
                Kopru.Etkin = A.Gerber;
                if (A.Gerber) Kopru.Baslat();
                StringBuilder sb = new StringBuilder();
                foreach (DictionaryEntry e in deg) sb.Append(' ').Append(e.Key).Append('=').Append(Json.Metin(e.Value));
                Kayit.Yaz("gerber ayarlari otomatik bulunanlarla degisti:" + sb);
                return Json.H("ok", true, "ayar", A.GerberAyar());
            }
        }

        // ---------- internet bağlantısının konumu (gün doğumu / batımı için) ----------
        OrderedDictionary konum;
        OrderedDictionary IpKonum()
        {
            if (konum != null) return konum;
            Web.Hazirla();
            foreach (string u in new string[] { "https://ipwho.is/", "https://ipapi.co/json/", "https://freeipapi.com/api/json" })
            {
                try
                {
                    object j = Json.Oku(Web.Metin(u, 6000));
                    string lat = Json.Str(j, "latitude"), lon = Json.Str(j, "longitude");
                    double la, lo;
                    if (double.TryParse(lat, NumberStyles.Float, CultureInfo.InvariantCulture, out la) && double.TryParse(lon, NumberStyles.Float, CultureInfo.InvariantCulture, out lo))
                    {
                        string sehir = Json.Str(j, "city");
                        if (sehir.Length == 0) sehir = Json.Str(j, "cityName");
                        konum = Json.H("lat", la, "lon", lo, "sehir", sehir, "kaynak", u);
                        return konum;
                    }
                }
                catch { }
            }
            return null;
        }

        // ---------- çalışma sayfalarının yedeği (pencerenin yerel kaydı: sayfalar, Gerber işleri, görünüm) ----------
        // Edge'deki eski pencereden yeni pencereye geçerken ve tarayıcı kaydı bozulursa geri gelsin diye diskte de tutulur.
        static readonly object yedekKilit = new object();
        void YerelKayit(HttpListenerContext ctx, string m)
        {
            string f = Yer.Yol("yerel_kayit.json");
            if (m == "GET")
            {
                byte[] v = null;
                lock (yedekKilit) { try { if (File.Exists(f)) v = File.ReadAllBytes(f); } catch { } }
                Yanit(ctx, 200, v ?? Dosya.Utf8.GetBytes("{}"), "application/json; charset=utf-8", null);
                return;
            }
            if (m != "POST") { Yanit(ctx, 405); return; }
            byte[] veri = Govde(ctx);
            string metin = Dosya.Utf8.GetString(veri);
            IDictionary d = null;
            try { d = Json.Oku(metin) as IDictionary; } catch { }
            if (d == null || d.Count == 0) { JsonYanit(ctx, Json.H("hata", "gecersiz")); return; }
            lock (yedekKilit)
            {
                try
                {
                    if (File.Exists(f))
                    {
                        FileInfo fi = new FileInfo(f);
                        if ((DateTime.Now - fi.LastWriteTime).TotalMinutes > 10) File.Copy(f, Yer.Yol("yerel_kayit.onceki.json"), true);
                    }
                    Dosya.GuvenliYaz(f, metin, Dosya.Utf8);
                }
                catch (Exception ex) { Kayit.Yaz("yerel kayit yazilamadi: " + ex.Message); }
            }
            JsonYanit(ctx, Json.H("ok", true));
        }
    }

    // internetten okuma (GitHub sürümü, konum)
    static class Web
    {
        static bool hazir;
        public static void Hazirla()
        {
            if (hazir) return;
            hazir = true;
            try { ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12; } catch { }
        }

        public static string Metin(string url, int zamanAsimi)
        {
            HttpWebRequest r = (HttpWebRequest)WebRequest.Create(url);
            r.Timeout = zamanAsimi;
            r.ReadWriteTimeout = zamanAsimi;
            r.UserAgent = "AsortiAraci";
            using (WebResponse y = r.GetResponse())
            using (Stream s = y.GetResponseStream())
            using (StreamReader sr = new StreamReader(s, Encoding.UTF8)) return sr.ReadToEnd();
        }

        public static void Indir(string url, string hedef, int zamanAsimi)
        {
            HttpWebRequest r = (HttpWebRequest)WebRequest.Create(url);
            r.Timeout = zamanAsimi;
            r.ReadWriteTimeout = zamanAsimi;
            r.UserAgent = "AsortiAraci";
            using (WebResponse y = r.GetResponse())
            using (Stream s = y.GetResponseStream())
            using (FileStream fs = File.Create(hedef)) s.CopyTo(fs);
        }
    }
}
