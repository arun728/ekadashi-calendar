import urllib.request
import re
import json

headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}

for year in [2026, 2027]:
    url = f'https://www.drikpanchang.com/iskcon/iskcon-ekadashi-list.html?geoname-id=1264527&year={year}'
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=15) as resp:
        html = resp.read().decode('utf-8')
    
    cards = re.split(r'<div class="dpEventCard', html)[1:]
    print(f"Year {year}: Found {len(cards)} event cards")
    events = []
    for c in cards:
        date_m = re.search(r'class="dpEventDateTitle">([^<]+)</div>', c)
        title_m = re.search(r'title="[^"]*>\s*([A-Za-z\s]+Ekadashi)', c)
        parana_m = re.search(r'Parana\s*-\s*([^<]+(?:<span[^>]*>[^<]+</span>)*)', c)
        
        date_str = date_m.group(1).strip() if date_m else "Unknown"
        title_str = title_m.group(1).strip() if title_m else "Unknown"
        
        parana_clean = "Unknown"
        if parana_m:
            raw_p = parana_m.group(0)
            parana_clean = re.sub(r'<[^>]+>', ' ', raw_p).strip()
            parana_clean = ' '.join(parana_clean.split())
        
        events.append({
            "title": title_str,
            "date": date_str,
            "parana": parana_clean
        })
    with open(f'scripts/iskcon_parsed_{year}.json', 'w', encoding='utf-8') as f:
        json.dump(events, f, ensure_ascii=False, indent=2)
    print(f"Saved scripts/iskcon_parsed_{year}.json with {len(events)} events")
