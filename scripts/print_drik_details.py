import json
import re

with open('scripts/drik_2027_audit_results.json', 'r', encoding='utf-8') as f:
    drik = json.load(f)

for idx, d in enumerate(drik, 1):
    name = d['name']
    infos = d.get('infos', [])
    times = d.get('times', [])
    print(f"[{idx}] {name}")
    for i in infos:
        print(f"    Info: {i}")
    for t in times:
        print(f"    Time: {t}")
