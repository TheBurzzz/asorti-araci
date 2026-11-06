# Eleman kabuğu: Asorti Aracı'nın sekmeli penceresini (AsortiAraci/uygulama.html) Eleman'a çevirir.
#
#   python3 kaynak/eleman/kabuk_yap.py <asorti uygulama.html> <çıktı>
#
# Asorti'nin kendi kodu (sekmeler, Gerber, güncelleme, görünüm) olduğu gibi kalır; üstüne eklenenler:
#   - sol üstte Eleman simgesi: basınca Ana sayfa / Asorti Aracı / Ölçü Tablosu menüsü
#   - Apple tarzı ana sayfa; açılışta Eleman simgesi küçülüp büyüyerek uygulamayı açar (X / Twitter'ın iOS açılışı gibi)
#   - Ölçü Tablosu için Asorti'ninkiyle aynı tarzda sekmeler (ayrı kap: #sayfalarO, ayrı kayıt: eleman-olcu-sayfalar)
#   - sayfa kendiliğinden açılmaz; açık sayfa yokken düzgün bir boş ekran
#   - çok sayfada hız: sayfalar ilk açılınca yüklenir, uzun süredir bakılmayanlar uyutulur (kaydedilip kapatılır,
#     dönünce kaldığı yerden açılır); Gerber işi ya da okuma süren sayfa hiç uyutulmaz
#   - ⚙ menüsünde açık uygulamaya göre bölümler (görünüm hepsinde ortak); sürüm yalnız ⚙ menüsünde
#   - renk: Eleman sarı, Asorti mavi (aynen), Ölçü yeşil
# main'deki uygulama.html değişirse (Asorti düzeltmesi) bu betik onun üstüne yeniden çalıştırılır.
import os, re, sys

src, out = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
SISTEM = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "AsortiAraci", "sistem")


