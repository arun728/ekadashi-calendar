import json

def analyze():
    with open('scripts/drik_2027_audit_results.json', 'r', encoding='utf-8') as f:
        drik = json.load(f)

    with open('assets/ekadashi_data.json', 'r', encoding='utf-8') as f:
        data = json.load(f)

    e27 = [e for e in data['ekadashis'] if e['timing']['IST']['date'].startswith('2027')]

    print(f"Loaded {len(drik)} Drik records and {len(e27)} local 2027 events.\n")

    for d, loc in zip(drik, e27):
        print(f"=== {loc['id']}: {loc['name']['en']} ===")
        print("  Local Date:  ", loc['timing']['IST']['date'])
        print("  Local Fast:  ", loc['timing']['IST']['fasting_start'])
        print("  Local Parana:", loc['timing']['IST']['parana_start'], "to", loc['timing']['IST']['parana_end'])
        print("  Local HasVar:", loc.get('has_tradition_variation'), loc.get('tradition_variants', {}).keys())
        print("  Drik Infos:  ", d.get('infos'))
        print("  Drik Times:  ", d.get('times'))
        print()

if __name__ == '__main__':
    analyze()
