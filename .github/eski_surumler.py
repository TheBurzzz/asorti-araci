# Eski sürüm dallarını (surum-v*, arsiv, surum-test) GitHub Releases'a taşır. GitHub Actions'ta bir kez çalışır
# (kullanıcının isteği, 7 Kasım 2026: dal listesi sadeleşsin, eski sürümler Releases'ta dursun).
# Her sürüm için: etiket o dalın son commit'inde, sürüm notları o commit'teki AsortiAraci/surum.json'dan.
# Bütün sürümler oluşunca, etiketi aynı commit'te olan eski dallar silinir (surum-test, surum-v1.1.6 ile aynı commit).
import json, subprocess, os, sys, tempfile
def run(*a, ok=False):
    r = subprocess.run(list(a), capture_output=True, text=True)
    if r.returncode and not ok: print(r.stdout, r.stderr); sys.exit(r.returncode)
    return r
AY = ['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık']
def tarih(t):
    try: y, m, d = (int(x) for x in t.split('-')); return f'{d} {AY[m-1]} {y}'
    except Exception: return t
L = json.load(open('.github/eski_surumler.json', encoding='utf-8'))
var = set(run('gh', 'release', 'list', '--limit', '200', '--json', 'tagName', '-q', '.[].tagName').stdout.split())
for i, o in enumerate(L):
    t, sha = o['etiket'], o['sha']
    if t in var: print('var:', t); continue
    if t == 'ilk-deneme':
        ad = 'İlk deneme sürümü'
        notlar = ['Asorti Aracı paketlenmeden önce `C:\\AccuNest` içinde çalışan ilk deneme hâli (26 Ekim 2026). Yalnız arşiv için.']
        gun = ''
    else:
        s = json.loads(run('git', 'show', f'{sha}:AsortiAraci/surum.json').stdout.lstrip('\ufeff'))
        ad = f"Asorti Aracı {t}" + (' (iş bilgisayarındaki sürüm)' if t == 'v2.0.4' else '')
        notlar = s.get('notlar') or []
        gun = tarih(s.get('tarih') or run('git', 'log', '-1', '--format=%ad', '--date=short', sha).stdout.strip())
    govde = (f'**{gun}**\n\n' if gun else '') + '\n'.join('- ' + n for n in notlar) + \
        ('\n\nKurmak için: aşağıdaki **Source code (zip)** → klasöre çıkar → **Kurulum.bat**.' if t != 'ilk-deneme' else '')
    f = tempfile.NamedTemporaryFile('w', delete=False, suffix='.md', encoding='utf-8'); f.write(govde); f.close()
    son = (t == 'v2.0.4')
    run('gh', 'release', 'create', t, '--target', sha, '--title', ad, '--notes-file', f.name, '--latest=' + ('true' if son else 'false'))
    print('oluştu:', t)
# etiketler yerinde mi? sonra eski dallar
run('git', 'fetch', '--tags', '--force', 'origin')
silinecek = []
for o in L:
    if not o.get('dal'): continue
    e = run('git', 'rev-parse', f"refs/tags/{o['etiket']}^{{commit}}", ok=True).stdout.strip()
    if e == o['sha']: silinecek.append(o['dal'])
    else: print('etiket tutmuyor, dal kalıyor:', o['dal'])
d = run('git', 'rev-parse', 'origin/surum-test', ok=True).stdout.strip()
if d and run('git', 'rev-parse', 'refs/tags/v1.1.6^{commit}', ok=True).stdout.strip() == d: silinecek.append('surum-test')
if silinecek:
    run('git', 'push', 'origin', '--delete', *silinecek)
    print('silinen dallar:', ' '.join(silinecek))
