import urllib.request
import re

def clean_html(text):
    text = re.sub(r'<[^>]+>', ' ', text)
    return ' '.join(text.split())

for city, gid in [('Delhi', '1273294'), ('Chennai', '1264527'), ('Guwahati', '1271476'), ('Mumbai', '1275339')]:
    url = f'https://www.drikpanchang.com/ekadashis/vijaya/vijaya-ekadashi-date-time.html?geoname-id={gid}&year=2026'
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            html = resp.read().decode('utf-8')
        infos = [clean_html(i) for i in re.findall(r'dpMuhurtaInfo">(.*?)</div>', html)]
        times = [clean_html(t) for t in re.findall(r'dpMuhurtaTime">(.*?)</div>', html)]
        print(f'=== {city} ===')
        for i, t in zip(infos, times):
            print(f'  {i} -> {t}')
    except Exception as e:
        print(f'{city} error: {e}')
