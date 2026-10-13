import json
from datetime import datetime, timezone, timedelta

with open('assets/ekadashi_data.json', 'r', encoding='utf-8') as f:
    d = json.load(f)

events = {e['id']: e for e in d['ekadashis']}

targets = [13, 16, 22, 29, 32]
for tid in targets:
    e = events[tid]
    print(f"\n================ ID {tid}: {e['name']['en']} ================")
    print("Base IST Timing:", e['timing']['IST'])
    print("Tithi:", e.get('tithi'))
    tithi = e.get('tithi', {})
    if tithi.get('ekadashi_start'):
        # Convert UTC to IST (+5:30)
        def to_ist(s):
            dt = datetime.fromisoformat(s.replace('Z', '+00:00'))
            ist = dt + timedelta(hours=5, minutes=30)
            return ist.strftime('%Y-%m-%d %H:%M:%S IST')
        print("  Ekadashi Start (IST):", to_ist(tithi['ekadashi_start']))
        print("  Ekadashi End   (IST):", to_ist(tithi['ekadashi_end']))
        print("  Dwadashi End   (IST):", to_ist(tithi['dwadashi_end']))
        print("  Dashami End    (IST):", to_ist(tithi['dashami_end']))
