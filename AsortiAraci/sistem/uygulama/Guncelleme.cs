// Asorti Aracı - güncelleme: GitHub'daki yeni sürümü bulur, indirir, eskisini yedekler, yenisini yerine koyar.
// Uygulamanın kendisi (sistem\uygulama\*.cs) değiştiyse bu bilgisayarda Windows'un kendi derleyicisiyle yeniden derlenir;
// derlenemezse eski pencere çalışmaya devam eder (güncelleme uygulamayı asla bozmaz).
using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Threading;

namespace AsortiAraci
{
    sealed partial class Sunucu
    {
        object uzak;
        DateTime uzakZaman = DateTime.MinValue;
        volatile bool guncelleniyor;

        object UzakSurum(bool taze)
        {
            Ayarlar a = A;
            if (a.Guncelleme.Length == 0) return null;
            if (!taze && uzak != null && (DateTime.Now - uzakZaman).TotalMinutes < 10) return uzak;
            Web.Hazirla();
            string metin = Web.Metin("https://raw.githubusercontent.com/" + a.Guncelleme + "/" + a.Dal + "/AsortiAraci/surum.json?t=" + DateTime.UtcNow.Ticks, 8000);
            uzak = Json.Oku(metin);
            uzakZaman = DateTime.Now;
            return uzak;
        }

        OrderedDictionary GuncellemeVarMi(bool taze)
        {
            IDictionary y = Surum.Yerel();
            object u;
            try { u = UzakSurum(taze); }
            catch (Exception ex) { return Json.H("hata", "Güncelleme sunucusuna ulaşılamadı: " + ex.Message, "yerel", Json.Str(y, "surum")); }
            if (u == null) return Json.H("var", false, "yerel", Json.Str(y, "surum"), "kapali", true);
            object notlar = Json.Al(u, "notlar");
            if (notlar == null) notlar = new object[0];
            else if (!(notlar is IList)) notlar = new object[] { notlar };
            return Json.H("var", Surum.No(Json.Str(u, "surum")) > Surum.No(Json.Str(y, "surum")), "yerel", Json.Str(y, "surum"), "yeni", Json.Str(u, "surum"), "tarih", Json.Str(u, "tarih"), "notlar", notlar);
        }

        void GuncelleIstek(HttpListenerContext ctx)
        {
            if (A.Guncelleme.Length == 0) { JsonYanit(ctx, Json.H("hata", "Güncelleme adresi ayarlı değil.")); return; }
            if (SurenIs()) { JsonYanit(ctx, Json.H("hata", "Gerber'de süren bir iş var. Pastallar bitince güncelle.")); return; }
            if (guncelleniyor) { JsonYanit(ctx, Json.H("hata", "Güncelleme zaten sürüyor.")); return; }
            guncelleniyor = true;
            string yeni;
            bool yeniden;
            try { yeni = Guncelle(out yeniden); }
            catch (Exception ex)
            {
                guncelleniyor = false;
                Kayit.Yaz("guncelleme hatasi: " + ex.Message);
                JsonYanit(ctx, Json.H("hata", "Güncellenemedi: " + ex.Message));
                return;
            }
            JsonYanit(ctx, Json.H("ok", true, "surum", yeni));
            guncelleniyor = false;
            Thread.Sleep(200);
            // sayfa yeni program kimliğini görünce kendini tazeler; uygulamanın kendisi değiştiyse pencere yeniden açılır
            if (yeniden && Pencere != null) Pencere.Guncellendi(true);
            else
            {
                Id = YeniId();
                if (Pencere != null) Pencere.Guncellendi(false);
            }
        }

