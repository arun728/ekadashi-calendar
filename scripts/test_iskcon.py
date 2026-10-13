import urllib.request
import re

def clean_html(text):
    text = re.sub(r'<[^>]+>', ' ', text)
    return ' '.join(text.split())

for year in [2026, 2027]:
    url = f'https://www.drikpanchang.com/iskcon/iskcon-ekadashi-list.html?geoname-id=1264527&year={year}'
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            html = resp.read().decode('utf-8')
        cards = re.findall(r'<div class="dpTableRow.*?>(.*?)</div>\s*</div>', html, re.DOTALL)
        print(f'=== ISKCON {year} Chennai ===')
        # Let's extract date, name, parana
        items = re.findall(r'class="dpTableCell">(.*?)</div>', html)
        print(f'Found {len(items)} cells')
        # Let's find rows with Ekadashi
        matches = re.findall(r'(\d{1,2}\s+[A-Za-z]+,\s+\d{4},\s+\w+).*?<a[^>]*>(.*?)</a>.*?Parana\s*-\s*([0-9:APM\s-]+)', html, re.DOTALL)
        print(f'Parsed matches: {len(matches)}')
        for m in matches[:10]:
            print(clean_html(m[0]), '||', clean_html(m[1]), '||', clean_html(m[2]))
    except Exception as e:
        print('Error:', e)
