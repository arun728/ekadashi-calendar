import urllib.request
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')
headers = {'User-Agent': 'Mozilla/5.0'}

url = "https://www.drikpanchang.com/ekadashis/vijaya/vijaya-ekadashi-date-time.html?year=2026"
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req, timeout=10) as resp:
    html = resp.read().decode('utf-8')

# Look for Tithi begins and ends
matches = re.findall(r'Ekadashi Tithi (?:Begins|Ends)\s*-\s*([^<\n\r]+)', html)
print("Vijaya 2026 Tithi matches:", matches)

# Also look for any other tithi details in the page
all_tithi = re.findall(r'([A-Za-z\s]+Tithi\s+(?:Begins|Ends))\s*-\s*([^<\n\r]+)', html)
for m in all_tithi:
    print(m[0].strip(), '->', m[1].strip())
