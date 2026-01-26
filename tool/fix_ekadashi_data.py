#!/usr/bin/env python3
"""
Script to process ekadashi_data_v2.json and create ekadashi_data.json with:
1. Only 2026 data (remove 2025 and 2027 entries)
2. Simplified IST cities to just ["India"]
3. Corrected IST dates for specific Ekadashis
"""

import json
from datetime import datetime, timedelta

# Load the source file
with open('assets/ekadashi_data_v2.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# Update metadata
data['date_range'] = {
    'start': '2026-01-01',
    'end': '2026-12-31'
}

# Simplify IST cities to just ["India"]
data['timezones']['IST']['cities'] = ['India']

# Date corrections for IST timezone only
# Format: (ekadashi_name, new_start_date, new_parana_date)
ist_corrections = {
    'Mohini Ekadashi': {
        'date': '2026-04-27',
        'fasting_start': '2026-04-27T05:36:00+05:30',
        'parana_start': '2026-04-28T05:35:00+05:30',
        'parana_end': '2026-04-28T09:47:00+05:30'
    },
    'Apara Ekadashi': {
        'date': '2026-05-13',
        'fasting_start': '2026-05-13T05:26:00+05:30',
        'parana_start': '2026-05-14T05:25:00+05:30',
        'parana_end': '2026-05-14T09:39:00+05:30'
    },
    'Prabodhini Ekadashi': {
        'date': '2026-10-22',
        'fasting_start': '2026-10-22T06:19:00+05:30',
        'parana_start': '2026-10-23T06:20:00+05:30',
        'parana_end': '2026-10-23T10:29:00+05:30'
    },
    'Utpanna Ekadashi': {
        'date': '2026-11-05',
        'fasting_start': '2026-11-05T06:26:00+05:30',
        'parana_start': '2026-11-06T06:27:00+05:30',
        'parana_end': '2026-11-06T10:35:00+05:30'
    },
    'Saphala Ekadashi': {
        'date': '2026-12-04',
        'fasting_start': '2026-12-04T06:44:00+05:30',
        'parana_start': '2026-12-05T06:45:00+05:30',
        'parana_end': '2026-12-05T10:49:00+05:30'
    },
    'Pausha Putrada Ekadashi': {
        'date': '2026-12-20',
        'fasting_start': '2026-12-20T06:54:00+05:30',
        'parana_start': '2026-12-21T06:55:00+05:30',
        'parana_end': '2026-12-21T10:57:00+05:30'
    }
}

# Filter ekadashis to only include 2026 dates and apply corrections
filtered_ekadashis = []
for ekadashi in data['ekadashis']:
    # Check if the IST date is in 2026
    ist_timing = ekadashi.get('timing', {}).get('IST', {})
    date_str = ist_timing.get('date', '')
    
    if date_str.startswith('2026'):
        # Apply IST corrections if this ekadashi needs it
        ekadashi_name = ekadashi.get('name', {}).get('en', '')
        if ekadashi_name in ist_corrections:
            correction = ist_corrections[ekadashi_name]
            ekadashi['timing']['IST'] = correction
            print(f"Corrected: {ekadashi_name} -> {correction['date']}")
        
        filtered_ekadashis.append(ekadashi)
        print(f"Kept 2026: {ekadashi_name} ({date_str})")
    else:
        print(f"Removed (not 2026): {ekadashi.get('name', {}).get('en', '')} ({date_str})")

data['ekadashis'] = filtered_ekadashis

# Renumber ids (1-based, sequential)
for i, ekadashi in enumerate(data['ekadashis'], 1):
    ekadashi['id'] = i

print(f"\nTotal Ekadashis retained: {len(filtered_ekadashis)}")

# Save the new file
with open('assets/ekadashi_data.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("\nDone! Created assets/ekadashi_data.json")