        string Guncelle(out bool yenidenBaslat)
        {
            yenidenBaslat = false;
            Web.Hazirla();
            Ayarlar a = A;
            string tmp = Path.Combine(Path.GetTempPath(), "asorti_guncelleme_" + Guid.NewGuid().ToString("N").Substring(0, 8));
            Directory.CreateDirectory(tmp);
            try
            {
                string zip = Path.Combine(tmp, "paket.zip");
                Web.Indir("https://codeload.github.com/" + a.Guncelleme + "/zip/refs/heads/" + a.Dal, zip, 120000);
                string ac = Path.Combine(tmp, "ac");
                System.IO.Compression.ZipFile.ExtractToDirectory(zip, ac);
                string[] ici = Directory.GetDirectories(ac);
                if (ici.Length == 0) throw new Exception("indirilen paket boş");
                string ic = ici[0], src = Path.Combine(ic, "AsortiAraci");
                foreach (string g in new string[] { "uygulama.html", "asorti_araci.html", "surum.json", "sistem/sunucu.ps1", "sistem/ortak.ps1", "sistem/bul.ps1", "sistem/tara.ps1", "kopru/kopru.ps1", "sistem/uygulama/Program.cs" })
                {
                    if (!File.Exists(Path.Combine(src, g.Replace('/', Path.DirectorySeparatorChar)))) throw new Exception("indirilen pakette " + g + " yok");
                }
                string yeni = Json.Str(Json.Oku(File.ReadAllText(Path.Combine(src, "surum.json"), Encoding.UTF8)), "surum");
                string eski = Json.Str(Surum.Yerel(), "surum");
                Yedekle();
                // yeni dosyaları yerine koy (ayarlar, çalışma sayfaları, sipariş kayıtları pakette yok, dokunulmaz)
                int ertelenen = Kopyala(src, Yer.Kok);
                string kp = Path.Combine(ic, "kurulum");
                if (Directory.Exists(kp))
                {
                    string hk = Yer.Yol("kurulum_paketi");
                    try { if (Directory.Exists(hk)) Directory.Delete(hk, true); } catch { }
                    KlasorKopyala(ic, hk);
                }
                Kayit.Yaz("guncellendi: " + eski + " -> " + yeni + (ertelenen > 0 ? " (" + ertelenen + " dosya yeniden acilista yerine konacak)" : ""));
                if (Derleyici.KaynakDegisti())
                {
                    string hata;
                    if (Derleyici.Derle(out hata)) yenidenBaslat = true;
                    else Kayit.Yaz("yeni surum derlenemedi, simdiki pencere calismaya devam ediyor: " + hata);
                }
                if (ertelenen > 0) yenidenBaslat = true;
                return yeni;
            }
            finally { try { Directory.Delete(tmp, true); } catch { } }
        }

        // geri dönebilmek için şimdiki sürümü yedekle (sadece program dosyaları)
        static void Yedekle()
        {
            string yd = Yer.Yol("yedek");
            try { if (Directory.Exists(yd)) Directory.Delete(yd, true); } catch { }
            Directory.CreateDirectory(Path.Combine(yd, "sistem"));
            Directory.CreateDirectory(Path.Combine(yd, "kopru"));
            foreach (string f in new string[] { "uygulama.html", "asorti_araci.html", "surum.json" })
            {
                string k = Yer.Yol(f);
                if (File.Exists(k)) File.Copy(k, Path.Combine(yd, f), true);
            }
            foreach (string f in Directory.GetFiles(Yer.Sistem)) { try { File.Copy(f, Path.Combine(Path.Combine(yd, "sistem"), Path.GetFileName(f)), true); } catch { } }
            string uk = Path.Combine(Yer.Sistem, "uygulama");
            if (Directory.Exists(uk)) KlasorKopyala(uk, Path.Combine(Path.Combine(yd, "sistem"), "uygulama"));
            string kk = Yer.Yol("kopru");
            if (Directory.Exists(kk)) foreach (string f in Directory.GetFiles(kk, "*.ps1")) { try { File.Copy(f, Path.Combine(Path.Combine(yd, "kopru"), Path.GetFileName(f)), true); } catch { } }
        }

        // aynı olan dosyaya dokunmaz; kullanımda olan (açık) dosyayı ".yeni" adıyla bırakır, yeniden açılışta yerine konur
        static int Kopyala(string kaynak, string hedef)
        {
            int ertelenen = 0;
            Directory.CreateDirectory(hedef);
            foreach (string f in Directory.GetFiles(kaynak))
            {
                string h = Path.Combine(hedef, Path.GetFileName(f));
                if (Ayni(f, h)) continue;
                try { File.Copy(f, h, true); }
                catch (Exception ex)
                {
                    if (!(ex is IOException || ex is UnauthorizedAccessException)) throw;
                    File.Copy(f, h + ".yeni", true);
                    ertelenen++;
                }
            }
            foreach (string d in Directory.GetDirectories(kaynak)) ertelenen += Kopyala(d, Path.Combine(hedef, Path.GetFileName(d)));
            return ertelenen;
        }

