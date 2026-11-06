# Ölçü Tablosu Aracı: kaynaktan tek dosyalık programı üretir.
#
#   python kaynak/olcu/derle.py
#       -> AsortiAraci/olcu_tablosu_araci.html  (Eleman içindeki hali: anahtarsız, müşteri şablonları gömülü değil;
#          şablonlar Eleman'da gizli ortak hafızadan / kurulumdaki yerel dosyadan gelir)
#
#   python kaynak/olcu/derle.py --sablonlar <gizli/sablonlar.json> --anahtar <github_pat_...> --cikti <yol>
#       -> tarayıcıda tek başına çalışan hali (şablonlar ve anahtar içinde). BU DOSYA GITHUB'A KONMAZ.
#
# Kurallar: anahtar (github_pat_...) ve müşteri şablonları (sablonlar.json) herkese açık bu depoya asla girmez.
import base64, os, sys

D = os.path.dirname(os.path.abspath(__file__))
KOK = os.path.normpath(os.path.join(D, "..", ".."))
SISTEM = os.path.join(KOK, "AsortiAraci", "sistem")


def arg(ad, varsayilan=None):
    if ad in sys.argv:
        return sys.argv[sys.argv.index(ad) + 1].strip()
    return varsayilan


v = lambda f: open(os.path.join(D, "veri", f), encoding="utf-8").read()
b64 = lambda p: base64.b64encode(open(p, "rb").read()).decode()

s = open(os.path.join(D, "src.html"), encoding="utf-8").read()
s = s.replace("/*__DICT__*/null", v("dict.json")).replace("/*__TYP__*/null", v("tipik_olculer.json"))
s = s.replace("/*__GLOSS__*/null", v("sozluk.json"))
s = s.replace("/*__INTER1__*/", b64(os.path.join(SISTEM, "inter-latin.woff2")))
s = s.replace("/*__INTER2__*/", b64(os.path.join(SISTEM, "inter-latin-ext.woff2")))
sab = arg("--sablonlar")
if sab:
    s = s.replace("/*__TPLS__*/null", open(sab, encoding="utf-8").read())
for k in ["/*__DICT__*/", "/*__TYP__*/", "/*__GLOSS__*/", "/*__INTER1__*/", "/*__INTER2__*/"]:
    assert k not in s, k
assert s.count("/*__TOKEN__*/") == 1
anahtar = arg("--anahtar")
if anahtar:
    s = s.replace("/*__TOKEN__*/", anahtar)
cikti = arg("--cikti", os.path.join(KOK, "AsortiAraci", "olcu_tablosu_araci.html"))
if (anahtar or sab) and os.path.normpath(os.path.dirname(os.path.abspath(cikti))).startswith(KOK):
    sys.exit("Anahtarlı ya da şablonlu hali depo klasörüne yazılmaz (herkese açık). --cikti ile depo dışına ver.")
open(cikti, "w", encoding="utf-8", newline="\n").write(s)
print(cikti, len(s))
