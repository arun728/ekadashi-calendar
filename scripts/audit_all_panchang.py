import urllib.request
import re
import json
import sys

sys.stdout.reconfigure(encoding='utf-8')
headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}

# All Ekadashis for 2026 and 2027
# In 2026, Adhika Jyeshtha occurs with Padmini and Parama
# In 2027, Saphala occurs twice (Jan 3 and Dec 23)

def fetch_ekadashi(url):
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            html = resp.read().decode('utf-8')
        infos = [re.sub(r'<[^>]+>', ' ', i).strip() for i in re.findall(r'dpMuhurtaInfo">(.*?)</div>', html)]
        times = [re.sub(r'<[^>]+>', ' ', t).strip() for t in re.findall(r'dpMuhurtaTime">(.*?)</div>', html)]
        # Also extract tithi start and end
        tithi_m = re.findall(r'Ekadashi Tithi Begins\s*-\s*([^<]+)<.*?Ekadashi Tithi Ends\s*-\s*([^<]+)<', html, re.DOTALL)
        tithi_info = tithi_m[0] if tithi_m else None
        return {
            'pairs': list(zip(infos, times)),
            'tithi': tithi_info
        }
    except Exception as e:
        return {'error': str(e)}

print("Script template ready")
