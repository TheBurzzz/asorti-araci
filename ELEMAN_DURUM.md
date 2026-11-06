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

- Okur-yazar ortak hafıza anahtarı (`github_pat_…`, `anahtar.txt`): yalnız kullanıcının bilgisayarlarında. Salt-okur anahtar
  yalnız karışık yazılmış hâliyle girer (aşağıda "Anahtarlar").
- Müşteri şablonları (`sablonlar.json`: müşteri adları, logolar), müşteri kağıtları/taramaları, KESİM RAPORLARI,
  deneme verileri (`base.json`). Bunlar gizli `eleman-hafiza` deposunda ya da Eleman sohbetinin çalışma alanında durur.
- Kök `.gitignore`: `anahtar.txt`, `guncelleme_anahtari.txt`, `sablonlar.json`, `olcu_sablonlar.json` yanlışlıkla eklenmesin.

## Anahtarlar (kullanıcının kararı, 6 Kasım 2026 gece)

Kullanıcı: "uygulamayı indirdiğim an kendinden anahtarlı olsun; müşteri bilgileri çok gizli değil." Önce gizli depo
düşünüldü; kullanıcı istemedi (başka bilgisayarda adını yazıp programı gösterebilmek, hesabına girmeden indirebilmek
istiyor). **Program deposu herkese açık kalır.** Karar:
- **Güncel karar (6 Kasım 2026, 22:58):** "her pc hem öğrensin hem öğretsin; 1 yıl sonra başka bir bilgisayara geçtiğimde
  sana 'bu benim bilgisayarım' demek zorunda kalmayayım." Asıl kullanım iş bilgisayarı, ev deneme. Bu yüzden **programın
  içindeki anahtar** (`SunucuOlcu.cs` → `OKUMA`, ters + "eleman-okuma" ile XOR + base64; GitHub'daki adı `eleman-okuma`,
  yalnız `eleman-hafiza`) her kurulumda kullanılır ve kullanıcı onu GitHub'da **Contents: Read and write** yapar.
  Düz yazılmaz çünkü GitHub herkese açık depoda gördüğü anahtarı iptal eder; gizleme değildir, kurcalayan çözebilir
  (kullanıcı kabul etti: müşteriler gizli değil, başkası kullanmıyor). Başkası da kullanırsa öğrendikleri ortak olur.
- Sunucu `salt` hep false. Ölçü Tablosu yazmayı dener; GitHub 403 derse (anahtar yalnız okuyorsa) kendiliğinden yalnız
  okumaya geçer (`SYNC.salt`, "Ortak hafıza (okuma)"), bir sonraki açılışta yine dener.
- Koruma: ortak hafıza silinir ya da bilgisayarın bildiğinin yarısından azı kalırsa (`saves`, en az 20) o bilgisayardaki
  kopya geri yüklenir. Müşterilerden yarısı ya da fazlası (en az 2) birden kaybolursa yeniden gönderilir; tek tük kaybolan
  başka bilgisayarda silinmiştir, burada da silinir (yeni gönderilen 2 dk sayılmaz). GitHub her sürümü saklar.
- `anahtar.txt` (ayrı okur-yazar anahtar) artık şart değil; evde var, kalabilir (programdaki anahtar iptal edilse de o
  bilgisayar yazmaya devam eder). İş bilgisayarına konması gerekmiyor.
- Güncellemeler herkese açık yoldan, eskisi gibi. 3.0.2'deki `guncelleme_anahtari.txt` desteği boşta bekler (dosya yoksa
  hiçbir şey yapmaz); depo bir gün gizli yapılırsa işe yarar.

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

