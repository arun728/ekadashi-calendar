import urllib.request
import re

url = 'https://www.drikpanchang.com/ekadashis/kamada/kamada-ekadashi-date-time.html?geoname-id=1264527&year=2027'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req, timeout=10) as r:
        html = r.read().decode('utf-8')
        times = re.findall(r'dpMuhurtaTime\">(.*?)</div>', html)
        infos = re.findall(r'dpMuhurtaInfo\">(.*?)</div>', html)
        print('Kamada html len:', len(html))
        print('infos:', [re.sub(r'<[^>]+>', ' ', i).strip() for i in infos])
        print('times:', [re.sub(r'<[^>]+>', ' ', t).strip() for t in times])
except Exception as e:
    print('err:', e)