        static bool Ayni(string a, string b)
        {
            try
            {
                FileInfo fa = new FileInfo(a), fb = new FileInfo(b);
                if (!fb.Exists || fa.Length != fb.Length) return false;
                byte[] x = File.ReadAllBytes(a), y = Dosya.PaylasimliOku(b);
                if (x.Length != y.Length) return false;
                for (int i = 0; i < x.Length; i++) if (x[i] != y[i]) return false;
                return true;
            }
            catch { return false; }
        }

        static void KlasorKopyala(string kaynak, string hedef)
        {
            Directory.CreateDirectory(hedef);
            foreach (string f in Directory.GetFiles(kaynak)) File.Copy(f, Path.Combine(hedef, Path.GetFileName(f)), true);
            foreach (string d in Directory.GetDirectories(kaynak)) KlasorKopyala(d, Path.Combine(hedef, Path.GetFileName(d)));
        }
    }

    // uygulamayı bu bilgisayarda .NET Framework'ün kendi derleyicisiyle (csc.exe) derler: sistem\AsortiAraci.exe
    static class Derleyici
    {
        public const string ExeAd = "AsortiAraci.exe";

        static string Klasor { get { return Path.Combine(Yer.Sistem, "uygulama"); } }

        public static string[] Kaynaklar()
        {
            string[] k = Directory.GetFiles(Klasor, "*.cs");
            Array.Sort(k, StringComparer.OrdinalIgnoreCase);
            return k;
        }

        // kaynakların, ekranın ve WebView2 dosyalarının parmak izi: değişince yeniden derlenir
        public static string Damga()
        {
            using (MD5 md5 = MD5.Create())
            using (MemoryStream ms = new MemoryStream())
            {
                List<string> l = new List<string>(Kaynaklar());
                l.Add(Path.Combine(Klasor, "uygulama.manifest"));
                l.Add(Path.Combine(Yer.Sistem, "Microsoft.Web.WebView2.Core.dll"));
                l.Add(Path.Combine(Yer.Sistem, "Microsoft.Web.WebView2.WinForms.dll"));
                foreach (string f in l)
                {
                    string g = File.Exists(f + ".yeni") ? f + ".yeni" : f;
                    if (!File.Exists(g)) continue;
                    byte[] ad = Encoding.UTF8.GetBytes(Path.GetFileName(f).ToLowerInvariant() + "|");
                    ms.Write(ad, 0, ad.Length);
                    byte[] v = File.ReadAllBytes(g);
                    ms.Write(v, 0, v.Length);
                }
                return BitConverter.ToString(md5.ComputeHash(ms.ToArray())).Replace("-", "");
            }
        }

        public static bool KaynakDegisti()
        {
            try { return Dosya.MetinOku(Path.Combine(Yer.Sistem, "AsortiAraci.surum")).Trim() != Damga(); } catch { return true; }
        }

