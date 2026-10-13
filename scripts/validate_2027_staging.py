import json
from datetime import datetime

def validate_staging():
    staging_path = 'assets/ekadashi_2027_staging.json'
    with open(staging_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    events = data.get('ekadashis', [])
    errors = []
    warnings = []
    
    print(f"=== Validating {staging_path} ===")
    print(f"Total events found: {len(events)}")
    
    if len(events) != 24:
        warnings.append(f"Expected 24 events, found {len(events)}")

    seen_ids = set()
    seen_dates = set()

    required_keys = [
        'id', 'name', 'paksha', 'month', 'description', 'story',
        'fasting_rules', 'benefits', 'timing', 'tradition_tags',
        'region_tags', 'tradition_variants', 'has_tradition_variation'
    ]
    lang_keys = ['en', 'ta', 'hi']

    for idx, e in enumerate(events):
        eid = e.get('id')
        name_en = e.get('name', {}).get('en', f'Event #{idx}')

        # 1. Check ID uniqueness & format
        if not isinstance(eid, int):
            errors.append(f"[{name_en}] ID must be an integer, got: {eid}")
        elif eid in seen_ids:
            errors.append(f"[{name_en}] Duplicate ID found: {eid}")
        seen_ids.add(eid)

        # 2. Check required top-level event keys
        for key in required_keys:
            if key not in e:
                errors.append(f"[{name_en}] Missing required key: '{key}'")

        # 3. Check language maps
        for map_field in ['name', 'description', 'story', 'fasting_rules', 'benefits']:
            f_val = e.get(map_field)
            if not isinstance(f_val, dict):
                errors.append(f"[{name_en}] Field '{map_field}' must be a dictionary, got: {type(f_val)}")
            else:
                for lang in lang_keys:
                    if not f_val.get(lang) or not isinstance(f_val.get(lang), str) or not f_val.get(lang).strip():
                        errors.append(f"[{name_en}] Missing or empty '{lang}' text in '{map_field}'")

        # 4. Check paksha
        if e.get('paksha') not in ['shukla', 'krishna']:
            errors.append(f"[{name_en}] Invalid paksha: {e.get('paksha')}")

        # 5. Check month
        if not e.get('month') or not isinstance(e.get('month'), str):
            errors.append(f"[{name_en}] Missing or invalid month: {e.get('month')}")

        # 6. Check timing (Chennai / IST)
        timing = e.get('timing', {})
        if 'IST' not in timing:
            errors.append(f"[{name_en}] Missing 'IST' timing block")
        else:
            ist = timing['IST']
            date_str = ist.get('date')
            fast_start_str = ist.get('fasting_start')
            par_start_str = ist.get('parana_start')
            par_end_str = ist.get('parana_end')

            if not date_str or not date_str.startswith('2027-'):
                errors.append(f"[{name_en}] Invalid or non-2027 date: {date_str}")
            if date_str in seen_dates:
                warnings.append(f"[{name_en}] Duplicate IST date found: {date_str}")
            seen_dates.add(date_str)

            try:
                dt_fast_start = datetime.fromisoformat(fast_start_str)
                dt_par_start = datetime.fromisoformat(par_start_str)
                dt_par_end = datetime.fromisoformat(par_end_str)

                if dt_par_start <= dt_fast_start:
                    errors.append(f"[{name_en}] Parana start ({par_start_str}) must be after fasting start ({fast_start_str})")
                if dt_par_end <= dt_par_start:
                    errors.append(f"[{name_en}] Parana end ({par_end_str}) must be after parana start ({par_start_str})")
            except Exception as ex:
                errors.append(f"[{name_en}] ISO datetime parse error in IST timing: {ex}")

        # 7. Check tradition variants
        has_var = e.get('has_tradition_variation', False)
        variants = e.get('tradition_variants', {})
        if has_var:
            if not variants or ('smarta' not in variants and 'vaishnava' not in variants):
                errors.append(f"[{name_en}] has_tradition_variation is True but variants missing smarta/vaishnava")
            for t_key, t_val in variants.items():
                if 'timing' not in t_val or 'IST' not in t_val['timing']:
                    errors.append(f"[{name_en}] Variant '{t_key}' missing IST timing block")
                if 'fasting_rules' not in t_val:
                    errors.append(f"[{name_en}] Variant '{t_key}' missing fasting_rules")

    print("\n--- Validation Results ---")
    if errors:
        print(f"FAILED: {len(errors)} error(s) detected:")
        for err in errors:
            print(f"  [ERROR] {err}")
    else:
        print("SUCCESS: 0 schema or timing errors found! All 24 events strictly adhere to EkadashiEvent contract.")

    if warnings:
        print(f"Warnings ({len(warnings)}):")
        for w in warnings:
            print(f"  [WARN] {w}")
    else:
        print("0 warnings.")

if __name__ == '__main__':
    validate_staging()
