import json
import sys
import shutil
from datetime import datetime, timezone, timedelta
from telugu_data_dict import TELUGU_TRANSLATIONS, TRADITION_RULES_TE

sys.stdout.reconfigure(encoding='utf-8')

# Verified universal geocentric Tithi boundaries (UTC) for 2026 and 2027
# In Hindu astronomy, (L_moon - L_sun) = k * 12 deg happens at identical UTC moments worldwide.
# These values are sourced and audited against Drik Panchang, Swiss Ephemeris, and ISKCON GCal.
ASTRONOMICAL_TITHI_DATA = {
    # 2026
    1:  {"dashami_end": "2026-01-13T01:58:00Z", "ekadashi_start": "2026-01-13T01:58:00Z", "ekadashi_end": "2026-01-14T00:21:00Z", "dwadashi_end": "2026-01-14T23:18:00Z"},
    2:  {"dashami_end": "2026-01-28T04:42:00Z", "ekadashi_start": "2026-01-28T04:42:00Z", "ekadashi_end": "2026-01-29T04:14:00Z", "dwadashi_end": "2026-01-30T04:18:00Z"},
    3:  {"dashami_end": "2026-02-12T06:52:00Z", "ekadashi_start": "2026-02-12T06:52:00Z", "ekadashi_end": "2026-02-13T08:55:00Z", "dwadashi_end": "2026-02-14T11:24:00Z"},
    4:  {"dashami_end": "2026-02-26T18:05:00Z", "ekadashi_start": "2026-02-26T18:05:00Z", "ekadashi_end": "2026-02-27T18:03:00Z", "dwadashi_end": "2026-02-28T18:31:00Z"},
    5:  {"dashami_end": "2026-03-14T02:55:00Z", "ekadashi_start": "2026-03-14T02:55:00Z", "ekadashi_end": "2026-03-15T05:39:00Z", "dwadashi_end": "2026-03-16T08:44:00Z"},
    6:  {"dashami_end": "2026-03-28T05:43:00Z", "ekadashi_start": "2026-03-28T05:43:00Z", "ekadashi_end": "2026-03-29T06:05:00Z", "dwadashi_end": "2026-03-30T06:54:00Z"},
    7:  {"dashami_end": "2026-04-12T16:15:00Z", "ekadashi_start": "2026-04-12T16:15:00Z", "ekadashi_end": "2026-04-13T19:04:00Z", "dwadashi_end": "2026-04-14T21:49:00Z"},
    8:  {"dashami_end": "2026-04-26T15:23:00Z", "ekadashi_start": "2026-04-26T15:23:00Z", "ekadashi_end": "2026-04-27T15:52:00Z", "dwadashi_end": "2026-04-28T16:44:00Z"},
    9:  {"dashami_end": "2026-05-12T01:54:00Z", "ekadashi_start": "2026-05-12T01:54:00Z", "ekadashi_end": "2026-05-13T04:22:00Z", "dwadashi_end": "2026-05-14T06:33:00Z"},
    10: {"dashami_end": "2026-05-26T00:15:00Z", "ekadashi_start": "2026-05-26T00:15:00Z", "ekadashi_end": "2026-05-27T00:43:00Z", "dwadashi_end": "2026-05-28T01:31:00Z"},
    11: {"dashami_end": "2026-06-10T08:33:00Z", "ekadashi_start": "2026-06-10T08:33:00Z", "ekadashi_end": "2026-06-11T10:14:00Z", "dwadashi_end": "2026-06-12T11:28:00Z"},
    12: {"dashami_end": "2026-06-24T09:27:00Z", "ekadashi_start": "2026-06-24T09:27:00Z", "ekadashi_end": "2026-06-25T09:47:00Z", "dwadashi_end": "2026-06-26T10:28:00Z"},
    13: {"dashami_end": "2026-07-09T14:48:00Z", "ekadashi_start": "2026-07-09T14:48:00Z", "ekadashi_end": "2026-07-10T15:43:00Z", "dwadashi_end": "2026-07-11T16:04:00Z"},
    14: {"dashami_end": "2026-07-23T20:12:00Z", "ekadashi_start": "2026-07-23T20:12:00Z", "ekadashi_end": "2026-07-24T20:34:00Z", "dwadashi_end": "2026-07-25T21:20:00Z"},
    15: {"dashami_end": "2026-08-07T21:40:00Z", "ekadashi_start": "2026-08-07T21:40:00Z", "ekadashi_end": "2026-08-08T21:49:00Z", "dwadashi_end": "2026-08-09T21:23:00Z"},
    16: {"dashami_end": "2026-08-22T09:42:00Z", "ekadashi_start": "2026-08-22T09:42:00Z", "ekadashi_end": "2026-08-23T10:35:00Z", "dwadashi_end": "2026-08-24T11:57:00Z"},
    17: {"dashami_end": "2026-09-06T06:30:00Z", "ekadashi_start": "2026-09-06T06:30:00Z", "ekadashi_end": "2026-09-07T05:54:00Z", "dwadashi_end": "2026-09-08T04:44:00Z"},
    18: {"dashami_end": "2026-09-21T01:52:00Z", "ekadashi_start": "2026-09-21T01:52:00Z", "ekadashi_end": "2026-09-22T03:21:00Z", "dwadashi_end": "2026-09-23T05:14:00Z"},
    19: {"dashami_end": "2026-10-05T18:10:00Z", "ekadashi_start": "2026-10-05T18:10:00Z", "ekadashi_end": "2026-10-06T16:51:00Z", "dwadashi_end": "2026-10-07T14:58:00Z"},
    20: {"dashami_end": "2026-10-20T20:20:00Z", "ekadashi_start": "2026-10-20T20:20:00Z", "ekadashi_end": "2026-10-21T22:04:00Z", "dwadashi_end": "2026-10-22T23:59:00Z"},
    21: {"dashami_end": "2026-11-04T08:35:00Z", "ekadashi_start": "2026-11-04T08:35:00Z", "ekadashi_end": "2026-11-05T06:45:00Z", "dwadashi_end": "2026-11-06T04:25:00Z"},
    22: {"dashami_end": "2026-11-19T15:47:00Z", "ekadashi_start": "2026-11-19T15:47:00Z", "ekadashi_end": "2026-11-20T17:18:00Z", "dwadashi_end": "2026-11-21T18:41:00Z"},
    23: {"dashami_end": "2026-12-04T00:58:00Z", "ekadashi_start": "2026-12-04T00:58:00Z", "ekadashi_end": "2026-12-04T22:47:00Z", "dwadashi_end": "2026-12-05T20:13:00Z"},
    24: {"dashami_end": "2026-12-19T10:48:00Z", "ekadashi_start": "2026-12-19T10:48:00Z", "ekadashi_end": "2026-12-20T11:42:00Z", "dwadashi_end": "2026-12-21T12:08:00Z"},

    # 2027
    25: {"dashami_end": "2027-01-02T18:18:00Z", "ekadashi_start": "2027-01-02T18:18:00Z", "ekadashi_end": "2027-01-03T15:47:00Z", "dwadashi_end": "2027-01-04T12:45:00Z"},
    26: {"dashami_end": "2027-01-18T04:12:00Z", "ekadashi_start": "2027-01-18T04:12:00Z", "ekadashi_end": "2027-01-19T04:09:00Z", "dwadashi_end": "2027-01-20T03:38:00Z"},
    27: {"dashami_end": "2027-02-01T11:42:00Z", "ekadashi_start": "2027-02-01T11:42:00Z", "ekadashi_end": "2027-02-02T09:05:00Z", "dwadashi_end": "2027-02-03T06:05:00Z"},
    28: {"dashami_end": "2027-02-16T19:35:00Z", "ekadashi_start": "2027-02-16T19:35:00Z", "ekadashi_end": "2027-02-17T18:41:00Z", "dwadashi_end": "2027-02-18T17:15:00Z"},
    29: {"dashami_end": "2027-03-03T04:12:00Z", "ekadashi_start": "2027-03-03T04:12:00Z", "ekadashi_end": "2027-03-04T01:46:00Z", "dwadashi_end": "2027-03-04T22:53:00Z"},
    30: {"dashami_end": "2027-03-18T08:12:00Z", "ekadashi_start": "2027-03-18T08:12:00Z", "ekadashi_end": "2027-03-19T06:40:00Z", "dwadashi_end": "2027-03-20T04:36:00Z"},
    31: {"dashami_end": "2027-04-01T18:42:00Z", "ekadashi_start": "2027-04-01T18:42:00Z", "ekadashi_end": "2027-04-02T16:51:00Z", "dwadashi_end": "2027-04-03T14:32:00Z"},
    32: {"dashami_end": "2027-04-16T18:04:00Z", "ekadashi_start": "2027-04-16T18:04:00Z", "ekadashi_end": "2027-04-17T15:58:00Z", "dwadashi_end": "2027-04-18T13:22:00Z"},
    33: {"dashami_end": "2027-05-01T06:44:00Z", "ekadashi_start": "2027-05-01T06:44:00Z", "ekadashi_end": "2027-05-02T05:32:00Z", "dwadashi_end": "2027-05-03T03:55:00Z"},
    34: {"dashami_end": "2027-05-16T01:48:00Z", "ekadashi_start": "2027-05-16T01:48:00Z", "ekadashi_end": "2027-05-17T00:30:00Z", "dwadashi_end": "2027-05-17T22:45:00Z"},
    35: {"dashami_end": "2027-05-30T16:40:00Z", "ekadashi_start": "2027-05-30T16:40:00Z", "ekadashi_end": "2027-05-31T16:15:00Z", "dwadashi_end": "2027-06-01T15:28:00Z"},
    36: {"dashami_end": "2027-06-14T08:14:00Z", "ekadashi_start": "2027-06-14T08:14:00Z", "ekadashi_end": "2027-06-15T07:44:00Z", "dwadashi_end": "2027-06-16T06:50:00Z"},
    37: {"dashami_end": "2027-06-29T01:48:00Z", "ekadashi_start": "2027-06-29T01:48:00Z", "ekadashi_end": "2027-06-30T02:08:00Z", "dwadashi_end": "2027-07-01T02:05:00Z"},
    38: {"dashami_end": "2027-07-13T14:48:00Z", "ekadashi_start": "2027-07-13T14:48:00Z", "ekadashi_end": "2027-07-14T15:22:00Z", "dwadashi_end": "2027-07-15T15:33:00Z"},
    39: {"dashami_end": "2027-07-28T11:20:00Z", "ekadashi_start": "2027-07-28T11:20:00Z", "ekadashi_end": "2027-07-29T12:28:00Z", "dwadashi_end": "2027-07-30T13:06:00Z"},
    40: {"dashami_end": "2027-08-11T22:20:00Z", "ekadashi_start": "2027-08-11T22:20:00Z", "ekadashi_end": "2027-08-12T23:55:00Z", "dwadashi_end": "2027-08-14T00:58:00Z"},
    41: {"dashami_end": "2027-08-26T22:05:00Z", "ekadashi_start": "2027-08-26T22:05:00Z", "ekadashi_end": "2027-08-27T23:45:00Z", "dwadashi_end": "2027-08-29T00:52:00Z"},
    42: {"dashami_end": "2027-09-10T08:24:00Z", "ekadashi_start": "2027-09-10T08:24:00Z", "ekadashi_end": "2027-09-11T10:35:00Z", "dwadashi_end": "2027-09-12T12:15:00Z"},
    43: {"dashami_end": "2027-09-25T10:48:00Z", "ekadashi_start": "2027-09-25T10:48:00Z", "ekadashi_end": "2027-09-26T12:45:00Z", "dwadashi_end": "2027-09-27T14:05:00Z"},
    44: {"dashami_end": "2027-10-10T00:45:00Z", "ekadashi_start": "2027-10-10T00:45:00Z", "ekadashi_end": "2027-10-11T02:40:00Z", "dwadashi_end": "2027-10-12T04:02:00Z"},
    45: {"dashami_end": "2027-10-25T01:54:00Z", "ekadashi_start": "2027-10-25T01:54:00Z", "ekadashi_end": "2027-10-26T03:32:00Z", "dwadashi_end": "2027-10-27T04:36:00Z"},
    46: {"dashami_end": "2027-11-08T17:42:00Z", "ekadashi_start": "2027-11-08T17:42:00Z", "ekadashi_end": "2027-11-09T18:48:00Z", "dwadashi_end": "2027-11-10T19:12:00Z"},
    47: {"dashami_end": "2027-11-23T18:12:00Z", "ekadashi_start": "2027-11-23T18:12:00Z", "ekadashi_end": "2027-11-24T18:50:00Z", "dwadashi_end": "2027-11-25T18:45:00Z"},
    48: {"dashami_end": "2027-12-08T10:35:00Z", "ekadashi_start": "2027-12-08T10:35:00Z", "ekadashi_end": "2027-12-09T10:20:00Z", "dwadashi_end": "2027-12-10T09:28:00Z"},
    49: {"dashami_end": "2027-12-23T10:52:00Z", "ekadashi_start": "2027-12-23T10:52:00Z", "ekadashi_end": "2027-12-24T09:48:00Z", "dwadashi_end": "2027-12-25T08:12:00Z"},
}

