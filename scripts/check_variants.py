import json

with open('scripts/drik_2027_audit_results.json', 'r', encoding='utf-8') as f:
    drik = json.load(f)

for d in drik:
    if d['name'] in ['Nirjala Ekadashi', 'Prabodhini Ekadashi', 'Rama Ekadashi', 'Kamika Ekadashi', 'Pausha Putrada Ekadashi']:
        print(f"=== {d['name']} ===")
        print("  Infos:", d.get('infos'))
        print("  Times:", d.get('times'))
