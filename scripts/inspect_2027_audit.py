import json

with open('scripts/drik_2027_audit_results.json', 'r', encoding='utf-8') as f:
    d2027 = json.load(f)

print(f"2027 Ekadashis in Drik audit: {len(d2027)}")
for item in d2027:
    name = item.get('name')
    infos = item.get('infos', [])
    times = item.get('times', [])
    print(f"\n--- {name} ---")
    for i, t in zip(infos, times):
        print(f"  {i} | {t}")
    if len(infos) > len(times):
        for rem in infos[len(times):]:
            print(f"  [extra info]: {rem}")