- 2026-11-06 gece: **Eleman 3.0.1** (yalnız `eleman` dalı; kullanıcının evdeki kurulumu bu daldan güncellenir).
  Kullanıcının kısaltmaları: **AA** = Asorti Aracı, **ÖT** = Ölçü Tablosu.
  - Simge: kurulumdaki derleme (sistem/ortak.ps1) de eleman.ico kullanır; kısayollar (Kisayol.cs) eleman.ico'ya bağlanır,
    güncellenen kurulumlarda masaüstü / Başlat'taki "Asorti Araci.lnk" adı "Eleman.lnk" olur (görev çubuğuna sabitlenmişe dokunulmaz).
  - Açılış (X / Twitter iOS gibi): yerel açılış ekranı (Acilis.cs) düz zemin + ortada 104 px simge (sistem/acilis/orta_*.png
    yalnız simge). Sayfa da aynı görüntüyle açılır (#acilis); yerel ekran kalkınca Eleman sayfaya {t:"acilis"} yollar, simge
    küçülüp büyür, içi pencere olur ve uygulama görünür (tuval, ~0,9 sn). Aynı oturumda yenilemede oynamaz (sessionStorage).
  - Üst çubuk: AA / ÖT düğmeleri kalktı; sol üstteki Eleman simgesi menü açar (Ana sayfa, AA, ÖT). Etiket: "Eleman › Asorti Aracı".
  - Sayfa kendiliğinden açılmaz; boşken AA / ÖT boş ekranı (Yeni sayfa düğmesi). Ana sayfada sürüm yazmaz (yalnız ⚙).
  - Hız: sayfalar ilk açılınca yüklenir; AA'da en çok 4, ÖT'de 3 sayfa canlı, gerisi uyur (AA: yalnız boş ya da tablosu
    kaydedilmiş sayfa uyur; Gerber işi süren uyumaz. ÖT: okuma / kayıt sürerken uyumaz, uyumadan önce taslakYaz(true)).
    Sekme adları kalıcı (S.ad / SO.ad).
  - ÖT: müşteri döşemeleri (şablondaki logo + ad; sıra Sorgenfri, Lykka, Deerberg, Heiter, sonra alfabetik), başlıkta
    "＋ Müşteri ekle" ve "Sıfırla" (AA'daki gibi; Kaydet'teki "Yeni tablo" kalktı), Tara'da bağlı tarayıcının adı ya da
    "Tarayıcı bağlı değil", "Kağıdı yanda aç": taranan kağıt solda, seçili satırın kağıttaki yeri işaretli (satırlarda yer:{pg,a,b}),
    "✓ Onayla" düğmesi. Eleman sekmesinde tablo kaydedilse de sekmede durur, program açılınca sessizce geri gelir.

- 2026-11-06 gece: **Eleman 3.0.2** (yalnız `eleman`): anahtarlı güncelleme (yukarıdaki "Gizli depo" 1. aşama),
  güncelleme yedeğine `olcu_tablosu_araci.html` de girdi, kök `.gitignore`. Linux'ta mono ile denendi: anahtarla surum.json,
  zipball (302 → codeload, 10 MB, `TheBurzzz-asorti-araci-<sha>/AsortiAraci/...`). (Gizli depo planı sonra iptal edildi.)
- 2026-11-06 gece: **Eleman 3.0.3** (yalnız `eleman`): salt-okur hafıza (yukarıda "Anahtarlar"). Kullanıcının `eleman-okuma`
  anahtarı `OKUMA`'da karışık yazılı (düz hâli yalnız Eleman sohbetinin çalışma alanında, depoda yok). Okuma izni
  raw.githubusercontent ile doğrulandı (sahte anahtar 404, bu anahtar 200); yazma izni yokluğu token sayfasının ekran görüntüsüyle
  doğrulandı: yalnız `TheBurzzz/eleman-hafiza`, Contents Read-only, Metadata Read-only, süresiz. (Buradan api.github.com /
  github.com denemesi olmaz: vekil kendi kimliğini koyuyor.) Anahtar değişecekse: önce yeni salt-okur token → `OKUMA`
  yeniden karışık yazılır → yeni sürüm yayınlanır → kurulumlar güncellenince eskisi silinir (önce silinirse yeni kurulumlar müşterisiz kalır). mono + Playwright (GitHub taklit) ile denendi:
  okuma anahtarıyla yalnız GET (hafiza.json, sablonlar), PUT/DELETE hiç yok; yerel öğrenilen, eklenen ve silinen
  müşteri yerelde kalıyor; `anahtar.txt` varken `salt:false`, okur-yazar anahtar.

- 2026-11-06 gece: **Eleman 3.0.4** (yalnız `eleman`), Ölçü Tablosu (kullanıcı Eleman sohbetinden istedi):
  - Logo: şablonlarda müşteri logosu F7:I10 kutusundan taşıyor (Lykka üst/alt, Strikkeby ve Story of Mine yanlar; Excel'de
    gölgeli beyaz kart olarak görünüyor). `buildXlsx` → `logoSigdir`: merkezi boş bir birleşik hücreye düşen resim o kutuya
    oranı korunarak, ortalanarak, %9 payla sığdırılır (oneCellAnchor). Şirket logosu (D2) ve nokta şekli dokunulmaz.
    Önizleme sütun pikselleri Excel'deki gibi (`xlPx`: (256w+18)/256*7; eskiden w*7+5). LibreOffice ve önizlemeyle 7 müşteri denendi.
  - Beden dizisi: `SZ={list,sample,base,elle}`; "Beden dizisi" menüsü (şablondaki, hazır harf/numara dizileri, son elle
    yazılanlar `ota_beden_son`, elle yaz). Dizideki bir bedene basınca kağıttan araya giren beden geri alınır. Müşteri
    değişince / boş tabloda şablondakine döner; taramadan sonra elle seçilen dizi kalır. Az bedenli dizide yazdırma alanı
    şablonun genişliğinde kalır (Development başlığı kesilmesin).

- 2026-11-06 gece: **Eleman 3.0.5** (yalnız `eleman`): her kurulum ortak hafızaya yazar (yukarıda "Anahtarlar"), 403'te
  yalnız okumaya geçer, silinen / bozulan hafıza ve müşteriler geri yüklenir. Playwright + GitHub taklidiyle 6 durum denendi
  (yazabilen, 403, hafıza 404, hafıza küçülmüş, 3 müşteriden 2'si kayıp, 1'i silinmiş).

- 2026-11-06 gece: **Eleman 3.0.6** (yalnız `eleman`):
  - Açılış (kullanıcı: "daha efektli, logonun içine giriliyormuş gibi, ekrana çarpıyormuş gibi, saçma efekt yok"): simge
    vektör çizilir (`ADAM` = eleman.svg'deki çizgiler, kabuk_yap.py çıkarır). 300 ms geri çekilme (0,82), 640 ms dalış
    (üstel büyüme, yakınlaşma merkezi simge ortasından yüze kayar: FX,FY=32,28.6; yüzün içi ekranı p≈0,74'te kaplar),
    sarı dağılırken üst çubuk ve ana sayfa "çarpar" (1,18 → 0,982 → 1,004 → 1, 620 ms). Toplam ≈1,3 sn. Kareler denendi.
  - Ölçü Tablosu `logoIsle`: müşteri logosunun zemini kırpılır (saydam ya da düz renk; düz renk zemin yumuşak kenarla
    saydam yapılır), PNG olur (`xl/media/eleman_logoN.png`, eski resim kullanılmıyorsa silinir), gölgesi kaldırılır, kutuya
    %5 payla sığar. Desenli zemine (Deerberg) dokunulmaz. Müşteri döşemelerinde de kırpılmış logo. JSZip'e
    `createFolders:false` (çıktıda klasör girdisi kalmasın). LibreOffice ile 7 müşteri denendi.

- 2026-11-06 gece: **Eleman 3.0.7** (yalnız `eleman`): açık görünüm "Liquid Glass" (kullanıcı: "gece modu çok güzel, açık
  tema da hayran bıraksın"). Tek dosya: `AsortiAraci/sistem/eleman_cam.css`, yalnız `html:not([data-theme=dark])`:
  kabuk (`[data-uyg]`, kabuk_yap.py `</style></head>`'e <link> ekler), Asorti sayfaları (kabuk iframe'e `camEkle(f)` ile
  <link> ekler ve `data-eleman="asorti"` yapar; **asorti_araci.html değişmedi**), Ölçü (src.html `data-eleman="olcu"` + <link>).
  Değişkenler (--bg #e2e7f0, --glass daha saydam, --gb/--hi parlak kenar, --sh ince çizgi + derinlik, --btn cam kapsül,
  --bl1..5 canlı lekeler); bileşen kuralları `:where()` ile (sayfanın temel kuralı kadar özgül; .btn.pri, .btn.duz,
  button.exb gibi özellere dokunmaz). Kartlarda backdrop-filter yalnız saturate (blur yok: zemin yumuşak, kaydırmada pahalı).
  Yerel açılış zemini (Acilis.cs) açıkta 226,231,240 (yeni --bg ile aynı, geçişte renk atlamasın). Koyu görünüm piksel
  piksel aynı kaldı (karşılaştırıldı). **Asorti sohbeti:** açık temada renk değişkenlerini değiştirirse eleman_cam.css'e de bakmalı.

## Sıradaki işler

1. ✓ Müşteri şablonları gizli `eleman-hafiza` deposunda: `olcu-tablosu/veri/sablonlar.json` (2026-11-06, 7 müşteri).
   Eleman ilk açılışta `anahtar.txt` ile oradan indirip `olcu_sablonlar.json` olarak saklar, 6 saatte bir arka planda tazeler
   (SunucuOlcu.cs: OlcuSablonIndir). Bu klasör çalışan Ölçü Tablosu'nun okuduğu `olcu-tablosu/sablonlar/` değildir, ona karışmaz.
   Claude'un GitHub uygulaması artık `eleman-hafiza`'ya da erişebiliyor.
2. ✓ Masaüstü kısayolunun adı ve simgesi "Eleman" (kurulum ve güncelleme).
3. Ölçü: birden çok sekme açıkken ortak hafıza eşitlemesini tek sekme yapsın.
4. ⚙ menüsünde Ölçü'nün ayarları (şimdilik düğme Ölçü'nün kendi ayar penceresini açıyor).
5. Sürüm 3.0.0 → iş bilgisayarında deneme (Asorti sayfaları, Gerber, Ölçü kaydet / Excel'de aç / tara, güncelleme) → main.
6. El yazısı okuma modeli (Eleman'ın ilk sürümünde olacak).
