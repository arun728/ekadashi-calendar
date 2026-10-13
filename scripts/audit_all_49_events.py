import urllib.request
import re
import json
import sys
from datetime import datetime, timezone, timedelta

sys.stdout.reconfigure(encoding='utf-8')
headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}

# 2026: 24 Ekadashis (including Adhika Jyeshtha Padmini and Parama)
SLUGS_2026 = [
    ("shattila", "Shattila Ekadashi", "krishna", "pausha", 1),
    ("jaya", "Jaya Ekadashi", "shukla", "magha", 2),
    ("vijaya", "Vijaya Ekadashi", "krishna", "magha", 3),
    ("amalaki", "Amalaki Ekadashi", "shukla", "phalguna", 4),
    ("papmochani", "Papamochani Ekadashi", "krishna", "phalguna", 5),
    ("kamada", "Kamada Ekadashi", "shukla", "chaitra", 6),
    ("varuthini", "Varuthini Ekadashi", "krishna", "chaitra", 7),
    ("mohini", "Mohini Ekadashi", "shukla", "vaishakha", 8),
    ("apara", "Apara Ekadashi", "krishna", "vaishakha", 9),
    ("padmini", "Padmini Ekadashi", "shukla", "adhika_jyeshtha", 10),
    ("parama", "Parama Ekadashi", "krishna", "adhika_jyeshtha", 11),
    ("nirjala", "Nirjala Ekadashi", "shukla", "jyeshtha", 12),
    ("yogini", "Yogini Ekadashi", "krishna", "jyeshtha", 13),
    ("devshayani", "Devshayani Ekadashi", "shukla", "ashadha", 14),
    ("kamika", "Kamika Ekadashi", "krishna", "ashadha", 15),
    ("shravana-putrada", "Shravana Putrada Ekadashi", "shukla", "shravana", 16),
    ("aja", "Aja Ekadashi", "krishna", "shravana", 17),
    ("parivartini", "Parivartini Ekadashi", "shukla", "bhadrapada", 18),
    ("indira", "Indira Ekadashi", "krishna", "bhadrapada", 19),
    ("papankusha", "Papankusha Ekadashi", "shukla", "ashwina", 20),
    ("rama", "Rama Ekadashi", "krishna", "ashwina", 21),
    ("prabodhini", "Prabodhini Ekadashi", "shukla", "kartika", 22),
    ("utpanna", "Utpanna Ekadashi", "krishna", "kartika", 23),
    ("mokshada", "Mokshada Ekadashi", "shukla", "margashirsha", 24),
]

# 2027: 25 Ekadashis (Saphala occurs twice: Jan 3 and Dec 23)
SLUGS_2027 = [
    ("saphala", "Saphala Ekadashi", "krishna", "pausha", 25, "03/01/2027"),
    ("pausha-putrada", "Pausha Putrada Ekadashi", "shukla", "pausha", 26, None),
    ("shattila", "Shattila Ekadashi", "krishna", "magha", 27, None),
    ("jaya", "Jaya Ekadashi", "shukla", "magha", 28, None),
    ("vijaya", "Vijaya Ekadashi", "krishna", "phalguna", 29, None),
    ("amalaki", "Amalaki Ekadashi", "shukla", "phalguna", 30, None),
    ("papmochani", "Papamochani Ekadashi", "krishna", "chaitra", 31, None),
    ("kamada", "Kamada Ekadashi", "shukla", "chaitra", 32, None),
    ("varuthini", "Varuthini Ekadashi", "krishna", "vaishakha", 33, None),
    ("mohini", "Mohini Ekadashi", "shukla", "vaishakha", 34, None),
    ("apara", "Apara Ekadashi", "krishna", "jyeshtha", 35, None),
    ("nirjala", "Nirjala Ekadashi", "shukla", "jyeshtha", 36, None),
    ("yogini", "Yogini Ekadashi", "krishna", "ashadha", 37, None),
    ("devshayani", "Devshayani Ekadashi", "shukla", "ashadha", 38, None),
    ("kamika", "Kamika Ekadashi", "krishna", "shravana", 39, None),
    ("shravana-putrada", "Shravana Putrada Ekadashi", "shukla", "shravana", 40, None),
    ("aja", "Aja Ekadashi", "krishna", "bhadrapada", 41, None),
    ("parivartini", "Parivartini Ekadashi", "shukla", "bhadrapada", 42, None),
    ("indira", "Indira Ekadashi", "krishna", "ashwina", 43, None),
    ("papankusha", "Papankusha Ekadashi", "shukla", "ashwina", 44, None),
    ("rama", "Rama Ekadashi", "krishna", "kartika", 45, None),
    ("prabodhini", "Prabodhini Ekadashi", "shukla", "kartika", 46, None),
    ("utpanna", "Utpanna Ekadashi", "krishna", "margashirsha", 47, None),
    ("mokshada", "Mokshada Ekadashi", "shukla", "margashirsha", 48, None),
    ("saphala", "Saphala Ekadashi", "krishna", "pausha", 49, "23/12/2027"),
]

def clean_html(text):
    text = re.sub(r'<[^>]+>', ' ', text)
    return ' '.join(text.split())

def fetch_url(url):
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            return resp.read().decode('utf-8')
    except Exception as e:
        return None

print(f"Total events configured: {len(SLUGS_2026)} (2026) + {len(SLUGS_2027)} (2027) = {len(SLUGS_2026) + len(SLUGS_2027)}")
