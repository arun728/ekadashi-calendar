import re
import json

with open('scripts/iskcon_2027.html', 'r', encoding='utf-8') as f:
    text = f.read()

# Let's find each event card
cards = re.split(r'<div class="dpEventCard', text)[1:]
print(f"Found {len(cards)} event cards in ISKCON page")

iskcon_events = []
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

    iskcon_events.append({
        "title": title_str,
        "date": date_str,
        "parana": parana_clean
    })

with open('scripts/iskcon_parsed_2027.json', 'w', encoding='utf-8') as f:
    json.dump(iskcon_events, f, ensure_ascii=False, indent=2)

for ev in iskcon_events:
    print(f"{ev['title']:<25} | {ev['date']:<30} | {ev['parana']}")
