import json

with open('assets/ekadashi_data.json', 'r', encoding='utf-8') as f:
    d = json.load(f)

for e in d['ekadashis']:
    eid = e['id']
    name = e['name']['en']
    date = e['timing']['IST']['date']
    tithi = e.get('tithi', {})
    has_var = e.get('has_tradition_variation', False)
    variants = e.get('tradition_variants', {})
    var_summary = {k: v.get('timing', {}).get('IST', {}).get('date') for k, v in variants.items()}
    if eid in [3, 13, 16, 21, 22, 23, 24, 25, 26, 29, 30, 32, 34, 36, 40, 45, 49]:
        print(f"ID {eid:2d}: {name:25} | IST Date: {date} | has_var: {has_var} | variants: {var_summary}")
        print(f"       tithi: {tithi}")
