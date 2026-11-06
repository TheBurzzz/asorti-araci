<p align="center"><img src="AsortiAraci/sistem/eleman.png" width="112" alt="Eleman simgesi"></p>
<h1 align="center">Eleman</h1>
<p align="center">Kesim planlamanın yardımcısı: <b>Asorti Aracı</b> ve <b>Ölçü Tablosu</b> tek programda.</p>

| Uygulama | Ne yapar |
|---|---|
| **Asorti Aracı** | Siparişi yaz, asortiyi hesapla, Excel'e kaydet. Pastalları Gerber'e gönder. |
| **Ölçü Tablosu** | Müşteri kağıdını tara, ölçü tablosunu kontrol et, Excel'e kaydet ve yazdır. Öğrendiklerini bütün bilgisayarlarla paylaşır. |

Eleman açılınca ana sayfa gelir; sol üstteki Eleman simgesinden (ya da **Ctrl+1 / 2 / 3** ile) uygulamalar arasında geçilir.

## Kurulum
1. Bu sayfada yeşil **Code** düğmesi → **Download ZIP**.
2. ZIP'i bir klasöre çıkar.
3. **Kurulum.bat**'a çift tıkla. Sihirbaz adım adım kurar; masaüstünde **Eleman** simgesi belirir.

Müşteri şablonları ve ortak hafıza kendiliğinden gelir. Sihirbaz bilgisayarı kendisi tarar, soru sormaz:
- **Gerber AccuMark** nerede (sürümü, klasörü), **müşteri klasörleri** nerede (`userroot\storage`, başka diskte ya da ağda olsa da),
- **OTOPASTAL** (AccuNest kuyruğu) bu bilgisayarda mı, ağdaki başka bir bilgisayarda mı, hiç yok mu,
  pastallara **hangi sürücü harfiyle** ulaşıyor (kuyruktaki geçmiş işlerden öğrenir).

Gerber yoksa yalnız asorti ve ölçü tablosu kurulur. Kurulduktan sonra bir şey değişirse (AccuMark yeni sürüme geçti,
OTOPASTAL başka bilgisayara taşındı) **⚙ → Gerber bağlantısı → Otomatik bul** yeterli; yeniden kurmak gerekmez.

## Güncelleme
Eleman açılışta kendisi bakar, yeni sürüm varsa haber verir. Elle: **⚙ → Güncellemeleri denetle**.
Çalışma sayfaları, ayarlar ve öğrenilenler korunur; bir önceki sürüm kurulum klasöründeki `yedek` klasöründe durur.

## Klasörler
| Klasör | İçinde |
|---|---|
| `AsortiAraci/` | Programın kendisi (kurulan dosyalar). Adı, eski sürümler güncellemeyi bu klasörden aldığı için şimdilik böyle. |
| `kaynak/` | Kaynak dosyalar: Eleman kabuğu (`eleman/`), Ölçü Tablosu (`olcu/`). |
| `kurulum/` | Kurulum sihirbazı (`Kurulum.bat` bunu çalıştırır). |
| `ELEMAN_DURUM.md` | Geliştirme notları. |

Müşteri şablonları ve öğrenilen ölçüler ayrı, gizli **eleman-hafiza** deposunda durur; program deposunda müşteri bilgisi yoktur.

## Dallar
- **`eleman`**: Eleman (en yeni sürüm).
- **`main`**: iş bilgisayarındaki sürüm; Eleman orada denenip onaylanınca buraya geçer.
- **`surum-v…`**, **`arsiv`**: eski sürümler. Dal seçiciden seç → **Code** → **Download ZIP** → **Kurulum.bat**.
