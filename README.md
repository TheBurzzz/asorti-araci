# Asorti Aracı

Gerber AccuMark ile çalışan asorti / pastal planlama uygulaması.

## Kurulum
1. Sağ üstteki yeşil **Code** düğmesi → **Download ZIP**.
2. ZIP'i bir klasöre çıkar.
3. **Kurulum.bat** dosyasına çift tıkla; sihirbaz adım adım kurar.

Sihirbaz bilgisayarı kendisi tarar ve ona göre kurar, soru sormaz:
- **Gerber AccuMark** nerede (hangi sürüm, hangi klasör; açık programdan, kayıt defterinden, bilinen klasörlerden),
- **müşteri klasörleri** nerede (`userroot\storage`, başka diskte ya da ağda olsa da),
- **OTOPASTAL** (AccuNest kuyruğu) bu bilgisayarda mı, ağdaki başka bir bilgisayarda mı, hiç yok mu,
- OTOPASTAL pastallara **hangi sürücü harfiyle** ulaşıyor (kuyruktaki geçmiş işlerden öğrenir).

Duruma göre:
- **OTOPASTAL ayrı bilgisayarda:** gerekiyorsa bu bilgisayarın diskini paylaşır (yönetici izni sorar) ve OTOPASTAL için
  bir kerelik bağlantı dosyası hazırlar; dosyayı OTOPASTAL'ın masaüstüne koymayı dener. O dosya bağlantıyı her açılışta kendisi yeniler.
  Geçmiş işlerden harf zaten belliyse OTOPASTAL'da hiçbir şey yapmak gerekmez.
- **OTOPASTAL bu bilgisayarda:** paylaşım ya da bağlantı gerekmez; köprü OTOPASTAL programı kapalıysa açar.
- **OTOPASTAL yok:** pastallar Gerber'de oluşturulur, yerleştirme Gerber'de elle yapılır; boy ve verim tabloya Gerber'den okunur.
- **Gerber yok:** sadece asorti kurulur (asorti hesabı, Excel'e kaydetme, yazdırma çalışır).

Bulunanları değiştirmek istersen sihirbazda **Ayarları elle değiştir…**.
Kurulduktan sonra bir şey değişirse (AccuMark yeni sürüme geçti, OTOPASTAL başka bilgisayara taşındı) uygulamada
**⚙ → Gerber bağlantısı → Otomatik bul → Bulunanları kullan** yeterli; yeniden kurmak gerekmez.

## Güncelleme
Uygulamada **⚙ → Güncellemeleri denetle → Güncelle**.
Uygulama açılışta da kendisi bakar; yeni sürüm varsa üst çubukta **Güncelle** çıkar.
Çalışma sayfaları ve ayarlar korunur; bir önceki sürüm kurulum klasöründeki `yedek` klasöründe durur.

Sürüm bilgisi: `AsortiAraci/surum.json`

## Eski sürümler
Her sürüm GitHub'da kendi dalında saklanır: `surum-v1.0.0`, `surum-v1.0.1`, … (en yenisi en sonda).
Sayfanın üstündeki dal seçiciden (**main** yazan düğme) istediğin sürümü seç → yeşil **Code** → **Download ZIP** →
ZIP'i çıkar → **Kurulum.bat**. Kurulum ayarlara ve çalışma sayfalarına dokunmaz; uygulama sonra yine en yeni sürümü önerir.

İlk deneme sürümü (paketlenmeden önce `C:\AccuNest` içinde çalışan hali) `arsiv` dalında duruyor.
