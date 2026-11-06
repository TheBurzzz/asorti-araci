# Eleman kabuğu: Asorti Aracı'nın sekmeli penceresini (AsortiAraci/uygulama.html) Eleman'a çevirir.
#
#   python3 kaynak/eleman/kabuk_yap.py <asorti uygulama.html> <çıktı>
#
# Asorti'nin kendi kodu (sekmeler, Gerber, güncelleme, görünüm) olduğu gibi kalır; üstüne eklenenler:
#   - Eleman simgesi ve adı, uygulama düğmeleri (Asorti Aracı · Ölçü Tablosu), Apple tarzı ana sayfa
#   - Ölçü Tablosu için Asorti'ninkiyle aynı tarzda sekmeler (ayrı kap: #sayfalarO, ayrı kayıt: eleman-olcu-sayfalar)
#   - ⚙ menüsünde açık uygulamaya göre bölümler (görünüm hepsinde ortak)
#   - renk: Eleman sarı, Asorti mavi (aynen), Ölçü yeşil
# main'deki uygulama.html değişirse (Asorti düzeltmesi) bu betik onun üstüne yeniden çalıştırılır.
import re, sys

src, out = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()


def r(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (a[:90], c)
    s = s.replace(a, b)


SQ = re.search(r'<path id="lgS" d="([^"]+)"', s).group(1)

# ---------- başlık, simge ----------
r("try{if(window.asortiPencere&&asortiPencere.baslik)document.documentElement.classList.add('pencere')}catch(e){}",
  "document.documentElement.dataset.uyg='ana';try{if(window.asortiPencere&&asortiPencere.baslik)document.documentElement.classList.add('pencere')}catch(e){}")
r("<title>Asorti Aracı</title>", "<title>Eleman</title>")
r('href="sistem/asorti.png?v=2"', 'href="sistem/eleman.png?v=1"', 2)
r('href="sistem/asorti.ico?v=2"', 'href="sistem/eleman.ico?v=1"')

# ---------- simgeler (bir kez tanımlanır, her yerde <use> ile) ----------
SPRITE = f'''<svg id="ikonlar" width="0" height="0" style="position:absolute" aria-hidden="true"><defs>
 <linearGradient id="lgA" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5AACFF"/><stop offset="1" stop-color="#0068DA"/></linearGradient>
 <radialGradient id="lgH" cx=".5" cy="0" r=".95"><stop offset="0" stop-color="#fff" stop-opacity=".26"/><stop offset=".6" stop-color="#fff" stop-opacity="0"/></radialGradient>
 <path id="lgS" d="{SQ}"/><clipPath id="elC"><use href="#lgS"/></clipPath>
 <linearGradient id="elG" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFE36E"/><stop offset="1" stop-color="#FFC21A"/></linearGradient>
 <linearGradient id="olG" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3CC47C"/><stop offset="1" stop-color="#138A4A"/></linearGradient>
 <symbol id="ikEleman" viewBox="0 0 64 64"><use href="#lgS" fill="url(#elG)"/><use href="#lgS" fill="url(#lgH)"/><g clip-path="url(#elC)" fill="none" stroke="#1D1D1F" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"><path d="M24.6 25.2a7.6 7.6 0 1 0 14.8 0"/><path d="M24 23.6c0-5 3.6-8.6 8-8.6s8 3.6 8 8.6z" fill="#1D1D1F"/><path d="M38.5 23.6h7"/><path d="M14.5 58c0-11 7.8-18 17.5-18s17.5 7 17.5 18"/><path d="M28 40.4l4 5.4 4-5.4"/></g></symbol>
 <symbol id="ikAsorti" viewBox="0 0 64 64"><use href="#lgS" fill="url(#lgA)"/><use href="#lgS" fill="url(#lgH)"/><g fill="none" stroke="#fff" stroke-linecap="round" stroke-linejoin="round"><path d="M13.75 24.75L32 14.75L50.25 24.75L32 34.75Z" fill="#fff" stroke-width="2.5"/><path d="M13.75 31.75L32 41.75L50.25 31.75" stroke-opacity=".82" stroke-width="3.62"/><path d="M13.75 38.75L32 48.75L50.25 38.75" stroke-opacity=".6" stroke-width="3.62"/></g></symbol>
 <symbol id="ikOlcu" viewBox="0 0 64 64"><use href="#lgS" fill="url(#olG)"/><use href="#lgS" fill="url(#lgH)"/><rect x="12.5" y="14.5" width="39" height="35" rx="4.8" fill="#fff"/><path d="M12.5 19.3a4.8 4.8 0 0 1 4.8-4.8h29.4a4.8 4.8 0 0 1 4.8 4.8v4.7h-39z" fill="#1E9E58" fill-opacity=".22"/><path d="M12.5 19.3a4.8 4.8 0 0 1 4.8-4.8h6.9V49.5h-6.9a4.8 4.8 0 0 1-4.8-4.8z" fill="#1E9E58" fill-opacity=".14"/><g stroke="#138A4A" stroke-width="1.9" fill="none"><path d="M12.5 24h39M12.5 32.5h39M12.5 41h39"/><path d="M24.2 14.5v35M37.8 14.5v35"/></g><path d="M28 28.3h6.2M41.5 28.3h6.2M28 36.8h6.2M41.5 36.8h4.4M28 45.3h4.4M41.5 45.3h6.2" stroke="#1D1D1F" stroke-opacity=".55" stroke-width="2" stroke-linecap="round"/></symbol>
</defs></svg>
'''

# ---------- üst çubuk: Eleman + uygulama düğmeleri ----------
i = s.find('<div id="logo"')
j = s.find("</div>", i) + 6
assert i > 0 and s[i:j].count("lgS") >= 1
s = s[:i] + ('<div id="logo" title="Ana sayfa" role="button" tabindex="0"><svg aria-hidden="true"><use href="#ikEleman"/></svg><span><b>Eleman</b></span></div>\n'
             ' <nav id="uyg" aria-label="Uygulamalar">'
             '<button type="button" data-u="asorti" title="Asorti Aracı"><svg aria-hidden="true"><use href="#ikAsorti"/></svg><span>Asorti Aracı</span><i></i></button>'
             '<button type="button" data-u="olcu" title="Ölçü Tablosu Aracı"><svg aria-hidden="true"><use href="#ikOlcu"/></svg><span>Ölçü Tablosu</span><i></i></button></nav>') + s[j:]
r('<body>\n<div id="bar">', '<body>\n' + SPRITE + '<div id="bar">')
r('<div id="tabs" role="tablist"></div>', '<div id="tabs" role="tablist" aria-label="Asorti sayfaları"></div><div id="tabsO" role="tablist" aria-label="Ölçü Tablosu sayfaları"></div>')

r('<div id="durum" title="Gerber köprüsünün durumu">', '<button id="hafiza" type="button" title="Ölçü Tablosu ortak hafızası"><i></i><span>Ortak hafıza</span></button>\n  <div id="durum" title="Gerber köprüsünün durumu">')
# ---------- ⚙ menüsü: açık uygulamaya göre bölümler ----------
r('  <h4>Excel kayıt klasörü</h4>', '  <div class="mAsorti">\n  <h4>Excel kayıt klasörü</h4>')
r('<div id="gbNot"></div></div>\n  <div class="alt">',
  '<div id="gbNot"></div></div>\n  </div>\n'
  '  <div class="mOlcu"><h4>Ölçü Tablosu</h4>\n'
  '  <div class="blok"><div class="not">Müşteriler ve şablonlar, kayıt klasörleri, tarayıcı, ortak hafıza.</div>\n'
  '   <div class="satir dug"><button type="button" id="olAyar">Ölçü Tablosu ayarları…</button></div></div></div>\n'
  '  <div class="alt">')
r('title="Ayarlar: görünüm, gece ışığı, Excel kayıt klasörü, güncelleme"', 'title="Ayarlar: görünüm, gece ışığı, uygulama ayarları, güncelleme"')

# ---------- ana sayfa ve Ölçü sayfalarının kabı ----------
ANA = '''<main id="ana" aria-label="Ana sayfa"><div class="anaIc">
 <div class="anaUst"><svg class="anaIk" aria-hidden="true"><use href="#ikEleman"/></svg><h1 id="anaSelam">Merhaba</h1><p>Hangi işi yapalım?</p></div>
 <div class="kartlar">
  <button type="button" class="kart" data-u="asorti"><svg class="kIk" aria-hidden="true"><use href="#ikAsorti"/></svg>
   <span class="kMetin"><b>Asorti Aracı</b><span>Siparişi yaz, asortiyi hesapla, Excel'e kaydet. Pastalları Gerber'e gönder.</span></span>
   <span class="kDurum" id="dAsorti"></span><span class="kOk" aria-hidden="true"><svg viewBox="0 0 12 20"><path d="M2 2l8 8-8 8"/></svg></span></button>
  <button type="button" class="kart" data-u="olcu"><svg class="kIk" aria-hidden="true"><use href="#ikOlcu"/></svg>
   <span class="kMetin"><b>Ölçü Tablosu Aracı</b><span>Müşteri kağıdını tara, ölçü tablosunu kontrol et, Excel'e kaydet ve yazdır.</span></span>
   <span class="kDurum" id="dOlcu"></span><span class="kOk" aria-hidden="true"><svg viewBox="0 0 12 20"><path d="M2 2l8 8-8 8"/></svg></span></button>
 </div>
 <div class="anaAlt">Created by <b>Şamil Yeşil</b><span id="anaSurum"></span></div>
</div></main>
'''
r('<div id="sayfalar"></div>', ANA + '<div id="sayfalar"></div><div id="sayfalarO"></div>')

# ---------- görünüm (CSS) ----------
CSS = '''
/* ================= Eleman ================= */
/* renk: Eleman sarı, Asorti mavi (aynen), Ölçü yeşil. Açık uygulama html[data-uyg] ile seçilir */
html[data-uyg=ana]{--acc:#b57d00;--accs:rgba(245,176,0,.17)}
html[data-theme=dark][data-uyg=ana]{--acc:#ffc93c;--accs:rgba(255,201,60,.18)}
html[data-uyg=olcu]{--acc:#168a49;--accs:rgba(22,138,73,.12)}
html[data-theme=dark][data-uyg=olcu]{--acc:#34c77b;--accs:rgba(52,199,123,.2)}
#logo{cursor:pointer;border-radius:10px;margin-left:-6px;padding:4px 16px 4px 6px;transition:background .18s}
#logo:hover{background:var(--tabh)}
#logo:focus-visible{outline:2px solid var(--acc);outline-offset:1px}
#logo svg{filter:drop-shadow(0 1px 1.5px rgba(150,105,0,.28)) drop-shadow(0 3px 6px rgba(150,105,0,.12))}
#logo b{font-weight:680}
html.pencere #bar #logo{app-region:no-drag;-webkit-app-region:no-drag}
#uyg{display:flex;align-items:center;gap:2px;flex:none;padding:3px;border-radius:12px;background:var(--tabh)}
#uyg button{position:relative;display:flex;align-items:center;gap:7px;height:30px;padding:0 12px 0 6px;border:0;border-radius:9px;background:transparent;color:var(--mut);font-weight:560;letter-spacing:-.005em;cursor:pointer;white-space:nowrap;transition:background .2s,color .2s,box-shadow .2s}
#uyg button svg{width:21px;height:21px;flex:none;filter:drop-shadow(0 1px 1px rgba(0,0,0,.12))}
#uyg button:hover{color:var(--ink)}
#uyg button.on{background:var(--on);color:var(--ink);font-weight:620;box-shadow:var(--sh)}
#uyg button i{position:absolute;top:5px;right:5px;width:6px;height:6px;border-radius:50%;background:transparent}
#uyg button i.is{background:#ff9f0a}
#uyg button.on i{display:none}
@media (max-width:1100px){#uyg button span{display:none}#uyg button{padding:0 6px}}
html[data-uyg=ana] #serit>*{display:none}
html[data-uyg=asorti] #tabsO,html[data-uyg=olcu] #tabs{display:none}
#tabsO{display:flex;align-items:center;gap:4px;overflow-x:auto;scrollbar-width:none;padding:6px 2px;min-width:0;scroll-behavior:smooth}
#tabsO::-webkit-scrollbar{display:none}
/* Gerber durumu yalnız Asorti'de; bağlantı sorunu her yerde görünür */
html:not([data-uyg=asorti]) #durum:not(.bad):not(.bekle){display:none}
#hafiza{display:none;align-items:center;gap:6px;height:28px;padding:0 10px;border:0;border-radius:14px;background:var(--tabh);font-size:12px;color:var(--mut);cursor:pointer}
html[data-uyg=olcu] #hafiza{display:flex}
#hafiza:hover{color:var(--ink)}
#hafiza i{width:7px;height:7px;border-radius:50%;background:var(--mut)}
#hafiza.ok i{background:var(--ok);box-shadow:0 0 0 3px rgba(31,157,85,.18)}
#hafiza.gonder i{background:#ff9f0a;animation:nb 1.2s ease-in-out infinite}
#hafiza.err i{background:#ff9f0a}
#hafiza.yok i{background:var(--bad)}
#menu .mAsorti,#menu .mOlcu{display:none}
html[data-uyg=asorti] #menu .mAsorti,html[data-uyg=olcu] #menu .mOlcu{display:block}
/* katmanlar: ana sayfa, Asorti sayfaları, Ölçü sayfaları. Gizli olan çalışmaya devam eder */
#ana,#sayfalarO{position:absolute;top:54px;left:0;right:0;bottom:0;overflow:hidden}
#sayfalarO iframe{position:absolute;inset:0;width:100%;height:100%;border:0;display:none;background:var(--bg)}
#sayfalarO iframe.on{display:block;z-index:2}
#sayfalarO iframe.yukleniyor{display:block;visibility:hidden;z-index:0}
#ana,#sayfalar,#sayfalarO{transition:opacity .24s cubic-bezier(.2,.8,.2,1)}
html:not([data-uyg=ana]) #ana,html:not([data-uyg=asorti]) #sayfalar,html:not([data-uyg=olcu]) #sayfalarO{visibility:hidden;opacity:0;pointer-events:none}
@media (prefers-reduced-motion:reduce){#ana,#sayfalar,#sayfalarO{transition:none}}
/* ana sayfa (Apple tarzı: büyük başlık, cam kartlar, yumuşak renk lekeleri) */
#ana{overflow-y:auto;background:radial-gradient(48vmax 38vmax at 50% -6%,rgba(255,206,64,.30),transparent 62%),radial-gradient(46vmax 42vmax at 4% 96%,rgba(120,170,255,.24),transparent 62%),radial-gradient(46vmax 42vmax at 98% 92%,rgba(70,200,130,.20),transparent 62%),var(--bg)}
html[data-theme=dark] #ana{background:radial-gradient(48vmax 38vmax at 50% -6%,rgba(255,190,40,.13),transparent 62%),radial-gradient(46vmax 42vmax at 4% 96%,rgba(40,90,220,.20),transparent 62%),radial-gradient(46vmax 42vmax at 98% 92%,rgba(30,140,80,.18),transparent 62%),var(--bg)}
.anaIc{min-height:100%;max-width:920px;margin:0 auto;padding:7vh 28px 22px;display:flex;flex-direction:column}
.anaUst{text-align:center;margin-bottom:34px}
.anaIk{display:block;width:92px;height:92px;margin:0 auto 18px;filter:drop-shadow(0 2px 3px rgba(150,105,0,.25)) drop-shadow(0 12px 26px rgba(150,105,0,.20))}
html[data-theme=dark] .anaIk{filter:drop-shadow(0 2px 4px rgba(0,0,0,.5)) drop-shadow(0 12px 28px rgba(0,0,0,.4))}
.anaUst h1{margin:0;font-size:40px;line-height:1.1;font-weight:700;letter-spacing:-.035em}
.anaUst p{margin:8px 0 0;font-size:17px;color:var(--mut);letter-spacing:-.01em}
.kartlar{display:grid;grid-template-columns:repeat(auto-fit,minmax(330px,1fr));gap:18px}
.kart{position:relative;display:grid;grid-template-columns:auto 1fr auto;grid-template-rows:auto auto;column-gap:16px;row-gap:12px;align-items:center;text-align:left;padding:22px 20px 18px 22px;border:1px solid rgba(255,255,255,.75);border-radius:24px;background:linear-gradient(145deg,rgba(255,255,255,.88),rgba(255,255,255,.66));box-shadow:inset 0 1px 0 rgba(255,255,255,.9),0 10px 30px rgba(40,55,110,.10),0 1px 3px rgba(40,55,110,.07);backdrop-filter:saturate(170%) blur(18px);cursor:pointer;transition:transform .25s cubic-bezier(.2,.8,.2,1),box-shadow .25s}
html[data-theme=dark] .kart{border-color:rgba(255,255,255,.12);background:linear-gradient(145deg,rgba(58,63,86,.78),rgba(36,40,56,.72));box-shadow:inset 0 1px 0 rgba(255,255,255,.12),0 12px 32px rgba(0,0,0,.42)}
.kart:hover{transform:translateY(-3px);box-shadow:inset 0 1px 0 rgba(255,255,255,.9),0 18px 42px rgba(40,55,110,.16),0 2px 6px rgba(40,55,110,.08)}
.kart[data-u=asorti]:hover{box-shadow:inset 0 1px 0 rgba(255,255,255,.9),0 18px 42px rgba(0,104,218,.20),0 2px 6px rgba(0,60,140,.10)}
.kart[data-u=olcu]:hover{box-shadow:inset 0 1px 0 rgba(255,255,255,.9),0 18px 42px rgba(19,138,74,.20),0 2px 6px rgba(10,90,45,.10)}
.kart:active{transform:translateY(-1px) scale(.995)}
.kart:focus-visible{outline:3px solid var(--acc);outline-offset:3px}
.kIk{width:64px;height:64px;grid-row:1;grid-column:1;filter:drop-shadow(0 2px 2px rgba(0,0,0,.10)) drop-shadow(0 8px 14px rgba(0,0,0,.10))}
.kMetin{grid-row:1;grid-column:2;display:flex;flex-direction:column;gap:4px;min-width:0}
.kMetin b{font-size:19px;font-weight:650;letter-spacing:-.02em;color:var(--ink)}
.kMetin span{font-size:13.5px;line-height:1.45;color:var(--mut)}
.kOk{grid-row:1;grid-column:3;display:grid;place-items:center;width:34px;height:34px;border-radius:50%;background:var(--tabh)}
.kOk svg{width:8px;height:14px;fill:none;stroke:var(--mut);stroke-width:2.4;stroke-linecap:round;stroke-linejoin:round}
.kart[data-u=asorti]:hover .kOk{background:#0071e3}.kart[data-u=olcu]:hover .kOk{background:#168a49}
.kart:hover .kOk svg{stroke:#fff}
.kDurum{grid-column:1/-1;display:flex;flex-wrap:wrap;gap:6px;min-height:24px}
.kDurum span{display:inline-flex;align-items:center;gap:6px;height:24px;padding:0 10px;border-radius:12px;background:var(--tabh);font-size:12px;color:var(--mut);font-weight:500}
.kDurum span i{width:7px;height:7px;border-radius:50%;background:var(--mut)}
.kDurum span.ok i{background:var(--ok)}.kDurum span.is i{background:#ff9f0a}.kDurum span.bad{color:var(--bad)}.kDurum span.bad i{background:var(--bad)}
.anaAlt{margin-top:auto;padding-top:40px;text-align:center;font-size:12px;color:var(--mut);letter-spacing:.2px}
.anaAlt b{font-weight:600;color:var(--ink)}
.anaAlt span:not(:empty)::before{content:' · '}
'''
r("</style></head>", CSS + "</style></head>")

# ---------- davranış (JS) ----------
# yerel yedek: Eleman'ın kayıtları da (eleman-...) diske yedeklensin
r("for(const k in d)if(k.startsWith('asorti-')&&", "for(const k in d)if((k.startsWith('asorti-')||k.startsWith('eleman-'))&&")
r("if(k&&k.startsWith('asorti-'))d[k]=localStorage.getItem(k)", "if(k&&(k.startsWith('asorti-')||k.startsWith('eleman-')))d[k]=localStorage.getItem(k)")
# görünüm ve "kaydet" haberi Ölçü sayfalarına da gitsin
r("document.querySelectorAll('#sayfalar iframe').forEach(f=>{try{f.contentDocument.documentElement.dataset.theme=t}catch(e){}temaYolla(f,t)})",
  "document.querySelectorAll('#sayfalar iframe,#sayfalarO iframe').forEach(f=>{try{f.contentDocument.documentElement.dataset.theme=t}catch(e){}temaYolla(f,t)})")
r("function sayfalarKaydetsin(){document.querySelectorAll('#sayfalar iframe').forEach(",
  "function sayfalarKaydetsin(){document.querySelectorAll('#sayfalar iframe,#sayfalarO iframe').forEach(")
# Yeni sayfa: açık uygulamanın sekmesi
r("$('yeni').onclick=yeni;", "$('yeni').onclick=()=>UYG==='olcu'?yeniO():yeni();")
r("$('serit').addEventListener('dblclick',e=>{if(e.target===$('serit')||e.target===$('tabs'))yeni()});",
  "$('serit').addEventListener('dblclick',e=>{if(UYG==='ana')return;if(e.target===$('serit')||e.target===$('tabs')||e.target===$('tabsO'))UYG==='olcu'?yeniO():yeni()});")
r("$('surum').textContent=j.surum?'Asorti Aracı v'+j.surum:'';", "$('surum').textContent=j.surum?'Eleman v'+j.surum:'';$('anaSurum').textContent=j.surum?'v'+j.surum:'';")
r("confirm('Asorti Aracı v'+G.yeni", "confirm('Eleman v'+G.yeni")
r("masaüstündeki Asorti Aracı simgesinden aç", "masaüstündeki Eleman simgesinden aç")
r("durumYaz(j.kopru?'ok':'bad',j.kopru?'Gerber bağlı':'Gerber köprüsü kapalı')}", "durumYaz(j.kopru?'ok':'bad',j.kopru?'Gerber bağlı':'Gerber köprüsü kapalı');GB=j.gerber===false?'yok':j.kopru?'ok':'bad';anaYaz()}")

JS = r'''
/* ================= Eleman: ana sayfa, uygulama düğmeleri, Ölçü Tablosu sekmeleri =================
   Asorti'nin sekmeleri (#tabs, #sayfalar) olduğu gibi çalışır. Ölçü Tablosu'nun sekmeleri ayrı kapta (#tabsO, #sayfalarO),
   ayrı kayıtta (eleman-olcu-sayfalar). İki uygulama birbirinin sayfasına, kaydına, haberine dokunmaz. */
let UYG='ana',GB='';
const LO='eleman-olcu-sayfalar',TO=$('tabsO');
let SO=(()=>{try{return JSON.parse(localStorage.getItem(LO)||'null')}catch(e){return null}})()||{list:[],on:''};
const infoO={};let girisO=null,gosterilenO=null;
function saveO(){try{localStorage.setItem(LO,JSON.stringify(SO))}catch(e){}yerelYedek()}
function frameO(id){let f=document.querySelector('#sayfalarO iframe[data-id="'+id+'"]');
 if(!f){f=document.createElement('iframe');f.dataset.id=id;f.title='Ölçü Tablosu Aracı';f.addEventListener('load',()=>{f.dataset.hazir='1'});
  f.src='olcu_tablosu_araci.html?sayfa='+encodeURIComponent(id);$('sayfalarO').appendChild(f)}
 return f}
function sekmeO(id){let b=TO.querySelector('.tab[data-id="'+id+'"]');
 if(!b){b=document.createElement('div');b.className='tab';b.dataset.id=id;b.setAttribute('role','tab');
  b.innerHTML='<span class="ik"></span><span class="ad"></span><button class="x" type="button" title="Sayfayı kapat" aria-label="Sayfayı kapat">'+xIk+'</button>';
  b.addEventListener('click',e=>{if(b.dataset.kapaniyor)return;if(e.target.closest('.x'))kapatO(id);else acO(id)})}
 return b}
function cizO(){let onceki=null;
 SO.list.forEach((id,i)=>{const b=sekmeO(id),d=infoO[id]||{},yeniMi=!b.isConnected;
  let h=onceki?onceki.nextElementSibling:TO.firstElementChild;while(h&&h.dataset.kapaniyor)h=h.nextElementSibling;
  if(h!==b)TO.insertBefore(b,h);onceki=b;
  const ad=d.ad||'Sayfa '+(i+1),ik='ik'+(d.busy?' is':''),a=b.querySelector('.ad'),k=b.querySelector('.ik');
  b.classList.toggle('on',id===SO.on);b.setAttribute('aria-selected',String(id===SO.on));
  if(a.textContent!==ad){a.textContent=ad;a.dataset.t=ad}if(k.className!==ik)k.className=ik;
  b.title=ad+(d.degisti?' · kaydedilmedi':'');
  if(yeniMi&&girisO===id){girisO=null;if(!AZ.matches)sekmeOyna(b,true,()=>{if(b.classList.contains('on'))b.scrollIntoView({block:'nearest',inline:'nearest'})})}});
 [...TO.children].forEach(b=>{if(!b.dataset.kapaniyor&&!SO.list.includes(b.dataset.id))sekmeCik(b)});
 if(UYG==='olcu'||SO.on&&document.querySelector('#sayfalarO iframe[data-id="'+SO.on+'"]'))sayfaGosterO(SO.on);
 anaYaz()}
function sayfaGosterO(id){if(!id)return;const f=frameO(id);if(gosterilenO===f)return;gosterilenO=f;
 const degis=()=>{if(gosterilenO!==f)return;
  document.querySelectorAll('#sayfalarO iframe').forEach(x=>{if(x!==f&&!x.classList.contains('yukleniyor'))sayfaKaldir(x)});
  f.classList.remove('yukleniyor');f.classList.add('on')};
 if(f.dataset.hazir)return degis();
 f.classList.add('yukleniyor');let t=0;
 const hazir=()=>{clearTimeout(t);f.removeEventListener('load',hazir);if(gosterilenO===f)degis();else f.classList.remove('yukleniyor')};
 f.addEventListener('load',hazir);t=setTimeout(hazir,1500)}
function acO(id){SO.on=id;saveO();cizO()}
function yeniO(){const id=yeniId();SO.list.push(id);girisO=id;acO(id)}
/* kapanan sekmenin kaydedilmemiş tablosu da silinir (Ölçü'nün bu bilgisayardaki deposu: taslak-<sekme>) */
function olcuTaslakSil(id){try{const q=indexedDB.open('olcu-tablosu-araci',1);q.onupgradeneeded=()=>q.result.createObjectStore('kv');
 q.onsuccess=()=>{try{q.result.transaction('kv','readwrite').objectStore('kv').delete('taslak-'+id)}catch(e){}}}catch(e){}}
function kapatO(id){const i=SO.list.indexOf(id);if(i<0)return;const d=infoO[id]||{},f=document.querySelector('#sayfalarO iframe[data-id="'+id+'"]');
 if(d.busy){alert((d.ad||'Bu sayfa')+' şu an kağıt okuyor ya da kaydediyor. Bitince kapat.');return}
 if(d.degisti&&!confirm((d.ad?d.ad+' tablosu':'Bu sayfa')+' kapatılsın mı?\nKaydedilmemiş tablo silinir (Excel\'e kaydettiklerin durur).'))return;
 SO.list.splice(i,1);delete infoO[id];olcuTaslakSil(id);
 if(f)f.dataset.sil='1';
 if(!SO.list.length){const n=yeniId();SO.list.push(n);girisO=n;SO.on=n}else if(SO.on===id)SO.on=SO.list[Math.max(0,i-1)];
 saveO();cizO();if(f&&f!==gosterilenO&&!f.classList.contains('on'))f.remove()}
TO.addEventListener('wheel',e=>{if(Math.abs(e.deltaY)>Math.abs(e.deltaX)){TO.scrollLeft+=e.deltaY;e.preventDefault()}},{passive:false});
/* Ölçü sayfalarından gelen haberler: sekme başlığı, bildirim */
window.addEventListener('message',e=>{const d=e.data||{};if(d.uygulama!=='olcu'&&d.tur!=='olcu')return;
 if(d.t==='sayfa'&&SO.list.includes(d.id)){const o=infoO[d.id]||{};if(o.ad!==d.ad||o.busy!==d.busy||o.degisti!==d.degisti){infoO[d.id]={ad:d.ad,busy:!!d.busy,degisti:!!d.degisti};cizO()}}
 if(d.t==='bildirim'&&SO.list.includes(d.id))bildirim({tur:'excel',baslik:d.baslik||'Excel\'e kaydedildi',metin:d.metin||d.ad||'',
  ipucu:UYG!=='olcu'||d.id!==SO.on?'Tabloya gitmek için tıkla':'',tik:()=>{uygGit('olcu');acO(d.id)}})});
/* Ölçü'nün ortak hafıza durumu: hangi sekmeden gelirse gelsin aynı hafıza; tıklayınca açık sekmede ayarların o bölümü */
window.addEventListener('message',e=>{const d=e.data||{};if(d.t!=='hafiza'||d.uygulama!=='olcu')return;const h=$('hafiza');
 h.className=['ok','gonder','err','yok'].includes(d.durum)?d.durum:'';h.querySelector('span').textContent=d.yazi||'Ortak hafıza';h.title=d.ipucu||'Ortak hafıza'});
$('hafiza').onclick=e=>{e.stopPropagation();const f=document.querySelector('#sayfalarO iframe.on');if(f)try{f.contentWindow.postMessage({t:'ayarlar',bolum:'hafiza'},'*')}catch(x){}};
/* ana sayfa ve uygulama düğmeleri */
function selam(){const h=new Date().getHours();return h>=5&&h<11?'Günaydın':h>=11&&h<17?'İyi günler':h>=17&&h<22?'İyi akşamlar':'İyi geceler'}
function cip(c,t){return '<span class="'+c+'"><i></i>'+t+'</span>'}
function anaYaz(){if(!$('dAsorti'))return;
 const n=S.list.length,is=Object.values(info).filter(d=>d.busy).length,no=SO.list.length,dg=Object.values(infoO).filter(d=>d.degisti).length;
 $('dAsorti').innerHTML=cip('',n+' sayfa açık')+(is?cip('is',is+' Gerber işi sürüyor'):'')+(GB==='ok'?cip('ok','Gerber bağlı'):GB==='bad'?cip('bad','Gerber köprüsü kapalı'):'');
 $('dOlcu').innerHTML=(no?cip('',no+' sayfa açık'):cip('','Henüz açılmadı'))+(dg?cip('is',dg+' kaydedilmemiş tablo'):'');
 document.querySelector('#uyg [data-u=asorti] i').className=is?'is':'';
 document.querySelector('#uyg [data-u=olcu] i').className=dg?'is':''}
function uygGit(u,ilk){if(!['ana','asorti','olcu'].includes(u))u='ana';const once=UYG;UYG=u;
 document.documentElement.dataset.uyg=u;
 document.querySelectorAll('#uyg button').forEach(b=>{const on=b.dataset.u===u;b.classList.toggle('on',on);b.setAttribute('aria-pressed',String(on))});
 if(u==='ana')$('anaSelam').textContent=selam();
 if(u==='olcu'){if(!SO.list.length){const id=yeniId();SO.list.push(id);SO.on=id;saveO()}if(!SO.list.includes(SO.on))SO.on=SO.list[0];cizO();sayfaGosterO(SO.on)}
 if(u==='asorti'&&once!=='asorti'){const f=document.querySelector('#sayfalar iframe.on');try{if(f&&f.contentWindow.sayfaBelir)f.contentWindow.sayfaBelir()}catch(e){}}
 try{localStorage.setItem('eleman-son',u)}catch(e){}
 menu(false);anaYaz()}
$('logo').onclick=()=>uygGit('ana');
$('logo').onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();uygGit('ana')}};
document.querySelectorAll('#uyg button,.kart').forEach(b=>b.onclick=()=>uygGit(b.dataset.u));
$('olAyar').onclick=e=>{e.stopPropagation();menu(false);const f=document.querySelector('#sayfalarO iframe.on');if(f)try{f.contentWindow.postMessage({t:'ayarlar'},'*')}catch(x){}};
setInterval(()=>{if(UYG==='ana')$('anaSelam').textContent=selam()},60000);
uygGit('ana',true);
'''
r("/* açılışta önce görünen sayfa yüklenir, diğerleri hemen ardından", JS + "/* açılışta önce görünen sayfa yüklenir, diğerleri hemen ardından")
# Asorti sekmeleri değişince ana sayfa sayıları da
r("function ciz(){let onceki=null;", "function ciz(){setTimeout(()=>{try{anaYaz()}catch(e){}},0);let onceki=null;")
# açılış ekranı: Eleman ana sayfayla açılır, ekran çizilince kaybolur
r("(()=>{const f=document.querySelector('#sayfalar iframe[data-id=\"'+S.on+'\"]');let gitti=false;",
  "(()=>{const f=UYG==='ana'?null:document.querySelector('#sayfalar iframe[data-id=\"'+S.on+'\"]');let gitti=false;")
r(" if(!f)return bildir();", " if(!f)return Promise.race([document.fonts.ready,new Promise(r=>setTimeout(r,800))]).then(()=>setTimeout(bildir,40),bildir);")
open(out, "w", encoding="utf-8", newline="\n").write(s)
print("Eleman kabuğu:", out, len(s))