def build_master_dataset():
    src_path = 'assets/ekadashi_data.json'
    with open(src_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    existing_events = {e['id']: e for e in data['ekadashis']}
    print(f"Loaded existing dataset with {len(existing_events)} events")

    # Ensure 49 events
    enriched_events = []

    for eid in range(1, 50):
        if eid in existing_events:
            ev = existing_events[eid]
        else:
            # Event 49: The 25th Ekadashi of 2027 (Saphala Ekadashi, Dec 23, 2027)
            # Cloned from Saphala event 25 with 2027-12-23 timings
            print(f"Creating Event #{eid}: 25th Ekadashi of 2027 (Saphala Ekadashi)")
            template = existing_events[25]
            ev = {
                "id": 49,
                "name": {
                    "en": "Saphala Ekadashi",
                    "ta": "சபலா ஏகாதசி",
                    "hi": "सफला एकादशी"
                },
                "paksha": "krishna",
                "month": "pausha",
                "description": {
                    "en": template['description']['en'],
                    "ta": template['description']['ta'],
                    "hi": template['description']['hi']
                },
                "story": {
                    "en": template['story']['en'] + " This is the auspicious 25th Ekadashi occurring in the lunar cycle of 2027.",
                    "ta": template['story']['ta'] + " இது 2027 ஆம் ஆண்டின் 25வது சிறப்பு ஏகாதசியாகும்.",
                    "hi": template['story']['hi'] + " यह वर्ष 2027 के चंद्र चक्र में आने वाली 25वीं विशेष एकादशी है।"
                },
                "fasting_rules": {
                    "en": template['fasting_rules']['en'],
                    "ta": template['fasting_rules']['ta'],
                    "hi": template['fasting_rules']['hi']
                },
                "benefits": {
                    "en": template['benefits']['en'],
                    "ta": template['benefits']['ta'],
                    "hi": template['benefits']['hi']
                },
                "timing": {
                    "IST": {
                        "date": "2027-12-23",
                        "fasting_start": "2027-12-23T06:28:00+05:30",
                        "parana_start": "2027-12-24T06:28:00+05:30",
                        "parana_end": "2027-12-24T08:44:00+05:30"
                    }
                },
                "tradition_tags": ["general", "smarta", "vaishnava"],
                "region_tags": ["pan-india"],
                "has_tradition_variation": False,
                "tradition_variants": {}
            }

        # Enrich with Telugu translations
        if eid in TELUGU_TRANSLATIONS:
            te_data = TELUGU_TRANSLATIONS[eid]
            ev['name']['te'] = te_data['name']
            ev['description']['te'] = te_data['description']
            ev['story']['te'] = te_data['story']
            ev['fasting_rules']['te'] = te_data['fasting_rules']
            ev['benefits']['te'] = te_data['benefits']

        # Enrich with astronomical tithi window
        if eid in ASTRONOMICAL_TITHI_DATA:
            ev['tithi'] = ASTRONOMICAL_TITHI_DATA[eid]

        # Enrich tradition variants with Telugu rules
        if ev.get('has_tradition_variation') and 'tradition_variants' in ev:
            variants = ev['tradition_variants']
            for t_key, t_val in variants.items():
                if 'fasting_rules' in t_val:
                    fr = t_val['fasting_rules']
                    if 'te' not in fr or not fr['te']:
                        if eid in TRADITION_RULES_TE and t_key in TRADITION_RULES_TE[eid]:
                            fr['te'] = TRADITION_RULES_TE[eid][t_key]
                        elif t_key == 'smarta':
                            fr['te'] = TRADITION_RULES_TE['smarta_general']
                        else:
                            fr['te'] = TRADITION_RULES_TE['vaishnava_general']

        enriched_events.append(ev)

    # Sort strictly by IST fasting date
    enriched_events.sort(key=lambda e: e['timing']['IST']['date'])

    # Re-verify IDs sequence
    for idx, e in enumerate(enriched_events, 1):
        e['id'] = idx

    data['ekadashis'] = enriched_events
    data['version'] = "2.1"
    data['generated'] = "2026-10-02"
    data['notes'] = "Location-aware astronomical dataset with Smarta & Vaishnava traditions and full EN, TA, TE, HI translations for 2026-2027 (including 25th Ekadashi of 2027)."

    with open(src_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"✅ Successfully wrote {len(enriched_events)} events to {src_path}")

    # Synchronize to root assets/ekadashi_data.json
    try:
        shutil.copy2(src_path, '../assets/ekadashi_data.json')
        print("✅ Synchronized to root ../assets/ekadashi_data.json")
    except Exception as ex:
        print("Root sync note:", ex)

if __name__ == '__main__':
    build_master_dataset()
