import json

def main():
    with open('assets/ekadashi_data.json', 'r', encoding='utf-8') as f:
        d = json.load(f)
    e27 = [e for e in d['ekadashis'] if e['timing']['IST']['date'].startswith('2027')]
    print(f"Total 2027 events: {len(e27)}")
    for e in e27:
        ist = e['timing']['IST']
        has_var = e.get('has_tradition_variation', False)
        var_str = ''
        if has_var:
            variants = e.get('tradition_variants', {})
            var_str = ' | VARIANTS: ' + ', '.join([f"{k}: {v['timing']['IST']['date']} ({v['timing']['IST']['parana_start'][11:16]}-{v['timing']['IST']['parana_end'][11:16]})" for k, v in variants.items()])
        print(f"ID {e['id']}: {e['name']['en']:<24} | Date: {ist['date']} | Fast: {ist['fasting_start'][11:16]} | Parana: {ist['parana_start'][:10]} {ist['parana_start'][11:16]} - {ist['parana_end'][11:16]}{var_str}")

if __name__ == '__main__':
    main()
