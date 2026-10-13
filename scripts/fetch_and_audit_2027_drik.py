import urllib.request
import re
import json
import time

EKADASHI_URLS = [
    ("Saphala Ekadashi", "https://www.drikpanchang.com/ekadashis/saphala/saphala-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Pausha Putrada Ekadashi", "https://www.drikpanchang.com/ekadashis/putrada/pausha-putrada-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Shattila Ekadashi", "https://www.drikpanchang.com/ekadashis/shattila/shattila-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Jaya Ekadashi", "https://www.drikpanchang.com/ekadashis/jaya/jaya-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Vijaya Ekadashi", "https://www.drikpanchang.com/ekadashis/vijaya/vijaya-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Amalaki Ekadashi", "https://www.drikpanchang.com/ekadashis/amalaki/amalaki-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Papamochani Ekadashi", "https://www.drikpanchang.com/ekadashis/papmochani/papmochani-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Kamada Ekadashi", "https://www.drikpanchang.com/ekadashis/kamada/kamada-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Varuthini Ekadashi", "https://www.drikpanchang.com/ekadashis/varuthini/varuthini-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Mohini Ekadashi", "https://www.drikpanchang.com/ekadashis/mohini/mohini-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Apara Ekadashi", "https://www.drikpanchang.com/ekadashis/apara/apara-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Nirjala Ekadashi", "https://www.drikpanchang.com/ekadashis/nirjala/nirjala-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Yogini Ekadashi", "https://www.drikpanchang.com/ekadashis/yogini/yogini-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Devshayani Ekadashi", "https://www.drikpanchang.com/ekadashis/devshayani/devshayani-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Kamika Ekadashi", "https://www.drikpanchang.com/ekadashis/kamika/kamika-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Shravana Putrada Ekadashi", "https://www.drikpanchang.com/ekadashis/putrada/shravana-putrada-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Aja Ekadashi", "https://www.drikpanchang.com/ekadashis/aja/aja-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Parivartini Ekadashi", "https://www.drikpanchang.com/ekadashis/parivartini/parivartini-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Indira Ekadashi", "https://www.drikpanchang.com/ekadashis/indira/indira-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Papankusha Ekadashi", "https://www.drikpanchang.com/ekadashis/papankusha/papankusha-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Rama Ekadashi", "https://www.drikpanchang.com/ekadashis/rama/rama-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Prabodhini Ekadashi", "https://www.drikpanchang.com/ekadashis/prabodhini/prabodhini-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Utpanna Ekadashi", "https://www.drikpanchang.com/ekadashis/utpanna/utpanna-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
    ("Mokshada Ekadashi", "https://www.drikpanchang.com/ekadashis/mokshada/mokshada-ekadashi-date-time.html?geoname-id=1264527&year=2027"),
]

def clean_html(text):
    text = re.sub(r'<[^>]+>', ' ', text)
    return ' '.join(text.split())

def audit_url(name, url):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            html = resp.read().decode('utf-8')
    except Exception as e:
        return {"name": name, "error": str(e)}

    # Extract Muhurta groups
    # Look for <div class="dpMuhurtaCard dpCard">...
    cards = re.findall(r'<div class="dpMuhurtaGroup.*?>(.*?)</div>\s*</div>', html, re.DOTALL)
    times = [clean_html(t) for t in re.findall(r'dpMuhurtaTime\">(.*?)</div>', html)]
    infos = [clean_html(i) for i in re.findall(r'dpMuhurtaInfo\">(.*?)</div>', html)]
    
    return {
        "name": name,
        "infos": infos,
        "times": times
    }

def main():
    results = []
    print("Fetching and auditing all 24 Ekadashis for Chennai 2027 from Drik Panchang...")
    for idx, (name, url) in enumerate(EKADASHI_URLS, 1):
        print(f"[{idx}/24] Fetching {name}...")
        res = audit_url(name, url)
        results.append(res)
        time.sleep(0.3)

    out_path = 'scripts/drik_2027_audit_results.json'
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    print(f"Audit results written to {out_path}")

if __name__ == '__main__':
    main()
