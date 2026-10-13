import json
import sys
from datetime import datetime

def validate_all():
    target_data_file = 'assets/ekadashi_data.json'
    with open(target_data_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    events = data.get('ekadashis', [])
    print(f"Validating {target_data_file} ({len(events)} events)...")

    assert len(events) == 49, f"Expected 49 events, found {len(events)}"
    assert data.get('date_range', {}).get('start') == '2026-01-01'
    assert data.get('date_range', {}).get('end') == '2027-12-31'

    seen_ids = set()
    seen_dates = set()
    errors = []

    required_keys = [
        'id', 'name', 'paksha', 'month', 'description', 'story',
        'fasting_rules', 'benefits', 'timing', 'tradition_tags',
        'region_tags', 'tradition_variants', 'has_tradition_variation'
    ]
    lang_keys = ['en', 'ta', 'hi', 'te']

    prev_date = None
    for idx, e in enumerate(events):
        eid = e.get('id')
        name_en = e.get('name', {}).get('en', f'Event #{idx}')

        if not isinstance(eid, int):
            errors.append(f"[{name_en}] ID must be int: {eid}")
        elif eid in seen_ids:
            errors.append(f"[{name_en}] Duplicate ID: {eid}")
        seen_ids.add(eid)

        for key in required_keys:
            if key not in e:
                errors.append(f"[{name_en}] Missing key '{key}'")

        for map_field in ['name', 'description', 'story', 'fasting_rules', 'benefits']:
            f_val = e.get(map_field)
            if not isinstance(f_val, dict):
                errors.append(f"[{name_en}] Field '{map_field}' is not dict")
            else:
                for l in lang_keys:
                    if not f_val.get(l) or not f_val.get(l).strip():
                        errors.append(f"[{name_en}] Missing/empty '{l}' in '{map_field}'")

        if e.get('paksha') not in ['shukla', 'krishna']:
            errors.append(f"[{name_en}] Invalid paksha: {e.get('paksha')}")

        ist = e.get('timing', {}).get('IST')
        if not ist:
            errors.append(f"[{name_en}] Missing IST timing")
        else:
            d_str = ist.get('date')
            if not d_str:
                errors.append(f"[{name_en}] Missing date in IST")
            if d_str in seen_dates:
                errors.append(f"[{name_en}] Duplicate IST date: {d_str}")
            seen_dates.add(d_str)

            dt_d = datetime.strptime(d_str, '%Y-%m-%d')
            if prev_date and dt_d <= prev_date:
                errors.append(f"[{name_en}] Dates not strictly chronological: {d_str} after {prev_date.strftime('%Y-%m-%d')}")
            prev_date = dt_d

            try:
                fs = datetime.fromisoformat(ist['fasting_start'])
                ps = datetime.fromisoformat(ist['parana_start'])
                pe = datetime.fromisoformat(ist['parana_end'])
                if ps <= fs:
                    errors.append(f"[{name_en}] parana_start <= fasting_start")
                if pe <= ps:
                    errors.append(f"[{name_en}] parana_end <= parana_start")
            except Exception as ex:
                errors.append(f"[{name_en}] ISO parse error: {ex}")

        if e.get('has_tradition_variation'):
            variants = e.get('tradition_variants', {})
            if 'smarta' not in variants or 'vaishnava' not in variants:
                errors.append(f"[{name_en}] has_tradition_variation is True but missing smarta or vaishnava")
            for t_k, t_v in variants.items():
                if 'timing' not in t_v or 'IST' not in t_v['timing']:
                    errors.append(f"[{name_en}] variant '{t_k}' missing IST timing")
                if 'fasting_rules' not in t_v:
                    errors.append(f"[{name_en}] variant '{t_k}' missing fasting_rules")

    if errors:
        print(f"FAILED with {len(errors)} error(s):")
        for err in errors:
            print(f"  [ERROR] {err}")
        sys.exit(1)
    else:
        print("SUCCESS: 0 errors found! All 49 events strictly valid, chronological, and schema-compliant.")

if __name__ == '__main__':
    validate_all()
