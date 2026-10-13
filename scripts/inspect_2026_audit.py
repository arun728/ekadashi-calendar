import json

with open('scripts/drik_2026_audit_chennai.json', 'r', encoding='utf-8') as f:
    d2026 = json.load(f)

print(f"2026 Ekadashis in audit: {len(d2026)}")
for name, pairs in d2026.items():
    print(f"\n--- {name} ---")
    for info, time in pairs:
        print(f"  {info} | {time}")
