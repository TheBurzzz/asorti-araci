// Asorti Aracı - ortak parçalar: klasörler, kayıt (log), ayarlar.json, kullanici.json, sürüm.
// ayarlar.json'ı Gerber köprüsü (kopru.ps1) de okur; buradaki kurallar sistem\ortak.ps1'dekiyle birebir aynıdır.
using System;
using System.Collections;
using System.Collections.Specialized;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace AsortiAraci
{
    static class Yer
    {
        public static string Kok = "";       // kurulum klasörü (C:\AsortiAraci)
        public static string Sistem = "";    // Kok\sistem
        public static string Log = "";       // Kok\kopru\log

        public static void Ayarla(string kok)
        {
            Kok = kok;
            Sistem = Path.Combine(kok, "sistem");
            Log = Path.Combine(Path.Combine(kok, "kopru"), "log");
            try { Directory.CreateDirectory(Log); } catch { }
            Kayit.Dosya = Path.Combine(Log, "uygulama.txt");
        }

        public static string Yol(params string[] parcalar)
        {
            string y = Kok;
            foreach (string p in parcalar) y = Path.Combine(y, p);
            return y;
        }

        public static bool Windows { get { return Environment.OSVersion.Platform == PlatformID.Win32NT; } }
    }

    static class Kayit
    {
        static readonly object kilit = new object();
        public static string Dosya = "";

        public static void Yaz(string s)
        {
            try
            {
                lock (kilit)
                {
                    if (Dosya.Length == 0) return;
                    FileInfo fi = new FileInfo(Dosya);
                    if (fi.Exists && fi.Length > 2 * 1024 * 1024)
                    {
                        string eski = Dosya + ".eski";
                        if (File.Exists(eski)) File.Delete(eski);
                        File.Move(Dosya, eski);
                    }
                    File.AppendAllText(Dosya, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture) + " " + s + "\r\n", new UTF8Encoding(false));
                }
            }
            catch { }
        }
    }

    static class Dosya
    {
        public static readonly Encoding Utf8 = new UTF8Encoding(false);

        // başka program yazarken de okunabilsin (Gerber, OTOPASTAL, Excel)
        public static byte[] PaylasimliOku(string yol)
        {
            using (FileStream fs = new FileStream(yol, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
            using (MemoryStream ms = new MemoryStream())
            {
                fs.CopyTo(ms);
                return ms.ToArray();
            }
        }

        public static string MetinOku(string yol)
        {
            try { return File.Exists(yol) ? File.ReadAllText(yol, Encoding.UTF8) : ""; } catch { return ""; }
        }

        // önce yanına yazılır, sonra yerine konur: yarım yazılmış dosya kalmaz
        public static void GuvenliYaz(string yol, string metin, Encoding kodlama)
        {
            string tmp = yol + ".yeni";
            File.WriteAllText(tmp, metin, kodlama);
            Degistir(tmp, yol);
        }

        public static void Degistir(string kaynak, string hedef)
        {
            if (!File.Exists(hedef)) { File.Move(kaynak, hedef); return; }
            try { File.Replace(kaynak, hedef, null); }
            catch { File.Copy(kaynak, hedef, true); try { File.Delete(kaynak); } catch { } }
        }
    }

    sealed class Ayarlar
    {
        public int Port = 8642;
        public string AccuMark = @"C:\Program Files\Gerber Technology\AccuMark V12\AccuMark";
        public string Userroot = @"C:\userroot";
        public string Depo = "";
        public string Kuyruk = "";
        public string Otopastal = "";
        public string Surucu = "k:";
        public string Surucu2 = "z:";
        public string Tarayici = "";
        public bool Gerber = true;
        public string Guncelleme = "TheBurzzz/asorti-araci";
        public string Dal = "main";

        public static Ayarlar Oku(string kok)
        {
            Ayarlar a = new Ayarlar();
            try
            {
                string f = Path.Combine(kok, "ayarlar.json");
                if (File.Exists(f))
                {
                    IDictionary d = Json.Oku(File.ReadAllText(f, Encoding.UTF8)) as IDictionary;
                    if (d != null)
                    {
                        foreach (DictionaryEntry e in d)
                        {
                            if (e.Value == null) continue;
                            string v = Json.Metin(e.Value);
                            if (v.Length == 0) continue;
                            switch ((string)e.Key)
                            {
                                case "port": { double p; if (double.TryParse(v, NumberStyles.Float, CultureInfo.InvariantCulture, out p) && p > 0 && p < 65536) a.Port = (int)p; break; }
                                case "accumark": a.AccuMark = v; break;
                                case "userroot": a.Userroot = v; break;
                                case "depo": a.Depo = v; break;
                                case "kuyruk": a.Kuyruk = v; break;
                                case "otopastal": a.Otopastal = v; break;
                                case "surucu": a.Surucu = v; break;
                                case "surucu2": a.Surucu2 = v; break;
                                case "tarayici": a.Tarayici = v; break;
                                case "gerber": a.Gerber = !Regex.IsMatch(v, "^(false|0|hayir|no)$", RegexOptions.IgnoreCase); break;
                                case "guncelleme": a.Guncelleme = v; break;
                                case "dal": a.Dal = v; break;
                            }
                        }
                    }
                }
            }
            catch (Exception ex) { Kayit.Yaz("ayarlar okunamadi: " + ex.Message); }
            a.Surucu = (a.Surucu.TrimEnd(':', '\\') + ":").ToLowerInvariant();
            if (a.Depo.Length == 0) a.Depo = a.Userroot;
            a.Otopastal = a.Otopastal.ToLowerInvariant();
            if (a.Otopastal != "ayri" && a.Otopastal != "ayni" && a.Otopastal != "yok") a.Otopastal = a.Kuyruk.Length > 0 ? "ayri" : "yok";
            if (a.Kuyruk.Length == 0) a.Otopastal = "yok";
            if (!Regex.IsMatch(a.Dal, "^[A-Za-z0-9._/-]{1,80}$")) a.Dal = "main";
            return a;
        }

        // verilen anahtarları değiştirir, diğerlerine dokunmaz (ortak.ps1'deki AyarYaz gibi: UTF-8, BOM'lu)
        public static void Yaz(string kok, IDictionary degisen)
        {
            string f = Path.Combine(kok, "ayarlar.json");
            OrderedDictionary h = null;
            try { if (File.Exists(f)) h = Json.Oku(File.ReadAllText(f, Encoding.UTF8)) as OrderedDictionary; } catch { }
            if (h == null) h = new OrderedDictionary(StringComparer.Ordinal);
            foreach (DictionaryEntry e in degisen) h[(string)e.Key] = e.Value;
            Dosya.GuvenliYaz(f, Json.GuzelYaz(h), new UTF8Encoding(true));
        }

        public OrderedDictionary GerberAyar()
        {
            return Json.H("gerber", Gerber, "accumark", AccuMark, "userroot", Userroot, "depo", Depo, "kuyruk", Kuyruk, "otopastal", Otopastal, "surucu", Surucu, "surucu2", Surucu2);
        }
    }

    // kullanıcıya ait ayarlar (Excel klasörü, görünüm, pencere yeri): güncelleme ve kurulum bunlara dokunmaz
    static class Kullanici
    {
        static readonly object kilit = new object();
        static string Dosya_ { get { return Path.Combine(Yer.Kok, "kullanici.json"); } }

        public static OrderedDictionary Oku()
        {
            lock (kilit)
            {
                try
                {
                    string f = Dosya_;
                    if (File.Exists(f))
                    {
                        OrderedDictionary d = Json.Oku(File.ReadAllText(f, Encoding.UTF8)) as OrderedDictionary;
                        if (d != null) return d;
                    }
                }
                catch { }
                return new OrderedDictionary(StringComparer.Ordinal);
            }
        }

        public static string Al(string ad) { return Json.Str(Oku(), ad); }

        public static void Yaz(string ad, object deger)
        {
            lock (kilit)
            {
                OrderedDictionary h = Oku();
                h[ad] = deger;
                Dosya.GuvenliYaz(Dosya_, Json.GuzelYaz(h), Dosya.Utf8);
            }
        }
    }

    static class Surum
    {
        // surum.json: { surum, tarih, notlar }
        public static IDictionary Yerel()
        {
            try
            {
                IDictionary d = Json.Oku(File.ReadAllText(Path.Combine(Yer.Kok, "surum.json"), Encoding.UTF8)) as IDictionary;
                if (d != null) return d;
            }
            catch { }
            return Json.H("surum", "0.0.0", "notlar", new object[0]);
        }

        public static Version No(string v)
        {
            try { return new Version((v ?? "").Trim()); } catch { return new Version(0, 0); }
        }
    }
}
