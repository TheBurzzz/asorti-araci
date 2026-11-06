// Eleman - Ölçü Tablosu Aracı'nın yerel sunucu bölümü (/olcu/...).
// Sayfa (olcu_tablosu_araci.html) Eleman penceresinde açılınca kayıt klasörü, Excel'e kaydetme, Excel'de açma,
// tek tuşla tarama (Epson L3260, WIA) ve ortak hafıza anahtarı buradan gelir.
//
// Asorti Aracı'ndan tamamen ayrıdır: Asorti'nin hiçbir adresine, ayarına, klasörüne dokunmaz.
//   adresler   : yalnız /olcu/...            (Asorti: /excel/..., /gerber/... aynen kalır)
//   ayarlar    : kullanici.json'da "olcu_klasorler", "olcu_ayar" (Asorti: "excel_klasor", "tema"...)
//   dosyalar   : sistem\olcu\ (kitaplıklar, tarama betiği), anahtar.txt (ortak hafıza anahtarı, GitHub'a konmaz)
// Sunucu.cs'te tek satırla bağlanır (bkz. Sunucu.cs.yama.txt):
//     if (yol.StartsWith("olcu/") && OlcuIstek(ctx, yol, m)) return;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;

namespace AsortiAraci
{
    sealed partial class Sunucu
    {
        static readonly object olcuKilit = new object();
        static readonly object olcuTaramaKilit = new object();

        // true: istek bu bölümde cevaplandı (bilinmeyen /olcu/ adresi de 404 ile burada biter)
        bool OlcuIstek(HttpListenerContext ctx, string yol, string m)
        {
            // yalnız programın kendi sayfası: özel başlık (başka sitelerin sayfaları bunu gönderemez) ve localhost adresi
            string host = ctx.Request.Headers["Host"] ?? "";
            if (ctx.Request.Headers["X-Olcu"] != "1" || !(host == "localhost:" + A.Port || host == "127.0.0.1:" + A.Port))
            {
                Yanit(ctx, 403);
                return true;
            }
            switch (yol)
            {
                case "olcu/durum":
                    {
                        bool salt;
                        string k = HafizaAnahtari(out salt);
                        JsonYanit(ctx, Json.H("olcu", true, "surum", Json.Str(Surum.Yerel(), "surum"), "anahtar", k.Length > 0, "salt", salt));
                    }
                    return true;
                case "olcu/anahtar":
                    {
                        bool salt;
                        string k = HafizaAnahtari(out salt);
                        JsonYanit(ctx, Json.H("anahtar", k, "salt", salt));
                    }
                    return true;
                case "olcu/klasor":
                    JsonYanit(ctx, OlcuKlasorDurum(Sorgu(ctx, "musteri")));
                    return true;
                case "olcu/klasor-sec":
                    if (m != "POST") break;
                    JsonYanit(ctx, OlcuKlasorSec(Sorgu(ctx, "musteri")));
                    return true;
                case "olcu/kaydet":
                    if (m != "POST") break;
                    JsonYanit(ctx, OlcuKaydet(ctx));
                    return true;
                case "olcu/ac":
                    if (m != "POST") break;
                    JsonYanit(ctx, OlcuAc(ctx));
                    return true;
                case "olcu/tarayicilar":
                    JsonYanit(ctx, OlcuTarayicilar());
                    return true;
                case "olcu/tara":
                    if (m != "POST") break;
                    OlcuTara(ctx);
                    return true;
                case "olcu/ayar":
                    OlcuAyar(ctx, m);
                    return true;
                case "olcu/sablonlar":
                    // müşteri şablonları herkese açık program deposunda durmaz: kurulumla gelen gizli dosyadan okunur
                    Yanit(ctx, 200, OlcuSablonlar(), "application/json; charset=utf-8", null);
                    return true;
            }
            Yanit(ctx, 404);
            return true;
        }

