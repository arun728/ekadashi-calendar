import json
import shutil
import sys
from datetime import datetime

def merge_and_validate():
    target_data_file = 'assets/ekadashi_data.json'
    backup_file = 'assets/ekadashi_data.json.bak'
    staging_file = 'assets/ekadashi_2027_staging.json'

    print("Step 1: Creating verified backup of assets/ekadashi_data.json...")
    shutil.copy2(target_data_file, backup_file)
    print(f"Backed up to {backup_file}")

    # Load 2026 data
    with open(target_data_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Load 2027 staging data
    with open(staging_file, 'r', encoding='utf-8') as f:
        staging_data = json.load(f)

    existing_events = data.get('ekadashis', [])
    staging_events = staging_data.get('ekadashis', [])

    print(f"Current 2026 events count: {len(existing_events)}")
    print(f"Verified 2027 events count: {len(staging_events)}")

    # Pre-merge validation: IDs and Dates
    existing_ids = [e['id'] for e in existing_events]
    staging_ids = [e['id'] for e in staging_events]

    duplicate_ids = set(existing_ids).intersection(set(staging_ids))
    if duplicate_ids:
        raise ValueError(f"Duplicate IDs detected between 2026 and 2027: {duplicate_ids}")

    existing_dates = [e['timing']['IST']['date'] for e in existing_events]
    staging_dates = [e['timing']['IST']['date'] for e in staging_events]

    duplicate_dates = set(existing_dates).intersection(set(staging_dates))
    if duplicate_dates:
        raise ValueError(f"Duplicate IST dates detected: {duplicate_dates}")

    # Ensure all staging events are in 2027
    for e in staging_events:
        d = e['timing']['IST']['date']
        if not d.startswith('2027-'):
            raise ValueError(f"Event {e.get('name', {}).get('en')} has non-2027 date: {d}")

    # Ensure all existing events are in 2026
    for e in existing_events:
        d = e['timing']['IST']['date']
        if not d.startswith('2026-'):
            raise ValueError(f"Existing event {e.get('name', {}).get('en')} has non-2026 date: {d}")

    print("Step 2 & 3: Merging verified 2027 events while keeping 2026 events strictly unchanged...")
    merged_events = list(existing_events) + list(staging_events)

    # Update date_range.end
    data['date_range']['end'] = '2027-12-31'
    data['ekadashis'] = merged_events

    # Write merged data
    with open(target_data_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"Successfully wrote {len(merged_events)} events to {target_data_file}")

    # Also update root assets/ekadashi_data.json if root assets directory exists
    try:
        shutil.copy2(target_data_file, '../assets/ekadashi_data.json')
        shutil.copy2(backup_file, '../assets/ekadashi_data.json.bak')
        print("Synchronized root ../assets/ekadashi_data.json and backup.")
    except Exception as ex:
        print(f"Note: root assets update skipped or not needed: {ex}")

    # Post-merge schema validation
    print("\nStep 4: Running full schema validation on merged file...")
    with open(target_data_file, 'r', encoding='utf-8') as f:
        verified_data = json.load(f)

    all_events = verified_data['ekadashis']
    errors = []
    seen_ids = set()
    seen_dates = set()

    required_keys = [
        'id', 'name', 'paksha', 'month', 'description', 'story',
        'fasting_rules', 'benefits', 'timing', 'tradition_tags',
        'region_tags', 'tradition_variants', 'has_tradition_variation'
    ]
    lang_keys = ['en', 'ta', 'hi']

    prev_date = None
    for idx, e in enumerate(all_events):
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
        print(f"SUCCESS: All {len(all_events)} events passed full schema, ID uniqueness, date ordering, and timing checks!")
        print(f"date_range: {verified_data['date_range']}")

if __name__ == '__main__':
    merge_and_validate()
