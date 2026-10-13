import urllib.request
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')
headers = {'User-Agent': 'Mozilla/5.0'}

url = "https://www.drikpanchang.com/panchang/month-panchang.html?date=01/05/2026"
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req, timeout=10) as resp:
    html = resp.read().decode('utf-8')

print("May 2026 Panchang length:", len(html))
# Find ekadashi occurrences
for match in re.finditer(r'(Ekadashi|Padmini|Parama|Nirjala|Apara)', html, re.IGNORECASE):
    snippet = html[max(0, match.start()-100):min(len(html), match.end()+100)]
    clean = re.sub(r'<[^>]+>', ' ', snippet)
    print(' '.join(clean.split()))