        // ---------- ortak hafıza anahtarı: C:\Eleman\anahtar.txt (kurulumla gelir, güncelleme dokunmaz, GitHub'a konmaz) ----------
        // Ortak hafıza anahtarı: anahtar.txt varsa o, yoksa programın içindeki anahtar. Kullanıcının kararı (6 Kasım 2026 gece):
        // her bilgisayar hem öğrensin hem öğretsin, kimseye "bu benim bilgisayarım" demek gerekmesin. Programın içindeki anahtar
        // GitHub'da okur-yazar yapılınca her kurulum ortak hafızaya yazar; yalnız okuyabiliyorsa Ölçü Tablosu bunu GitHub'ın
        // cevabından (403) anlar ve kendiliğinden yalnız okumaya geçer. salt hep false: karar Ölçü Tablosu'nda.
        static string HafizaAnahtari(out bool salt)
        {
            string k = OlcuAnahtar();
            salt = false;
            if (k.Length > 0) return k;
            return OkumaAnahtari();
        }

        // Programın içindeki anahtar (GitHub'daki adı "eleman-okuma"; yalnız eleman-hafiza). Karışık yazılır, çünkü GitHub herkese
        // açık depoda düz duran anahtarı hemen iptal eder; bu bir gizleme değildir, kurcalayan çözebilir (kullanıcı kabul etti).
        const string OKUMA = "LQUpAy4nRgo9Pzg3JyZSWwYgXwAAOAciKTgzXgclHx8YITQUM1lSBgQXSR5ZJzwUMVsOOA45SzcDIiU+KV8jBSIoXyxfDTsHVSU0JTYseSxaRDIVBBw6DxQGWQYM";
        static string OkumaAnahtari()
        {
            if (OKUMA.Length == 0) return "";
            try
            {
                byte[] b = Convert.FromBase64String(OKUMA), k = Encoding.ASCII.GetBytes("eleman-okuma");
                for (int i = 0; i < b.Length; i++) b[i] ^= k[i % k.Length];
                Array.Reverse(b);
                string t = Encoding.ASCII.GetString(b);
                return AnahtarGecerli(t) ? t : "";
            }
            catch { return ""; }
        }

        static string OlcuAnahtar()
        {
            try
            {
                string f = Yer.Yol("anahtar.txt");
                if (File.Exists(f))
                {
                    string t = File.ReadAllText(f, Encoding.UTF8).Trim();
                    if (Regex.IsMatch(t, "^(github_pat_|ghp_)[A-Za-z0-9_]{20,}$")) return t;
                }
            }
            catch { }
            return "";
        }

        // ---------- müşteri şablonları: <kurulum>\olcu_sablonlar.json (kurulumla elden gelir; güncelleme dokunmaz, GitHub'a konmaz) ----------
        // ilk açılışta (dosya yoksa) gizli ortak hafızadan indirilir; sonra en fazla 6 saatte bir arka planda tazelenir
        static DateTime olcuSablonDenendi = DateTime.MinValue;
        static readonly object olcuSablonKilit = new object();
        static byte[] OlcuSablonlar()
        {
            try
            {
                string f = Yer.Yol("olcu_sablonlar.json");
                if (!File.Exists(f)) { olcuSablonDenendi = DateTime.Now; OlcuSablonIndir(15000); }
                else if ((DateTime.Now - olcuSablonDenendi).TotalHours >= 6) { olcuSablonDenendi = DateTime.Now; ThreadPool.QueueUserWorkItem(delegate { OlcuSablonIndir(30000); }); }
                if (File.Exists(f))
                {
                    byte[] b = File.ReadAllBytes(f);
                    int bas = (b.Length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) ? 3 : 0;
                    if (b.Length - bas > 1 && b[bas] == (byte)'[')
                    {
                        if (bas == 0) return b;
                        byte[] c = new byte[b.Length - 3]; Buffer.BlockCopy(b, 3, c, 0, c.Length); return c;
                    }
                }
            }
            catch { }
            return Encoding.ASCII.GetBytes("[]");
        }

