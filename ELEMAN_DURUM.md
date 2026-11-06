# Eleman — ortak durum notu

Bu dosya üç sohbetin (Asorti Aracı, Ölçü Tablosu Aracı, Eleman) ortak defteridir.
Her sohbet işe başlamadan önce bunu okur, iş bitince "Son durum" bölümünü günceller.

## Dallar (branch)

| Dal | Ne | Kural |
|---|---|---|
| `main` | Çalışan **Asorti Aracı** (v2.x). Kurulu bütün programlar güncellemeyi buradan alır. | Eleman hazır ve iş bilgisayarında denenmiş olmadan **Eleman buraya girmez**. |
| `exe-deneme` | Asorti'nin çalışma dalı (Asorti sohbeti). | Asorti düzeltmeleri eskisi gibi: exe-deneme → main. |
| `eleman` | **Eleman** geliştirme dalı. | Asorti'ye gelen her düzeltme buraya da alınır: `git merge main`. |
| `surum-vX.Y.Z`, `arsiv` | Eski sürümlerin arşivi. | Dokunulmaz. |

## Değişmeyecekler (çalışan hiçbir şey bozulmasın diye)

- Depo adı `asorti-araci` ve paketteki `AsortiAraci/` klasörü **aynı kalır**. Kurulu v2.x programların güncelleyicisi
  `AsortiAraci/surum.json` dosyasına ve zip içindeki `AsortiAraci/` klasörüne bakıyor; adı değişirse güncelleme durur.
- Kurulum klasörü `C:\AsortiAraci` aynı kalır (OTOPASTAL bağlantısı, WebView2 profili, çalışma sayfaları bu yolda).
- `AsortiAraci.exe` dosya adı şimdilik aynı; görünen ad (pencere, görev yöneticisi, bildirim, uyarılar) **Eleman**.
- Sunucu adresi `localhost:8642` aynı (sayfaların yerel kaydı bu adrese bağlı).

## Herkese açık depoya asla girmeyenler

- Ortak hafıza anahtarı (`github_pat_…`) → Eleman'da `C:\AsortiAraci\anahtar.txt` (kurulumla elden verilir).
- Müşteri şablonları (`sablonlar.json`: müşteri adları, logolar), müşteri kağıtları/taramaları, KESİM RAPORLARI,
  deneme verileri (`base.json`). Bunlar gizli `eleman-hafiza` deposunda ya da Eleman sohbetinin çalışma alanında durur.

## Tasarım kararları (6 Kasım 2026, kullanıcı)

- **Eleman**: sarı tema. Simge: sarı kare üstünde siyah çizgili, kasketli yardımcı eleman (`sistem/eleman.svg`).
- **Asorti Aracı**: mavi, **aynen kalır**.
- **Ölçü Tablosu Aracı**: yeşil tema; simge Excel'i / tabloyu andıran yeşil tablo (`sistem/olcu.svg`). Cetvel/metre simgesi kaldırıldı.
  Kullanımı Asorti gibi: üst çubukta sekmeler ("Sayfa 1", "+ Yeni sayfa").
- Açık/koyu görünüm yalnız **⚙ Ayarlar → Görünüm** içinde (Açık / Koyu / Otomatik + Gece ışığı). Üst çubukta ayrı tema düğmesi yok.
- Ana sayfa Apple tasarımından örnek alır; üç uygulama aynı tasarım dilinde (Inter, cam kartlar, yumuşak gölgeler).
- "Created by Şamil Yeşil" imzası her yerde kalır.
- Eleman'ın ilk sürümünde **el yazısı okuma modeli** bulunacak (unutulmayacak).

## Ölçü Tablosu kaynağı

- Kaynak: `kaynak/olcu/src.html` + `kaynak/olcu/veri/` (ölçü sözlüğü vb.). Eleman içindeki hali:
  `python kaynak/olcu/derle.py` → `AsortiAraci/olcu_tablosu_araci.html` (anahtarsız, şablonsuz).
- Masaüstündeki tek başına hali depo dışına derlenir: `derle.py --sablonlar <gizli> --anahtar <gizli> --cikti <depo dışı>`.
- Sunucu tarafı: `AsortiAraci/sistem/uygulama/SunucuOlcu.cs` (yalnız `/olcu/...` adresleri), kitaplıklar `AsortiAraci/sistem/olcu/`.

## Asorti ya da Ölçü değişince Eleman dalı nasıl güncellenir

- **Asorti düzeltmesi** (Asorti sohbeti): her zamanki gibi exe-deneme → main'e yayınla. Sonra eleman dalında `git merge main`.
  `AsortiAraci/uygulama.html` çakışırsa elle birleştirme yapılmaz: main'deki hali alınır ve Eleman kabuğu yeniden üretilir:
  `git show main:AsortiAraci/uygulama.html > /tmp/u.html && python3 kaynak/eleman/kabuk_yap.py /tmp/u.html AsortiAraci/uygulama.html`
