import urllib.request
import re
import json
import sys

sys.stdout.reconfigure(encoding='utf-8')

EKADASHIS_2026 = [
    ("shattila", "Shattila Ekadashi"),
    ("jaya", "Jaya Ekadashi"),
    ("vijaya", "Vijaya Ekadashi"),
    ("amalaki", "Amalaki Ekadashi"),
    ("papmochani", "Papamochani Ekadashi"),
    ("kamada", "Kamada Ekadashi"),
    ("varuthini", "Varuthini Ekadashi"),
    ("mohini", "Mohini Ekadashi"),
    ("apara", "Apara Ekadashi"),
    ("padmini", "Padmini Ekadashi"),
    ("parama", "Parama Ekadashi"),
    ("nirjala", "Nirjala Ekadashi"),
    ("yogini", "Yogini Ekadashi"),
    ("devshayani", "Devshayani Ekadashi"),
    ("kamika", "Kamika Ekadashi"),
    ("putrada", "Shravana Putrada Ekadashi"),
    ("aja", "Aja Ekadashi"),
    ("parivartini", "Parivartini Ekadashi"),
    ("indira", "Indira Ekadashi"),
    ("papankusha", "Papankusha Ekadashi"),
    ("rama", "Rama Ekadashi"),
    ("prabodhini", "Prabodhini Ekadashi"),
    ("utpanna", "Utpanna Ekadashi"),
    ("mokshada", "Mokshada Ekadashi")
]

def clean_html(text):
    text = re.sub(r'<[^>]+>', ' ', text)
    return ' '.join(text.split())

headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}

results = {}
for slug, name in EKADASHIS_2026:
    url = f"https://www.drikpanchang.com/ekadashis/{slug}/{slug}-ekadashi-date-time.html?geoname-id=1264527&year=2026"
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as resp:
            html = resp.read().decode('utf-8')
        infos = [clean_html(i) for i in re.findall(r'dpMuhurtaInfo">(.*?)</div>', html)]
        times = [clean_html(t) for t in re.findall(r'dpMuhurtaTime">(.*?)</div>', html)]
        results[name] = list(zip(infos, times))
        print(f"OK: {name}: {len(infos)} items")
    except Exception as e:
        print(f"ERR: {name}: {e}")

with open('scripts/drik_2026_audit_chennai.json', 'w', encoding='utf-8') as f:
    json.dump(results, f, ensure_ascii=False, indent=2)
print("Saved scripts/drik_2026_audit_chennai.json")