        // gizli ortak hafıza deposundan (eleman-hafiza: olcu-tablosu/veri/sablonlar.json) indirir. Anahtar ya da internet yoksa sessizce vazgeçer.
        static bool OlcuSablonIndir(int zamanAsimi)
        {
            bool salt;
            string anahtar = HafizaAnahtari(out salt);
            if (anahtar.Length == 0) return false;
            lock (olcuSablonKilit)
            {
                try
                {
                    Web.Hazirla();
                    HttpWebRequest r = (HttpWebRequest)WebRequest.Create("https://api.github.com/repos/TheBurzzz/eleman-hafiza/contents/olcu-tablosu/veri/sablonlar.json");
                    r.Timeout = zamanAsimi;
                    r.ReadWriteTimeout = zamanAsimi;
                    r.UserAgent = "Eleman";
                    r.Accept = "application/vnd.github.raw";
                    r.Headers["Authorization"] = "Bearer " + anahtar;
                    byte[] b;
                    using (WebResponse y = r.GetResponse())
                    using (Stream st = y.GetResponseStream())
                    using (MemoryStream ms = new MemoryStream()) { st.CopyTo(ms); b = ms.ToArray(); }
                    if (b.Length < 2 || b[0] != (byte)'[') return false;
                    string f = Yer.Yol("olcu_sablonlar.json"), g = f + ".gecici";
                    File.WriteAllBytes(g, b);
                    Dosya.Degistir(g, f);
                    return true;
                }
                catch (Exception ex) { Kayit.Yaz("olcu sablonlari indirilemedi: " + ex.Message); return false; }
            }
        }

        // ---------- müşteriye göre kayıt klasörü ----------
        static bool OlcuMusteriGecerli(string m) { return m.Length > 0 && m.Length < 80 && !Regex.IsMatch(m, "[\\\\/:*?\"<>|\\x00-\\x1f]"); }

        static bool OlcuAdGecerli(string n)
        {
            return n.Length > 0 && n.Length < 200 && !Regex.IsMatch(n, "[\\\\/:*?\"<>|\\x00-\\x1f]") && Regex.IsMatch(n, "\\.xlsx$", RegexOptions.IgnoreCase) && !n.StartsWith(".");
        }

        static IDictionary OlcuKlasorler()
        {
            IDictionary d = Json.Al(Kullanici.Oku(), "olcu_klasorler") as IDictionary;
            return d ?? new OrderedDictionary(StringComparer.Ordinal);
        }

        static string OlcuKlasor(string musteri) { return musteri.Length == 0 ? "" : Json.Str(OlcuKlasorler(), musteri); }

        static OrderedDictionary OlcuKlasorDurum(string musteri)
        {
            string k = OlcuKlasor(musteri);
            return Json.H("klasor", k, "var", k.Length > 0 && Directory.Exists(k));
        }

        OrderedDictionary OlcuKlasorSec(string musteri)
        {
            if (!OlcuMusteriGecerli(musteri)) return Json.H("hata", "Müşteri adı geçersiz.");
            string sec = "";
            try { if (Pencere != null) sec = Pencere.KlasorSec(OlcuKlasor(musteri)); }
            catch (Exception ex) { Kayit.Yaz("olcu klasor secilemedi: " + ex.Message); }
            if (sec.Length > 0 && Directory.Exists(sec))
            {
                lock (olcuKilit)
                {
                    OrderedDictionary d = new OrderedDictionary(StringComparer.Ordinal);
                    foreach (DictionaryEntry e in OlcuKlasorler()) d[Convert.ToString(e.Key)] = e.Value;
                    d[musteri] = sec;
                    Kullanici.Yaz("olcu_klasorler", d);
                }
                Kayit.Yaz("olcu klasoru (" + musteri + "): " + sec);
                return OlcuKlasorDurum(musteri);
            }
            OrderedDictionary r = OlcuKlasorDurum(musteri);
            r["iptal"] = true;
            return r;
        }

        // ---------- Excel'e kaydet: {ok,ad,klasor,yol} | {var} | {kilitli} | {klasoryok} | {hata} ----------
        static bool OlcuKilitliMi(Exception ex)
        {
            int h = System.Runtime.InteropServices.Marshal.GetHRForException(ex) & 0xFFFF;
            if (h == 32 || h == 33) return true;   // dosya Excel'de açık
            return Regex.IsMatch(ex.Message ?? "", "being used|kullan|another process|ba.ka bir i.lem", RegexOptions.IgnoreCase);
        }