- **Ölçü Tablosu düzeltmesi** (Ölçü sohbeti): `kaynak/olcu/src.html` eleman dalında düzeltilir, `python3 kaynak/olcu/derle.py`
  çalıştırılır (AsortiAraci/olcu_tablosu_araci.html yenilenir). Masaüstündeki tek başına hali gerekirse depo dışına derlenir.
- C# değişikliğinden sonra derleme denemesi (Linux, mono, Windows'taki csc.exe gibi C# 5): `KopruIcte.cs` yerine küçük bir taslak
  sınıfla `mcs -langversion:5` (Eleman sohbetinde `/home/claude/is/derle/derle.sh`).

## Son durum

- 2026-11-06 (Eleman sohbeti, öğleden sonra):
  - `eleman` dalı açıldı (main = v2.0.4'ten). main'e dokunulmadı.
  - Simgeler ve açılış ekranı Eleman; pencere, uyarı, bildirim, görev yöneticisi adı "Eleman". Ölçü sunucu bölümü (`/olcu/...`) eklendi.
  - Eleman kabuğu (`uygulama.html`): Apple tarzı ana sayfa (selam, iki uygulama kartı, canlı durum), üst çubukta
    Asorti Aracı / Ölçü Tablosu düğmeleri, Ölçü için Asorti'ninkiyle aynı sekmeler, ⚙ menüsünde açık uygulamanın bölümü,
    Ölçü'nün ortak hafıza durumu üst çubukta. Açılışta ana sayfa gelir.
  - Ölçü Tablosu: yeşil tema, tablo simgesi, tema düğmesi kaldırıldı, Eleman içinde başlıksız, sekme başına ayrı taslak,
    müşteri şablonları `/olcu/sablonlar`'dan (kurulumdaki gizli `olcu_sablonlar.json`).
  - Önizleme kullanıcının bilgisayarında: `Masaüstü\Ölçü Tablosu Aracı\exe-hazirlik\eleman_onizleme\Eleman.html`
    (sadece görünüş; sunucu yok, yazılanlar gerçek programlara karışmaz).
  - İş bilgisayarının kopyası Eleman sohbetinin çalışma alanında: `/home/claude/eleman-arsiv`
    (`is_pc_C` = C:\AsortiAraci ayarlar/kayıtlar/sayfalar, `is_pc_masaustu` = KESİM RAPORLARI + Ölçü Tablosu Aracı klasörü,
    `is_pc_ornekler` = son ölçü tabloları, müşteri logoları, bir tarama örneği). Gizli: GitHub'a konmaz.

- 2026-11-06 akşam: **Eleman 3.0.0** (yalnız `eleman` dalında). Kurulum sihirbazı Eleman adıyla; GitHub ZIP klasör adından
  (`asorti-araci-eleman`) güncelleme dalı `eleman` yazılır, böylece evdeki deneme kurulumu `eleman` dalındaki düzeltmeleri alır.
  Kullanıcıya evde denemesi için `Eleman_kurulum.zip` verildi (içinde anahtar.txt; GitHub'da yok).
  Linux'ta uçtan uca denendi: gerçek C# sunucusu (mono) + kabuk + Ölçü: şablonlar gizli depodan indi, PDF okundu (10 sn),
  Excel'e kaydedildi, Asorti sayfası açıldı. Tek 404: `kopru/alanlar.json` (Gerber'siz kurulumda zaten yok, eskiden de böyle).
  Deneme araçları (Eleman sohbeti): `/home/claude/is/e2e/e2e.py`, `/home/claude/is/derle/derle.sh`, `/home/claude/is/parse.ps1` (pwsh 7.4).

## Sıradaki işler

1. ✓ Müşteri şablonları gizli `eleman-hafiza` deposunda: `olcu-tablosu/veri/sablonlar.json` (2026-11-06, 7 müşteri).
   Eleman ilk açılışta `anahtar.txt` ile oradan indirip `olcu_sablonlar.json` olarak saklar, 6 saatte bir arka planda tazeler
   (SunucuOlcu.cs: OlcuSablonIndir). Bu klasör çalışan Ölçü Tablosu'nun okuduğu `olcu-tablosu/sablonlar/` değildir, ona karışmaz.
   Claude'un GitHub uygulaması artık `eleman-hafiza`'ya da erişebiliyor.
2. Masaüstü kısayolunun adı ve simgesi "Eleman"; Kurulum.ps1 ve Kaldir.bat'ta görünen ad.
3. Ölçü: birden çok sekme açıkken ortak hafıza eşitlemesini tek sekme yapsın.
4. ⚙ menüsünde Ölçü'nün ayarları (şimdilik düğme Ölçü'nün kendi ayar penceresini açıyor).
5. Sürüm 3.0.0 → iş bilgisayarında deneme (Asorti sayfaları, Gerber, Ölçü kaydet / Excel'de aç / tara, güncelleme) → main.
6. El yazısı okuma modeli (Eleman'ın ilk sürümünde olacak).
