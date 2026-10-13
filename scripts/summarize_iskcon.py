import json

def process_iskcon(year):
    with open(f'scripts/iskcon_parsed_{year}.json', 'r', encoding='utf-8') as f:
        cards = json.load(f)
    
    events = []
    # Each ekadashi block typically has 4 cards:
    # Card 0: Date title (e.g. "January 14, 2026, Wednesday")
    # Card 1: Ekadashi name (e.g. "Shattila Ekadashi")
    # Card 2: Parana info (e.g. "Parana - 06:35 AM to 10:46 AM")
    # Card 3: Notes / empty
    i = 0
    while i < len(cards):
        date_str = None
        name_str = None
        parana_str = None
        for j in range(i, min(i + 5, len(cards))):
            c = cards[j]
            if c['date'] != 'Unknown' and not date_str:
                date_str = c['date']
            if c['title'] != 'Unknown' and not name_str:
                name_str = c['title']
            if c['parana'] != 'Unknown' and not parana_str:
                parana_str = c['parana']
        if name_str:
            events.append({
                'name': name_str,
                'date': date_str,
                'parana': parana_str
            })
            i += 4
        else:
            i += 1
    return events

for y in [2026, 2027]:
    evs = process_iskcon(y)
    print(f"\n=================== ISKCON {y} ({len(evs)} events) ===================")
    for idx, e in enumerate(evs, 1):
        print(f"{idx:2d}. {e['name']:<25} | {e['date']:<30} | {e['parana']}")
