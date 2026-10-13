import urllib.request
import re

url = 'https://www.drikpanchang.com/iskcon/iskcon-ekadashi-list.html?geoname-id=1264527&year=2027'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req, timeout=15) as r:
        html = r.read().decode('utf-8')
    print("ISKCON html length:", len(html))

    # Look for event rows or card titles
    # Ekadashi names and dates
    rows = re.findall(r'<div class=\"dpTableCell\">(.*?)</div>', html)
    print("Table cells found:", len(rows))
    for r in rows[:30]:
        print(re.sub(r'<[^>]+>', ' ', r).strip())

    events = re.findall(r'(\w+ Ekadashi|\w+ Putrada Ekadashi).*?(\d{1,2}\s+[A-Za-z]+,\s+2027)', html)
    print("Events found:", len(events))
    for ev in events[:20]:
        print(ev)
except Exception as e:
    print('err:', e)