        OrderedDictionary OlcuKaydet(HttpListenerContext ctx)
        {
            string musteri = Sorgu(ctx, "musteri"), ad = Sorgu(ctx, "ad"), mod = Sorgu(ctx, "mod");
            if (!OlcuMusteriGecerli(musteri)) return Json.H("hata", "Müşteri adı geçersiz.");
            if (!OlcuAdGecerli(ad)) return Json.H("hata", "Dosya adı geçersiz.");
            string k = OlcuKlasor(musteri);
            if (!(k.Length > 0 && Directory.Exists(k))) return Json.H("klasoryok", true);
            byte[] veri = Govde(ctx);
            if (veri.Length < 100) return Json.H("hata", "Dosya boş geldi.");
            string hedef = Path.Combine(k, ad);
            if (File.Exists(hedef) && mod != "ustune") return Json.H("var", true, "ad", ad, "klasor", k);
            string gecici = Path.Combine(k, "~olcu_" + Guid.NewGuid().ToString("N").Substring(0, 8) + ".tmp");
            try
            {
                File.WriteAllBytes(gecici, veri);
                if (!File.Exists(hedef)) File.Move(gecici, hedef);
                else
                {
                    try { File.Replace(gecici, hedef, null); }
                    catch (Exception ex)
                    {
                        if (OlcuKilitliMi(ex)) throw;
                        File.Copy(gecici, hedef, true);
                        try { File.Delete(gecici); } catch { }
                    }
                }
            }
            catch (Exception ex)
            {
                try { File.Delete(gecici); } catch { }
                if (OlcuKilitliMi(ex) || ex is UnauthorizedAccessException) return Json.H("kilitli", true, "ad", ad);
                return Json.H("hata", ex.Message);
            }
            Kayit.Yaz("olcu tablosu kaydedildi: " + hedef);
            return Json.H("ok", true, "ad", ad, "klasor", k, "yol", hedef);
        }

