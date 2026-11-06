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

## Son durum

- 2026-11-06 (Eleman sohbeti): `eleman` dalı açıldı (main = v2.0.4'ten). İş bilgisayarındaki dosyalar Eleman sohbetinin
  çalışma alanına alındı (`/home/claude/eleman-arsiv`). Simgeler, açılış ekranı, pencere adı "Eleman", Ölçü sunucu bölümü eklendi.
  C# kaynakları Linux'ta mono ile C# 5 sınırında derleniyor.

## Sıradaki işler

1. Eleman kabuğu (`uygulama.html`): ana sayfa, uygulama düğmeleri, Ölçü için sekmeler, ⚙ menüsünde uygulamaya göre bölümler.
2. Ölçü Tablosu: yeşil tema, Eleman içinde kendi başlığını/tema düğmesini gizleme, sekme başına ayrı taslak.
3. Müşteri şablonları: gizli `eleman-hafiza` deposundan (`olcu-tablosu/sablonlar/`) gelsin; `/olcu/sablonlar` yerel önbellekten.
4. Kısayol adı "Eleman" ve masaüstü simgesi; kurulum sihirbazı (Kurulum.ps1) Eleman adıyla.
5. Sürüm 3.0.0, iş bilgisayarında deneme, sonra main'e.
6. El yazısı okuma modeli.