def r(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (a[:90], c)
    s = s.replace(a, b)


SQ = re.search(r'<path id="lgS" d="([^"]+)"', s).group(1)
ELEMAN_SVG = open(os.path.join(SISTEM, "eleman.svg"), encoding="utf-8").read().strip()

# ---------- başlık, simge ----------
r("try{if(window.asortiPencere&&asortiPencere.baslik)document.documentElement.classList.add('pencere')}catch(e){}",
  "document.documentElement.dataset.uyg='ana';try{if(sessionStorage.getItem('eleman-acildi'))document.documentElement.classList.add('acildi')}catch(e){}"
  "try{if(window.asortiPencere&&asortiPencere.baslik)document.documentElement.classList.add('pencere')}catch(e){}")
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

ANA_CSS = r'''/* ana sayfa (Apple tarzı: büyük başlık, cam kartlar, yumuşak renk lekeleri) */
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
.anaAlt span:not(:empty)::before{content:' · '}'''

# ---------- açılış katmanı (sayfanın ilk karesinden itibaren görünür; yerel açılış ekranıyla birebir aynı) ----------
ACILIS_HTML = '<div id="acilis" aria-hidden="true"><svg class="aIk"><use href="#ikEleman"/></svg><canvas></canvas></div>\n'

JS = r'''
/* ================= Eleman: ana sayfa, menü, Ölçü Tablosu sekmeleri, açılış =================
   Asorti'nin sekmeleri (#tabs, #sayfalar) olduğu gibi çalışır. Ölçü Tablosu'nun sekmeleri ayrı kapta (#tabsO, #sayfalarO),
   ayrı kayıtta (eleman-olcu-sayfalar). İki uygulama birbirinin sayfasına, kaydına, haberine dokunmaz. */
let UYG='ana',GB='';

/* ---------- çok sayfada hız: sayfalar ilk açılınca yüklenir; uzun süredir bakılmayanlar uyutulur ----------
   Uyuyan sayfa kaydedilip kapatılır (sekmesi yerinde kalır), tıklanınca kaldığı yerden açılır.
   Gerber işi süren ya da kağıt okuyan sayfa hiç uyutulmaz. */
const CANLI_A=4,CANLI_O=3,sonA={},sonO={};
function kaliciA(id){const d=info[id]||{};S.ad=S.ad||{};S.ms=S.ms||{};const ms=!!d.busy;
 if(S.ad[id]!==(d.ad||'')||!!S.ms[id]!==ms){S.ad[id]=d.ad||'';if(ms)S.ms[id]=1;else delete S.ms[id];save()}}
function mesgulA(id){if((info[id]||{}).busy||(S.ms&&S.ms[id]))return true;
 try{const j=JSON.parse(localStorage.getItem('asorti-gjob-'+id)||'null');return !!(j&&Date.now()-j.t<6*3600e3&&j.st&&!['bitti','hata','iptal'].includes(j.st.asama))}catch(e){return false}}
function uyutA(){const fs=[...document.querySelectorAll('#sayfalar iframe')].filter(f=>!f.dataset.sil);let fazla=fs.length-CANLI_A;if(fazla<=0)return;
 /* yalnız kaybolacak bir şeyi olmayan sayfa uyur: boş sayfa ya da son hali kaydedilmiş sayfa (tablosu hazırlanmış).
    Sipariş formu yazılıp henüz tablo hazırlanmamış sayfa uyutulmaz (o hal kaydedilmiyor) */
 const uyuyabilir=f=>{try{const w=f.contentWindow;if(w.sayfaKaydet)w.sayfaKaydet();return !!((w.sayfaBos&&w.sayfaBos())||localStorage.getItem('asorti-sayfa-'+f.dataset.id))}catch(e){return false}};
 fs.filter(f=>f!==gosterilen&&!f.classList.contains('yukleniyor')&&!mesgulA(f.dataset.id)).sort((a,b)=>(sonA[a.dataset.id]||0)-(sonA[b.dataset.id]||0))
  .forEach(f=>{if(fazla<=0||!uyuyabilir(f))return;f.remove();fazla--})}
function bosGoster(k){if(k==='A'){gosterilen=null;document.querySelectorAll('#sayfalar iframe').forEach(x=>{x.classList.remove('on');if(x.dataset.sil)x.remove()});$('bosA').hidden=false}
 else{gosterilenO=null;document.querySelectorAll('#sayfalarO iframe').forEach(x=>{x.classList.remove('on');if(x.dataset.sil)x.remove()});$('bosO').hidden=false}}
$('bosYeniA').onclick=()=>yeni();
$('bosYeniO').onclick=()=>yeniO();

/* ---------- Ölçü Tablosu sekmeleri ---------- */
const LO='eleman-olcu-sayfalar',TO=$('tabsO');
let SO=(()=>{try{return JSON.parse(localStorage.getItem(LO)||'null')}catch(e){return null}})()||{list:[],on:''};
SO.ad=SO.ad||{};
const infoO={};for(const id of SO.list)if(SO.ad[id])infoO[id]={ad:SO.ad[id]};
let girisO=null,gosterilenO=null;
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
 if(UYG==='olcu'){if(SO.on)sayfaGosterO(SO.on);else bosGoster('O')}
 anaYaz()}
function sayfaGosterO(id){if(!id)return;$('bosO').hidden=true;const f=frameO(id);sonO[id]=Date.now();if(gosterilenO===f)return;gosterilenO=f;
 const degis=()=>{if(gosterilenO!==f)return;
  document.querySelectorAll('#sayfalarO iframe').forEach(x=>{if(x!==f&&!x.classList.contains('yukleniyor'))sayfaKaldir(x)});
  f.classList.remove('yukleniyor');f.classList.add('on');setTimeout(uyutO,400)};
 if(f.dataset.hazir)return degis();
 f.classList.add('yukleniyor');let t=0;
 const hazir=()=>{clearTimeout(t);f.removeEventListener('load',hazir);if(gosterilenO===f)degis();else f.classList.remove('yukleniyor')};
 f.addEventListener('load',hazir);t=setTimeout(hazir,1500)}
function uyutO(){const fs=[...document.querySelectorAll('#sayfalarO iframe')].filter(f=>!f.dataset.sil&&!f.dataset.uyuyor);let fazla=fs.length-CANLI_O;if(fazla<=0)return;
 fs.filter(f=>f!==gosterilenO&&!f.classList.contains('yukleniyor')&&!(infoO[f.dataset.id]||{}).busy).sort((a,b)=>(sonO[a.dataset.id]||0)-(sonO[b.dataset.id]||0))
  .forEach(f=>{if(fazla<=0)return;fazla--;f.dataset.uyuyor='1';let p=null;try{p=f.contentWindow.taslakYaz&&f.contentWindow.taslakYaz(true)}catch(e){}
   Promise.race([Promise.resolve(p),new Promise(r=>setTimeout(r,1500))]).catch(()=>{}).then(()=>{if(f!==gosterilenO)f.remove();else delete f.dataset.uyuyor})})}
function acO(id){SO.on=id;saveO();cizO()}
function yeniO(){const id=yeniId();SO.list.push(id);girisO=id;acO(id)}
/* kapanan sekmenin bu bilgisayardaki tablosu da silinir (Ölçü'nün deposu: taslak-<sekme>) */
function olcuTaslakSil(id){try{const q=indexedDB.open('olcu-tablosu-araci',1);q.onupgradeneeded=()=>q.result.createObjectStore('kv');
 q.onsuccess=()=>{try{q.result.transaction('kv','readwrite').objectStore('kv').delete('taslak-'+id)}catch(e){}}}catch(e){}}
function kapatO(id){const i=SO.list.indexOf(id);if(i<0)return;const d=infoO[id]||{},f=document.querySelector('#sayfalarO iframe[data-id="'+id+'"]');
 if(d.busy){alert((d.ad||'Bu sayfa')+' şu an kağıt okuyor ya da kaydediyor. Bitince kapat.');return}
 if(d.degisti&&!confirm((d.ad?d.ad+' tablosu':'Bu sayfa')+' kapatılsın mı?\nKaydedilmemiş tablo silinir (Excel\'e kaydettiklerin durur).'))return;
 SO.list.splice(i,1);delete infoO[id];delete SO.ad[id];olcuTaslakSil(id);
 if(f)f.dataset.sil='1';
 if(!SO.list.length)SO.on='';else if(SO.on===id)SO.on=SO.list[Math.max(0,i-1)];
 saveO();cizO();if(f&&f!==gosterilenO&&!f.classList.contains('on'))f.remove()}
TO.addEventListener('wheel',e=>{if(Math.abs(e.deltaY)>Math.abs(e.deltaX)){TO.scrollLeft+=e.deltaY;e.preventDefault()}},{passive:false});
/* Ölçü sayfalarından gelen haberler: sekme başlığı, bildirim, ortak hafıza durumu */
window.addEventListener('message',e=>{const d=e.data||{};if(d.uygulama!=='olcu'&&d.tur!=='olcu')return;
 if(d.t==='sayfa'&&SO.list.includes(d.id)){const o=infoO[d.id]||{};if(o.ad!==d.ad||o.busy!==d.busy||o.degisti!==d.degisti){infoO[d.id]={ad:d.ad,busy:!!d.busy,degisti:!!d.degisti};
   if((SO.ad[d.id]||'')!==(d.ad||'')){SO.ad[d.id]=d.ad||'';saveO()}cizO()}}
 if(d.t==='bildirim'&&SO.list.includes(d.id))bildirim({tur:'excel',baslik:d.baslik||'Excel\'e kaydedildi',metin:d.metin||d.ad||'',
  ipucu:UYG!=='olcu'||d.id!==SO.on?'Tabloya gitmek için tıkla':'',tik:()=>{uygGit('olcu');acO(d.id)}});
 if(d.t==='hafiza'){const h=$('hafiza');h.className=['ok','gonder','err','yok'].includes(d.durum)?d.durum:'';h.querySelector('span').textContent=d.yazi||'Ortak hafıza';h.title=d.ipucu||'Ortak hafıza'}});
$('hafiza').onclick=e=>{e.stopPropagation();const f=document.querySelector('#sayfalarO iframe.on');if(f)try{f.contentWindow.postMessage({t:'ayarlar',bolum:'hafiza'},'*')}catch(x){}};

/* ---------- ana sayfa, sol üstteki menü, uygulamalar arası geçiş ---------- */
function selam(){const h=new Date().getHours();return h>=5&&h<11?'Günaydın':h>=11&&h<17?'İyi günler':h>=17&&h<22?'İyi akşamlar':'İyi geceler'}
function cip(c,t){return '<span class="'+c+'"><i></i>'+t+'</span>'}
function anaYaz(){if(!$('dAsorti'))return;
 const n=S.list.length,is=Object.values(info).filter(d=>d.busy).length,no=SO.list.length,dg=Object.values(infoO).filter(d=>d.degisti).length;
 const sA=n?n+' sayfa açık':'Açık sayfa yok',sO=no?no+' sayfa açık':'Açık sayfa yok';
 $('dAsorti').innerHTML=cip('',sA)+(is?cip('is',is+' Gerber işi sürüyor'):'')+(GB==='ok'?cip('ok','Gerber bağlı'):GB==='bad'?cip('bad','Gerber köprüsü kapalı'):'');
 $('dOlcu').innerHTML=cip('',sO)+(dg?cip('is',dg+' kaydedilmemiş tablo'):'');
 $('mDA').textContent=sA+(is?' · '+is+' Gerber işi sürüyor':'');
 $('mDO').textContent=sO+(dg?' · '+dg+' kaydedilmemiş':'')}
function uMenu(ac){const m=$('uMenu'),b=$('logo');if(ac===undefined)ac=!m.classList.contains('on');
 m.classList.toggle('on',ac);b.setAttribute('aria-expanded',String(ac));
 if(ac){menu(false);anaYaz();m.querySelectorAll('button[data-u]').forEach(x=>x.classList.toggle('on',x.dataset.u===UYG))}}
function uygGit(u){if(!['ana','asorti','olcu'].includes(u))u='ana';const once=UYG;UYG=u;
 document.documentElement.dataset.uyg=u;
 $('lUyg').textContent=u==='asorti'?'Asorti Aracı':u==='olcu'?'Ölçü Tablosu':'';
 if(u==='ana')$('anaSelam').textContent=selam();
 if(u==='olcu'){if(SO.on&&!SO.list.includes(SO.on))SO.on=SO.list[0]||'';cizO()}
 if(u==='asorti'){if(!S.list.length)bosGoster('A');else if(once!=='asorti'){const f=document.querySelector('#sayfalar iframe.on');try{if(f&&f.contentWindow.sayfaBelir)f.contentWindow.sayfaBelir()}catch(e){}}}
 try{localStorage.setItem('eleman-son',u)}catch(e){}
 uMenu(false);menu(false);anaYaz()}
$('logo').onclick=e=>{e.stopPropagation();uMenu()};
$('uMenu').querySelectorAll('button[data-u]').forEach(b=>b.onclick=e=>{e.stopPropagation();uygGit(b.dataset.u)});
document.querySelectorAll('.kart').forEach(b=>b.onclick=()=>uygGit(b.dataset.u));
document.addEventListener('click',e=>{if(!e.target.closest('#uMenu'))uMenu(false)});
document.addEventListener('keydown',e=>{if(e.key==='Escape')uMenu(false)});
window.addEventListener('blur',()=>uMenu(false));
$('ayar').addEventListener('click',()=>uMenu(false));
$('olAyar').onclick=e=>{e.stopPropagation();menu(false);const f=document.querySelector('#sayfalarO iframe.on');if(f)try{f.contentWindow.postMessage({t:'ayarlar'},'*')}catch(x){}};
setInterval(()=>{if(UYG==='ana')$('anaSelam').textContent=selam()},60000);
uygGit('ana');

/* ---------- açılış: Eleman simgesinin içine dalış (X / Twitter'ın iOS açılışı gibi, daha güçlü) ----------
   Yerel açılış ekranı (pencerenin kendisi) ve bu katman aynı görüntü: düz zemin, ortada 104 px simge. Yerel ekran kalkınca
   (Eleman haber verir): simge geri çekilir, sonra hızlanarak üstümüze gelir; adamın yüzünün içine girilir, sarı ekranı
   kaplar ve dağılırken uygulama ekrana "çarpar" (büyükten gelir, bir tık küçülüp oturur). Simge vektör çizilir: dev boyda da net. */
const KARE=__KARE__,ADAM=__ADAM__;
let acilisKalkti=false,acilisBasladi=false,acilisBekliyor=false;
if(PW)PW.addEventListener('message',e=>{if((e.data||{}).t==='acilis'){acilisKalkti=true;if(acilisBekliyor)requestAnimationFrame(acilisOyna)}});
function acilisBekle(){const ov=$('acilis');if(!ov||document.documentElement.classList.contains('acildi'))return;
 if(!PW||acilisKalkti){setTimeout(acilisOyna,PW?0:350);return}
 acilisBekliyor=true;setTimeout(acilisOyna,1600)}   // Eleman haber vermezse de en geç 1,6 sn sonra
function acilisOyna(){const ov=$('acilis');if(!ov||acilisBasladi)return;acilisBasladi=true;
 try{sessionStorage.setItem('eleman-acildi','1')}catch(e){}
 const bitir=()=>{ov.remove();document.documentElement.classList.add('acildi')};
 if(AZ.matches){const a=ov.animate([{opacity:1},{opacity:0}],{duration:260,easing:'ease-out',fill:'forwards'});a.onfinish=bitir;return}
 const cv=ov.querySelector('canvas'),ik=ov.querySelector('.aIk'),h=document.documentElement,cs=getComputedStyle(h);
 const dpr=window.devicePixelRatio||1,W=innerWidth,H=innerHeight,S0=104,cx=W/2,cy=H/2;
 cv.width=Math.round(W*dpr);cv.height=Math.round(H*dpr);cv.style.width=W+'px';cv.style.height=H+'px';
 const g=cv.getContext('2d'),bg=cs.getPropertyValue('--bg').trim()||'#eef0f6',ink=cs.getPropertyValue('--ink').trim()||'#1d1d1f';
 const kare=new Path2D(KARE),adam=ADAM.map(a=>({p:new Path2D(a.d),dolu:a.dolu})),pencere=h.classList.contains('pencere'),tam=h.classList.contains('tam');
 const T1=300,T2=640,FX=32,FY=28.6;   // FX,FY: adamın yüzünün ortası (simge birimi, 64'lük): içine buradan girilir
 const dk=Math.max(W/12,H/7.6)*64/S0*1.1,LK=Math.log(dk/.82)/Math.pow(.74,1.5);   // yüzün içi ekranı p≈0,74'te kaplasın
 const io=t=>t<.5?4*t*t*t:1-Math.pow(-2*t+2,3)/2;
 const yumu=(a,b,x)=>{const t=Math.min(1,Math.max(0,(x-a)/(b-a)));return t*t*(3-2*t)};
 const cizgi=(x0,y0,x1,y1)=>{g.beginPath();g.moveTo(x0,y0);g.lineTo(x1,y1);g.stroke()};
 const dugmeler=()=>{if(!pencere)return;g.save();g.strokeStyle=ink;g.lineWidth=1;g.globalAlpha=.92;
  const y=Math.round(27-5)+.5,x3=Math.round(W-46+18)+.5,x2=Math.round(W-92+18)+.5,x1=Math.round(W-138+18)+.5;
  cizgi(x1,y+5,x1+10,y+5);
  if(tam){g.strokeRect(x2,y+2,7,7);cizgi(x2+2,y+2,x2+2,y);cizgi(x2+2,y,x2+9,y);cizgi(x2+9,y,x2+9,y+7);cizgi(x2+9,y+7,x2+7,y+7)}else g.strokeRect(x2,y,9,9);
  cizgi(x3,y,x3+9,y+9);cizgi(x3+9,y,x3,y+9);g.restore()};
 const simge=(s,a,odak,golge)=>{const k=S0*s/64,ox=32+(FX-32)*odak,oy=32+(FY-32)*odak;
  g.save();g.translate(cx-ox*k,cy-oy*k);g.scale(k,k);g.globalAlpha=a;
  const sari=g.createLinearGradient(0,0,0,64);sari.addColorStop(0,'#FFE36E');sari.addColorStop(1,'#FFC21A');g.fillStyle=sari;
  if(golge>.01){g.save();g.shadowColor='rgba(0,0,0,'+(.3*golge)+')';g.shadowBlur=24*s*dpr;g.shadowOffsetY=10*s*dpr;g.fill(kare);g.restore()}
  g.fill(kare);
  const isik=g.createRadialGradient(32,0,0,32,0,60.8);isik.addColorStop(0,'rgba(255,255,255,.3)');isik.addColorStop(.6,'rgba(255,255,255,0)');g.fillStyle=isik;g.fill(kare);
  g.clip(kare);g.strokeStyle='#1D1D1F';g.fillStyle='#1D1D1F';g.lineWidth=3.2;g.lineCap='round';g.lineJoin='round';
  for(const y of adam){if(y.dolu)g.fill(y.p);g.stroke(y.p)}
  g.restore()};
 const kare1=(s,a,odak,golge,za)=>{g.setTransform(dpr,0,0,dpr,0,0);g.clearRect(0,0,W,H);
  if(za>0){g.globalAlpha=za;g.fillStyle=bg;g.fillRect(0,0,W,H);g.globalAlpha=1}
  if(a>0)simge(s,a,odak,golge);
  dugmeler()};
 kare1(1,1,0,0,1);cv.style.display='block';ov.style.background='transparent';ik.style.display='none';
 // uygulama: simgenin içinden çıkınca ekrana çarpar (büyükten gelir, bir tık küçülür, oturur)
 for(const e of [$('bar'),UYG==='ana'?$('ana'):null]){if(!e)continue;const r=e.getBoundingClientRect();e.style.transformOrigin=(cx-r.left)+'px '+(cy-r.top)+'px';
  const a=e.animate([{transform:'scale(1.18)',opacity:.25,easing:'cubic-bezier(.16,.8,.3,1)'},{offset:.58,transform:'scale(.982)',opacity:1,easing:'cubic-bezier(.4,0,.4,1)'},{offset:.82,transform:'scale(1.004)',opacity:1,easing:'ease-out'},{transform:'none',opacity:1}],{duration:620,delay:T1+T2*.64,fill:'backwards'});
  a.onfinish=()=>{e.style.transformOrigin=''}}
 let t0=0;
 const adim=now=>{if(!t0)t0=now;const t=now-t0;
  if(t<T1){kare1(1-.18*io(t/T1),1,0,0,1);requestAnimationFrame(adim);return}       // geri çekilir
  const p=Math.min(1,(t-T1)/T2),s=.82*Math.exp(LK*Math.pow(p,1.5));             // hızlanarak üstümüze gelir
  kare1(s,1-yumu(.7,.93,p),yumu(0,.45,p),Math.sin(Math.PI*Math.min(1,p/.4))*.9,1-yumu(.6,.76,p));
  if(p<1)requestAnimationFrame(adim);else bitir()};
 requestAnimationFrame(adim)}
'''

import json
# açılışta çizilen adam: eleman.svg'deki çizgiler (simge değişirse açılış da değişir)
ADAM = [{"d": m.group(1), "dolu": bool(m.group(2))} for m in re.finditer(r'<path d="([^"]+)"( fill="#[0-9A-Fa-f]{3,6}")?\s*/>', ELEMAN_SVG.split("clip-path=")[1])]
assert len(ADAM) >= 3, ADAM
JS = JS.replace('__KARE__', json.dumps(SQ)).replace('__ADAM__', json.dumps(ADAM))

# ---------- üst çubuk: Eleman simgesi (menü) ----------
i = s.find('<div id="logo"')
j = s.find("</div>", i) + 6
assert i > 0 and s[i:j].count("lgS") >= 1
s = s[:i] + ('<button id="logo" type="button" aria-haspopup="menu" aria-expanded="false" title="Ana sayfa ve uygulamalar">'
             '<svg aria-hidden="true"><use href="#ikEleman"/></svg><span class="lAd"><b>Eleman</b><span id="lUyg"></span></span>'
             '<svg class="lOk" viewBox="0 0 12 8" aria-hidden="true"><path d="M1.6 1.8 6 6.2l4.4-4.4"/></svg></button>\n'
             ' <div id="uMenu" role="menu" aria-label="Ana sayfa ve uygulamalar">'
             '<button type="button" role="menuitem" data-u="ana"><span class="mIk mEv"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3.5 10.6 12 3.6l8.5 7v9.1a1 1 0 0 1-1 1H15v-6.2H9v6.2H4.5a1 1 0 0 1-1-1z"/></svg></span>'
             '<span class="mMt"><b>Ana sayfa</b><small>Eleman</small></span><i class="mOn"></i></button>'
             '<div class="mAy"></div>'
             '<button type="button" role="menuitem" data-u="asorti"><svg class="mIk" aria-hidden="true"><use href="#ikAsorti"/></svg>'
             '<span class="mMt"><b>Asorti Aracı</b><small id="mDA"></small></span><i class="mOn"></i></button>'
             '<button type="button" role="menuitem" data-u="olcu"><svg class="mIk" aria-hidden="true"><use href="#ikOlcu"/></svg>'
             '<span class="mMt"><b>Ölçü Tablosu</b><small id="mDO"></small></span><i class="mOn"></i></button></div>') + s[j:]
r('<body>\n<div id="bar">', '<body>\n' + SPRITE + ACILIS_HTML + '<div id="bar">')
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

# ---------- ana sayfa, boş sayfa ekranları, Ölçü sayfalarının kabı ----------
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
 <div class="anaAlt">Created by <b>Şamil Yeşil</b></div>
</div></main>
'''
ARTI = '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M8 3v10M3 8h10"/></svg>'
BOS_A = ('<div class="bos" id="bosA" hidden><div class="bosK"><svg class="bosIk" aria-hidden="true"><use href="#ikAsorti"/></svg>'
         '<h2>Asorti Aracı</h2><p>Açık sayfa yok. Yeni bir sayfa aç; siparişi yaz, asortiyi hesapla.</p>'
         '<button type="button" class="bosYeni" id="bosYeniA">' + ARTI + 'Yeni sayfa</button></div></div>')
BOS_O = ('<div class="bos" id="bosO" hidden><div class="bosK"><svg class="bosIk" aria-hidden="true"><use href="#ikOlcu"/></svg>'
         '<h2>Ölçü Tablosu Aracı</h2><p>Açık sayfa yok. Yeni bir sayfa aç; müşteri kağıdını tara ya da PDF\'ini bırak.</p>'
         '<button type="button" class="bosYeni" id="bosYeniO">' + ARTI + 'Yeni sayfa</button></div></div>')
r('<div id="sayfalar"></div>', ANA + '<div id="sayfalar">' + BOS_A + '</div><div id="sayfalarO">' + BOS_O + '</div>')

# ---------- görünüm (CSS) ----------
CSS = '''
/* ================= Eleman ================= */
/* renk: Eleman sarı, Asorti mavi (aynen), Ölçü yeşil. Açık uygulama html[data-uyg] ile seçilir */
html[data-uyg=ana]{--acc:#b57d00;--accs:rgba(245,176,0,.17)}
html[data-theme=dark][data-uyg=ana]{--acc:#ffc93c;--accs:rgba(255,201,60,.18)}
html[data-uyg=olcu]{--acc:#168a49;--accs:rgba(22,138,73,.12)}
html[data-theme=dark][data-uyg=olcu]{--acc:#34c77b;--accs:rgba(52,199,123,.2)}
/* sol üst: Eleman simgesi, basınca menü */
#logo{border:0;background:transparent;font:inherit;cursor:pointer;border-radius:11px;margin-left:-6px;padding:5px 14px 5px 6px;gap:9px;transition:background .2s}
#logo:hover,#logo[aria-expanded=true]{background:var(--tabh)}
#logo:focus-visible{outline:2px solid var(--acc);outline-offset:1px}
#logo>svg:first-child{filter:drop-shadow(0 1px 1.5px rgba(150,105,0,.28)) drop-shadow(0 3px 6px rgba(150,105,0,.12))}
#logo .lAd{display:flex;align-items:center}
#logo b{font-weight:680;color:var(--ink)}
#lUyg{color:var(--mut);font-weight:500}
#lUyg:not(:empty)::before{content:'›';display:inline-block;margin:0 7px 0 8px;opacity:.55;font-weight:400}
#logo .lOk{width:11px;height:8px;fill:none;stroke:var(--mut);stroke-width:1.6;stroke-linecap:round;stroke-linejoin:round;margin-left:2px;transition:transform .28s cubic-bezier(.2,.8,.2,1)}
#logo[aria-expanded=true] .lOk{transform:rotate(180deg)}
html.pencere #bar #logo{app-region:no-drag;-webkit-app-region:no-drag}
#uMenu{position:absolute;top:52px;left:8px;z-index:30;width:292px;padding:6px;border-radius:16px;background:var(--pop);backdrop-filter:saturate(180%) blur(24px);
 box-shadow:var(--psh);border:1px solid var(--line);transform-origin:22px 0;opacity:0;visibility:hidden;transform:translateY(-6px) scale(.96);
 transition:opacity .2s cubic-bezier(.2,.8,.2,1),transform .26s cubic-bezier(.2,.9,.25,1),visibility 0s linear .26s;app-region:no-drag;-webkit-app-region:no-drag}
#uMenu.on{opacity:1;visibility:visible;transform:none;transition:opacity .18s ease-out,transform .3s cubic-bezier(.2,.9,.25,1.05),visibility 0s}
#uMenu button{display:flex;align-items:center;gap:12px;width:100%;padding:8px 10px;border:0;border-radius:11px;background:transparent;text-align:left;cursor:pointer;color:var(--ink);transition:background .15s}
#uMenu button:hover{background:var(--tabh)}
#uMenu button.on{background:var(--accs)}
#uMenu .mIk{width:34px;height:34px;flex:none;filter:drop-shadow(0 1px 2px rgba(0,0,0,.14))}
#uMenu .mEv{display:grid;place-items:center;border-radius:9px;background:linear-gradient(#ffe36e,#ffc21a)}
#uMenu .mEv svg{width:19px;height:19px;fill:none;stroke:#1d1d1f;stroke-width:1.9;stroke-linejoin:round}
#uMenu .mMt{display:flex;flex-direction:column;gap:1px;flex:1;min-width:0}
#uMenu .mMt b{font-size:14px;font-weight:620;letter-spacing:-.01em}
#uMenu .mMt small{font-size:12px;color:var(--mut);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#uMenu .mOn{width:7px;height:7px;border-radius:50%;flex:none;margin-right:4px;background:transparent}
#uMenu button.on .mOn{background:var(--acc)}
#uMenu button[data-u=asorti].on{background:rgba(0,113,227,.12)}#uMenu button[data-u=asorti].on .mOn{background:#0071e3}
#uMenu button[data-u=olcu].on{background:rgba(22,138,73,.13)}#uMenu button[data-u=olcu].on .mOn{background:#168a49}
html[data-theme=dark] #uMenu button[data-u=asorti].on{background:rgba(10,132,255,.22)}html[data-theme=dark] #uMenu button[data-u=asorti].on .mOn{background:#0a84ff}
html[data-theme=dark] #uMenu button[data-u=olcu].on{background:rgba(52,199,123,.2)}html[data-theme=dark] #uMenu button[data-u=olcu].on .mOn{background:#34c77b}
#uMenu .mAy{height:1px;margin:5px 10px;background:var(--line)}
/* sekme şeritleri: açık uygulamanınki görünür, geçerken yumuşakça belirir */
html[data-uyg=ana] #serit>*{display:none}
html[data-uyg=asorti] #tabsO,html[data-uyg=olcu] #tabs{display:none}
#tabsO{display:flex;align-items:center;gap:4px;overflow-x:auto;scrollbar-width:none;padding:6px 2px;min-width:0;scroll-behavior:smooth}
#tabsO::-webkit-scrollbar{display:none}
html[data-uyg=asorti] #tabs,html[data-uyg=olcu] #tabsO,html:not([data-uyg=ana]) #yeni{animation:serGir .34s cubic-bezier(.2,.8,.2,1)}
@keyframes serGir{from{opacity:0;transform:translateX(-6px)}to{opacity:1;transform:none}}
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
/* katmanlar: ana sayfa, Asorti sayfaları, Ölçü sayfaları. Geçişler yumuşak; gizli olan çalışmaya devam eder */
#ana,#sayfalarO{position:absolute;top:54px;left:0;right:0;bottom:0;overflow:hidden}
#sayfalarO iframe{position:absolute;inset:0;width:100%;height:100%;border:0;display:none;background:var(--bg)}
#sayfalarO iframe.on{display:block;z-index:2}
#sayfalarO iframe.yukleniyor{display:block;visibility:hidden;z-index:0}
#ana,#sayfalar,#sayfalarO{transition:opacity .34s cubic-bezier(.2,.8,.2,1),transform .42s cubic-bezier(.2,.8,.2,1),visibility 0s}
html:not([data-uyg=ana]) #ana,html:not([data-uyg=asorti]) #sayfalar,html:not([data-uyg=olcu]) #sayfalarO{visibility:hidden;opacity:0;pointer-events:none;transition:opacity .22s ease,transform .22s ease,visibility 0s linear .22s}
html:not([data-uyg=ana]) #ana{transform:scale(.985)}
@media (prefers-reduced-motion:reduce){#ana,#sayfalar,#sayfalarO{transition:none!important}}
/* açık sayfa yokken: boş ekran */
.bos{position:absolute;inset:0;z-index:3;display:grid;place-items:center;padding:24px}
.bos[hidden]{display:none}
#bosA{background:radial-gradient(55vmax 48vmax at 10% 6%,rgba(120,170,255,.30),transparent 62%),radial-gradient(50vmax 44vmax at 92% 10%,rgba(190,160,255,.22),transparent 62%),radial-gradient(56vmax 50vmax at 78% 98%,rgba(255,200,170,.25),transparent 62%),var(--bg)}
#bosO{background:radial-gradient(55vmax 48vmax at 10% 6%,rgba(90,200,140,.28),transparent 62%),radial-gradient(50vmax 44vmax at 92% 10%,rgba(180,215,140,.22),transparent 62%),radial-gradient(56vmax 50vmax at 78% 98%,rgba(255,205,175,.24),transparent 62%),var(--bg)}
html[data-theme=dark] #bosA{background:radial-gradient(55vmax 48vmax at 10% 6%,rgba(40,80,200,.30),transparent 62%),radial-gradient(56vmax 50vmax at 78% 98%,rgba(90,50,120,.25),transparent 62%),var(--bg)}
html[data-theme=dark] #bosO{background:radial-gradient(55vmax 48vmax at 10% 6%,rgba(20,110,60,.30),transparent 62%),radial-gradient(56vmax 50vmax at 78% 98%,rgba(60,90,40,.22),transparent 62%),var(--bg)}
.bosK{text-align:center;max-width:440px;animation:bosGir .5s cubic-bezier(.2,.8,.2,1) both}
@keyframes bosGir{from{opacity:0;transform:translateY(8px) scale(.985)}to{opacity:1;transform:none}}
.bosIk{width:84px;height:84px;display:block;margin:0 auto 18px;filter:drop-shadow(0 2px 3px rgba(0,0,0,.10)) drop-shadow(0 12px 24px rgba(0,0,0,.12))}
.bosK h2{margin:0;font-size:28px;font-weight:700;letter-spacing:-.03em}
.bosK p{margin:10px 0 24px;font-size:15px;line-height:1.5;color:var(--mut)}
.bosYeni{display:inline-flex;align-items:center;gap:8px;height:44px;padding:0 22px 0 18px;border:0;border-radius:22px;color:#fff;font:600 15px/1 inherit;cursor:pointer;
 background:linear-gradient(180deg,#4da6ff,#0071e3);box-shadow:inset 0 1px 0 rgba(255,255,255,.4),0 8px 22px rgba(0,113,227,.32);transition:transform .2s cubic-bezier(.2,.8,.2,1),box-shadow .2s}
#bosYeniO{background:linear-gradient(180deg,#3cc47c,#168a49);box-shadow:inset 0 1px 0 rgba(255,255,255,.4),0 8px 22px rgba(22,138,73,.30)}
.bosYeni:hover{transform:translateY(-2px)}.bosYeni:active{transform:scale(.97)}
.bosYeni svg{width:16px;height:16px;fill:none;stroke:currentColor;stroke-width:2.2;stroke-linecap:round}
/* açılış: Eleman simgesi ortada; küçülüp büyüyerek uygulamayı açar */
#acilis{position:fixed;inset:0;z-index:1000;display:grid;place-items:center;background:var(--bg);pointer-events:none}
#acilis .aIk{width:104px;height:104px;display:block}
#acilis canvas{position:absolute;left:0;top:0;display:none}
html.acildi #acilis{display:none}
''' + ANA_CSS + '''
'''
r("</style></head>", CSS + "</style></head>")

# ---------- davranış (Asorti'nin koduna dokunulan yerler) ----------
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
r("$('surum').textContent=j.surum?'Asorti Aracı v'+j.surum:'';", "$('surum').textContent=j.surum?'Eleman v'+j.surum:'';")
r("confirm('Asorti Aracı v'+G.yeni", "confirm('Eleman v'+G.yeni")
r("masaüstündeki Asorti Aracı simgesinden aç", "masaüstündeki Eleman simgesinden aç")
r("durumYaz(j.kopru?'ok':'bad',j.kopru?'Gerber bağlı':'Gerber köprüsü kapalı')}", "durumYaz(j.kopru?'ok':'bad',j.kopru?'Gerber bağlı':'Gerber köprüsü kapalı');GB=j.gerber===false?'yok':j.kopru?'ok':'bad';anaYaz()}")
# Asorti sekme adları ve Gerber işi bilgisi kalıcı (sayfa uyurken / program yeniden açılınca sekme adı kalsın)
r("const info={};", "const info={};for(const id of (S.list||[]))if(S.ad&&S.ad[id])info[id]={ad:S.ad[id]};")
r("info[d.id]={ad:d.ad,busy:d.busy,bitti:d.bitti};ciz()}}", "info[d.id]={ad:d.ad,busy:d.busy,bitti:d.bitti};kaliciA(d.id);ciz()}}")
r("S.list.splice(i,1);delete info[id];", "S.list.splice(i,1);delete info[id];if(S.ad)delete S.ad[id];if(S.ms)delete S.ms[id];")
# sayfa kendiliğinden açılmaz: son sayfa kapanınca boş ekran
r("if(!S.list.length){const n=yeniId();S.list.push(n);giris=n;S.on=n}else if(S.on===id)S.on=S.list[Math.max(0,i-1)];",
  "if(!S.list.length)S.on='';else if(S.on===id)S.on=S.list[Math.max(0,i-1)];")
r("sekmeCik(b)});\n sayfaGoster(S.on);", "sekmeCik(b)});\n if(S.on)sayfaGoster(S.on);else bosGoster('A');")
r("function sayfaGoster(id){const f=frame(id);if(gosterilen===f)return;gosterilen=f;",
  "function sayfaGoster(id){$('bosA').hidden=true;const f=frame(id);sonA[id]=Date.now();if(gosterilen===f)return;gosterilen=f;")
r("f.classList.remove('yukleniyor');f.classList.add('on');\n  try{const w=f.contentWindow;if(w&&w.sayfaBelir)w.sayfaBelir()}catch(e){}};",
  "f.classList.remove('yukleniyor');f.classList.add('on');\n  try{const w=f.contentWindow;if(w&&w.sayfaBelir)w.sayfaBelir()}catch(e){};setTimeout(uyutA,400)};")
# bildirime / Windows bildirimine tıklayınca Asorti'ye geçilir
r("tik:d.id!==S.on?()=>ac(d.id):null", "tik:(d.id!==S.on||UYG!=='asorti')?()=>{uygGit('asorti');ac(d.id)}:null")
r("ipucu:d.id!==S.on?'Sayfaya gitmek için tıkla':''", "ipucu:(d.id!==S.on||UYG!=='asorti')?'Sayfaya gitmek için tıkla':''")
r("if(d.t==='git'&&S.list.includes(d.id))ac(d.id);", "if(d.t==='git'&&S.list.includes(d.id)){uygGit('asorti');ac(d.id)}")
# açılış: sayfa kendiliğinden açılmaz; arkada yalnız Gerber işi süren sayfalar yüklenir (diğerleri ilk açılınca)
r("if(!S.list.length)yeni();else{if(!S.list.includes(S.on))S.on=S.list[0];ac(S.on);",
  "if(!S.list.length){S.on='';ciz()}else{if(!S.list.includes(S.on))S.on=S.list[0];ac(S.on);")
r("const digerleri=()=>S.list.forEach(frame),", "const digerleri=()=>S.list.forEach(id=>{if(id!==S.on&&mesgulA(id))frame(id)}),")
r("function ciz(){let onceki=null;", "function ciz(){setTimeout(()=>{try{anaYaz()}catch(e){}},0);let onceki=null;")
# açılış ekranı: Eleman ana sayfayla açılır; ekran çizilince yerel açılış ekranı kalkar ve simge uygulamayı açar
r("(()=>{const f=document.querySelector('#sayfalar iframe[data-id=\"'+S.on+'\"]');let gitti=false;",
  "(()=>{const f=UYG==='ana'?null:document.querySelector('#sayfalar iframe[data-id=\"'+S.on+'\"]');let gitti=false;")
r(" const gonder=()=>{if(gitti)return;gitti=true;fetch('/hazir',{method:'POST',body:'{}'}).catch(()=>{})},",
  " const gonder=()=>{if(gitti)return;gitti=true;fetch('/hazir',{method:'POST',body:'{}'}).catch(()=>{});acilisBekle()},")
r(" if(!f)return bildir();", " if(!f)return Promise.race([document.fonts.ready,new Promise(r=>setTimeout(r,800))]).then(()=>setTimeout(bildir,40),bildir);")
r("/* açılışta önce görünen sayfa yüklenir, diğerleri hemen ardından", JS + "/* açılışta önce görünen sayfa yüklenir, diğerleri hemen ardından")
open(out, "w", encoding="utf-8", newline="\n").write(s)
print("Eleman kabuğu:", out, len(s))