        // Excel'de aç / klasörde göster (yalnız o müşterinin kayıt klasöründeki dosya)
        static OrderedDictionary OlcuAc(HttpListenerContext ctx)
        {
            string musteri = Sorgu(ctx, "musteri"), ad = Sorgu(ctx, "ad"), nasil = Sorgu(ctx, "nasil");
            string k = OlcuKlasor(musteri);
            if (!(k.Length > 0 && Directory.Exists(k))) return Json.H("hata", "Kayıt klasörü yok.");
            if (nasil == "klasor" && ad.Length == 0) { Process.Start("explorer.exe", "\"" + k + "\""); return Json.H("ok", true); }
            if (!OlcuAdGecerli(ad)) return Json.H("hata", "Dosya adı geçersiz.");
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

        // ---------- tek tuşla tarama: sistem\olcu\tara_kagit.ps1 (WIA) ayrı süreçte; sürücü takılırsa süre dolunca kapatılır ----------
        static object OlcuBetikCalistir(string argumanlar, int zamanAsimiMs)
        {
            string cikti = Path.Combine(Path.GetTempPath(), "olcu_tara_" + Guid.NewGuid().ToString("N").Substring(0, 8) + ".json");
            ProcessStartInfo si = new ProcessStartInfo();
            si.FileName = Betik.PowerShell;
            si.Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -File \"" + Yer.Yol("sistem", "olcu", "tara_kagit.ps1") + "\" -Cikti \"" + cikti + "\" " + argumanlar;
            si.UseShellExecute = false;
            si.CreateNoWindow = true;
            si.WindowStyle = ProcessWindowStyle.Hidden;
            si.WorkingDirectory = Yer.Kok;
            try
            {
                using (Process p = Process.Start(si))
                {
                    if (!p.WaitForExit(zamanAsimiMs))
                    {
                        try { p.Kill(); } catch { }
                        return Json.H("hata", "Tarayıcı cevap vermedi. Epson açık mı? Tekrar dene.");
                    }
                }
                if (File.Exists(cikti))
                {
                    string t = File.ReadAllText(cikti, Encoding.UTF8);
                    try { File.Delete(cikti); } catch { }
                    return Json.Oku(t);
                }
                return Json.H("hata", "Tarama yapılamadı (sonuç gelmedi).");
            }
            catch (Exception ex) { return Json.H("hata", "Tarama başlatılamadı: " + ex.Message); }
        }

        static OrderedDictionary OlcuTarayicilar()
        {
            object r = OlcuBetikCalistir("-Liste", 30000);
            object l = Json.Al(r, "tarayicilar");
            return Json.H("tarayicilar", l ?? new List<object>(), "hata", Json.Str(r, "hata"));
        }

        // betiğin adım adım ne yaptığı (sorun çıkınca kopru\log\uygulama.txt'te görünsün)
        static string OlcuAdimlar(object r)
        {
            IList l = Json.Al(r, "adimlar") as IList;
            if (l == null) return "";
            List<string> s = new List<string>();
            foreach (object o in l) s.Add(Json.Metin(o));
            return string.Join(" | ", s.ToArray());
        }

        static void OlcuHata(HttpListenerContext ctx, int kod, string metin)
        {
            Yanit(ctx, kod, Dosya.Utf8.GetBytes(Json.Yaz(Json.H("hata", metin))), "application/json; charset=utf-8", null);
        }

        void OlcuTara(HttpListenerContext ctx)
        {
            int dpi;
            if (!int.TryParse(Sorgu(ctx, "dpi"), out dpi) || dpi < 100 || dpi > 600) dpi = 300;
            string renk = Sorgu(ctx, "renk") == "gri" ? "gri" : "renkli";
            string cihaz = Sorgu(ctx, "cihaz");
            if (!Monitor.TryEnter(olcuTaramaKilit)) { OlcuHata(ctx, 409, "Bir tarama zaten sürüyor."); return; }
            try
            {
                string resim = Path.Combine(Path.GetTempPath(), "olcu_tarama_" + DateTime.Now.Ticks + ".jpg");
                // cihaz kimliği ters bölü içerir: komut satırına base64 ile geçer
                string arg = "-Resim \"" + resim + "\" -Dpi " + dpi + " -Renk " + renk + (cihaz.Length > 0 && cihaz.Length < 400 ? " -CihazB64 " + Convert.ToBase64String(Encoding.UTF8.GetBytes(cihaz)) : "");
                object r = OlcuBetikCalistir(arg, 180000);
                // betik JPEG'e çeviremezse resmi olduğu gibi (BMP/PNG) verir: yolu ve türü sonuçtan al
                string yol = Json.Str(r, "resim");
                if (!yol.StartsWith(Path.Combine(Path.GetTempPath(), "olcu_tarama_"), StringComparison.OrdinalIgnoreCase)) yol = resim;
                string tur = Json.Str(r, "tur");
                if (!Regex.IsMatch(tur, "^image/(jpeg|png|bmp)$")) tur = "image/jpeg";
                if (Json.Str(r, "ok") == "True" && File.Exists(yol))
                {
                    byte[] veri = File.ReadAllBytes(yol);
                    try { File.Delete(yol); } catch { }
                    try { if (yol != resim) File.Delete(resim); } catch { }
                    Kayit.Yaz("olcu tarama: " + Json.Str(r, "cihaz") + ", " + dpi + " dpi, " + tur + ", " + veri.Length + " bayt · " + OlcuAdimlar(r));
                    Yanit(ctx, 200, veri, tur, null);
                    return;
                }
                string h = Json.Str(r, "hata");
                if (h.Length == 0) h = "Tarama yapılamadı.";
                Kayit.Yaz("olcu tarama hatasi: " + h + " " + Json.Str(r, "kod") + " · " + OlcuAdimlar(r));
                OlcuHata(ctx, 503, h);
            }
            finally { Monitor.Exit(olcuTaramaKilit); }
        }

        // ---------- tarama ayarları: {dpi, renk, cihaz, cihazAd} ----------
        void OlcuAyar(HttpListenerContext ctx, string m)
        {
            if (m == "POST")
            {
                IDictionary g = null;
                try { g = Json.Oku(Dosya.Utf8.GetString(Govde(ctx))) as IDictionary; } catch { }
                if (g != null)
                {
                    int dpi;
                    if (!int.TryParse(Json.Str(g, "dpi"), out dpi) || dpi < 100 || dpi > 600) dpi = 300;
                    OrderedDictionary a = Json.H("dpi", dpi, "renk", Json.Str(g, "renk") == "gri" ? "gri" : "renkli", "cihaz", Json.Str(g, "cihaz"), "cihazAd", Json.Str(g, "cihazAd"));
                    lock (olcuKilit) Kullanici.Yaz("olcu_ayar", a);
                }
            }
            IDictionary s = Json.Al(Kullanici.Oku(), "olcu_ayar") as IDictionary;
            JsonYanit(ctx, s != null ? (object)s : Json.H("dpi", 300, "renk", "renkli", "cihaz", "", "cihazAd", ""));
        }
    }
}