        // AsortiAraci.yeni.exe olarak derler (çalışan uygulamaya dokunmaz); yerine koyma yeniden açılışta olur
        public static bool Derle(out string hata)
        {
            hata = "";
            string csc = Path.Combine(System.Runtime.InteropServices.RuntimeEnvironment.GetRuntimeDirectory(), "csc.exe");
            if (!File.Exists(csc)) { hata = "csc.exe bulunamadı"; return false; }
            string yeni = Path.Combine(Yer.Sistem, "AsortiAraci.yeni.exe");
            try { File.Delete(yeni); } catch { }
            string wvc = Path.Combine(Yer.Sistem, "Microsoft.Web.WebView2.Core.dll"), wvw = Path.Combine(Yer.Sistem, "Microsoft.Web.WebView2.WinForms.dll");
            if (File.Exists(wvc + ".yeni")) wvc += ".yeni";
            if (File.Exists(wvw + ".yeni")) wvw += ".yeni";
            StringBuilder a = new StringBuilder("/nologo /target:winexe /optimize+ /platform:anycpu /codepage:65001");
            a.Append(" \"/out:").Append(yeni).Append('"');
            a.Append(" \"/win32icon:").Append(Path.Combine(Yer.Sistem, "asorti.ico")).Append('"');
            a.Append(" \"/win32manifest:").Append(Path.Combine(Klasor, "uygulama.manifest")).Append('"');
            foreach (string r in new string[] { "System.dll", "System.Core.dll", "System.Drawing.dll", "System.Windows.Forms.dll", "System.Management.dll", "System.IO.Compression.dll", "System.IO.Compression.FileSystem.dll" }) a.Append(" /r:").Append(r);
            a.Append(" \"/r:").Append(wvc).Append('"').Append(" \"/r:").Append(wvw).Append('"');
            foreach (string k in Kaynaklar()) a.Append(" \"").Append(k).Append('"');
            string cikti = "";
            int kod = -1;
            try
            {
                ProcessStartInfo si = new ProcessStartInfo(csc, a.ToString());
                si.UseShellExecute = false;
                si.CreateNoWindow = true;
                si.RedirectStandardOutput = true;
                si.RedirectStandardError = true;
                si.WorkingDirectory = Yer.Sistem;
                using (Process p = Process.Start(si))
                {
                    System.Threading.Tasks.Task<string> e = p.StandardError.ReadToEndAsync();
                    cikti = p.StandardOutput.ReadToEnd();
                    p.WaitForExit(120000);
                    cikti += e.Result;
                    kod = p.HasExited ? p.ExitCode : -1;
                }
            }
            catch (Exception ex) { hata = ex.Message; }
            bool ok = kod == 0 && File.Exists(yeni);
            try { File.WriteAllText(Path.Combine(Yer.Log, "uygulama_derleme.txt"), DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + (ok ? " derlendi" : " DERLENEMEDI") + "\r\n" + cikti + hata, Dosya.Utf8); } catch { }
            if (!ok) { if (hata.Length == 0) hata = cikti.Length > 400 ? cikti.Substring(0, 400) : cikti; return false; }
            try { File.WriteAllText(Path.Combine(Yer.Sistem, "AsortiAraci.yeni.surum"), Damga(), Encoding.ASCII); } catch { }
            Kayit.Yaz("uygulama derlendi: AsortiAraci.yeni.exe");
            return true;
        }

        // bekleyen ".yeni" dosyaları yerine koyar (çalışan exe ve yüklü dosyalar da yeniden adlandırılabilir)
        public static int YeniDosyalariYerlestir()
        {
            int n = 0;
            List<string> yeniler = new List<string>();
            try { yeniler.AddRange(Directory.GetFiles(Yer.Sistem, "*.yeni", SearchOption.AllDirectories)); } catch { }
            string yexe = Path.Combine(Yer.Sistem, "AsortiAraci.yeni.exe");
            if (File.Exists(yexe)) yeniler.Add(yexe);
            foreach (string y in yeniler)
            {
                string h = y.EndsWith(".yeni.exe", StringComparison.OrdinalIgnoreCase) ? y.Substring(0, y.Length - 9) + ".exe" : y.Substring(0, y.Length - 5);
                try
                {
                    string e = null;
                    if (File.Exists(h))
                    {
                        e = h + ".eski";
                        try { if (File.Exists(e)) File.Delete(e); } catch { e = h + "." + DateTime.Now.Ticks + ".eski"; }
                        File.Move(h, e);
                    }
                    try { File.Move(y, h); }
                    catch
                    {
                        // yenisi konamadıysa eskisi yerine döner: uygulama hiçbir zaman dosyasız kalmaz
                        if (e != null && !File.Exists(h)) { try { File.Move(e, h); } catch { } }
                        throw;
                    }
                    n++;
                }
                catch (Exception ex) { Kayit.Yaz("yerine konamadi: " + y + " (" + ex.Message + ")"); }
            }
            string ys = Path.Combine(Yer.Sistem, "AsortiAraci.yeni.surum");
            if (File.Exists(ys)) { try { Dosya.Degistir(ys, Path.Combine(Yer.Sistem, "AsortiAraci.surum")); } catch { } }
            return n;
        }

        public static void EskileriSil()
        {
            try
            {
                foreach (string e in Directory.GetFiles(Yer.Sistem, "*.eski", SearchOption.AllDirectories)) { try { File.Delete(e); } catch { } }
            }
            catch { }
        }
    }
}
