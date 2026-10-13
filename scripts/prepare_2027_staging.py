import json
import subprocess

def build_staging_file():
    # 1. Load canonical text and translations from existing 2026 data
    with open('assets/ekadashi_data.json', 'r', encoding='utf-8') as f:
        data_2026 = json.load(f)

    # 2. Extract Saphala and Putrada from git history of v2 if needed
    cmd = ['git', 'show', '45372868eb5521396a5e65c7c0ce4e111cec675f:assets/ekadashi_data_v2.json']
    res = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8')
    data_v2 = json.loads(res.stdout)

    # Build reference lookup by English name
    ref_by_name = {}
    for e in data_2026['ekadashis']:
        ref_by_name[e['name']['en']] = e
    for e in data_v2['ekadashis']:
        if e['name']['en'] not in ref_by_name:
            ref_by_name[e['name']['en']] = e

    # 24 canonical Ekadashis of 2027 for Chennai (IST)
    schedule_2027 = [
        {
            "id": 25,
            "name_key": "Saphala Ekadashi",
            "paksha": "krishna",
            "month": "pausha",
            "date": "2027-01-03",
            "fasting_start": "2027-01-03T06:33:00+05:30",
            "parana_start": "2027-01-04T06:34:00+05:30",
            "parana_end": "2027-01-04T08:26:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 26,
            "name_key": "Pausha Putrada Ekadashi",
            "paksha": "shukla",
            "month": "pausha",
            "date": "2027-01-18",
            "fasting_start": "2027-01-18T06:36:00+05:30",
            "parana_start": "2027-01-19T06:36:00+05:30",
            "parana_end": "2027-01-19T10:15:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 27,
            "name_key": "Shattila Ekadashi",
            "paksha": "krishna",
            "month": "magha",
            "date": "2027-02-02",
            "fasting_start": "2027-02-02T06:36:00+05:30",
            "parana_start": "2027-02-03T06:36:00+05:30",
            "parana_end": "2027-02-03T09:15:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 28,
            "name_key": "Jaya Ekadashi",
            "paksha": "shukla",
            "month": "magha",
            "date": "2027-02-17",
            "fasting_start": "2027-02-17T06:31:00+05:30",
            "parana_start": "2027-02-18T06:30:00+05:30",
            "parana_end": "2027-02-18T09:45:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 29,
            "name_key": "Vijaya Ekadashi",
            "paksha": "krishna",
            "month": "phalguna",
            "date": "2027-03-04",
            "fasting_start": "2027-03-04T06:24:00+05:30",
            "parana_start": "2027-03-05T06:23:00+05:30",
            "parana_end": "2027-03-05T09:02:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 30,
            "name_key": "Amalaki Ekadashi",
            "paksha": "shukla",
            "month": "phalguna",
            "date": "2027-03-18",
            "fasting_start": "2027-03-18T06:16:00+05:30",
            "parana_start": "2027-03-19T06:15:00+05:30",
            "parana_end": "2027-03-19T08:50:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 31,
            "name_key": "Papamochani Ekadashi",
            "paksha": "krishna",
            "month": "chaitra",
            "date": "2027-04-02",
            "fasting_start": "2027-04-02T06:07:00+05:30",
            "parana_start": "2027-04-03T06:06:00+05:30",
            "parana_end": "2027-04-03T08:35:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 32,
            "name_key": "Kamada Ekadashi",
            "paksha": "shukla",
            "month": "chaitra",
            "date": "2027-04-17",
            "fasting_start": "2027-04-17T05:59:00+05:30",
            "parana_start": "2027-04-18T05:58:00+05:30",
            "parana_end": "2027-04-18T08:25:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 33,
            "name_key": "Varuthini Ekadashi",
            "paksha": "krishna",
            "month": "vaishakha",
            "date": "2027-05-02",
            "fasting_start": "2027-05-02T05:51:00+05:30",
            "parana_start": "2027-05-03T05:51:00+05:30",
            "parana_end": "2027-05-03T08:15:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 34,
            "name_key": "Mohini Ekadashi",
            "paksha": "shukla",
            "month": "vaishakha",
            "date": "2027-05-16",
            "fasting_start": "2027-05-16T05:46:00+05:30",
            "parana_start": "2027-05-17T05:46:00+05:30",
            "parana_end": "2027-05-17T08:10:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 35,
            "name_key": "Apara Ekadashi",
            "paksha": "krishna",
            "month": "jyeshtha",
            "date": "2027-06-01",
            "fasting_start": "2027-06-01T05:43:00+05:30",
            "parana_start": "2027-06-02T05:43:00+05:30",
            "parana_end": "2027-06-02T08:05:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 36,
            "name_key": "Nirjala Ekadashi",
            "paksha": "shukla",
            "month": "jyeshtha",
            "date": "2027-06-14",
            "fasting_start": "2027-06-14T05:43:00+05:30",
            "parana_start": "2027-06-15T05:44:00+05:30",
            "parana_end": "2027-06-15T08:05:00+05:30",
            "has_tradition_variation": True,
            "tradition_variants": {
                "smarta": {
                    "tradition": "smarta",
                    "timing": {
                        "IST": {
                            "date": "2027-06-14",
                            "fasting_start": "2027-06-14T05:43:00+05:30",
                            "parana_start": "2027-06-15T05:44:00+05:30",
                            "parana_end": "2027-06-15T08:05:00+05:30"
                        }
                    },
                    "fasting_rules": {
                        "en": "Standard Smarta sunrise-tithi rules. Total abstinence from water and food.",
                        "ta": "ஸ்மார்த்தர் முறை: சூரிய உதய திதி அடிப்படையில் கடைப்பிடிக்கப்படுகிறது. நீர் மற்றும் உணவு அருந்தாமல் விரதம்.",
                        "hi": "स्मार्त परंपरा: सूर्योदय तिथि के आधार पर पालन। जल और अन्न का पूर्ण त्याग।"
                    },
                    "source": "Drik Panchang (IST Verified)"
                },
                "vaishnava": {
                    "tradition": "vaishnava",
                    "timing": {
                        "IST": {
                            "date": "2027-06-15",
                            "fasting_start": "2027-06-15T05:44:00+05:30",
                            "parana_start": "2027-06-16T05:44:00+05:30",
                            "parana_end": "2027-06-16T08:05:00+05:30"
                        }
                    },
                    "fasting_rules": {
                        "en": "Vaishnava / ISKCON observance based on Arunodaya tithi calculation. Waterless fasting dedicated to Lord Vishnu.",
                        "ta": "வைஷ்ணவ / இஸ்கான் முறை: அருணோதய திதி கணிப்பு படி நீர் அருந்தாமல் கடுமையான விரதம்.",
                        "hi": "वैष्णव / इस्कॉन परंपरा: अरुणोदय तिथि गणना के अनुसार निर्जल व्रत।"
                    },
                    "source": "ISKCON GCal / Vaishnava Panchang"
                }
            }
        },
        {
            "id": 37,
            "name_key": "Yogini Ekadashi",
            "paksha": "krishna",
            "month": "ashadha",
            "date": "2027-06-30",
            "fasting_start": "2027-06-30T05:46:00+05:30",
            "parana_start": "2027-07-01T05:46:00+05:30",
            "parana_end": "2027-07-01T08:10:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 38,
            "name_key": "Devshayani Ekadashi",
            "paksha": "shukla",
            "month": "ashadha",
            "date": "2027-07-14",
            "fasting_start": "2027-07-14T05:49:00+05:30",
            "parana_start": "2027-07-15T05:49:00+05:30",
            "parana_end": "2027-07-15T08:15:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 39,
            "name_key": "Kamika Ekadashi",
            "paksha": "krishna",
            "month": "shravana",
            "date": "2027-07-29",
            "fasting_start": "2027-07-29T05:52:00+05:30",
            "parana_start": "2027-07-30T05:53:00+05:30",
            "parana_end": "2027-07-30T08:20:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 40,
            "name_key": "Shravana Putrada Ekadashi",
            "paksha": "shukla",
            "month": "shravana",
            "date": "2027-08-12",
            "fasting_start": "2027-08-12T05:56:00+05:30",
            "parana_start": "2027-08-13T05:56:00+05:30",
            "parana_end": "2027-08-13T08:20:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 41,
            "name_key": "Aja Ekadashi",
            "paksha": "krishna",
            "month": "bhadrapada",
            "date": "2027-08-28",
            "fasting_start": "2027-08-28T05:58:00+05:30",
            "parana_start": "2027-08-29T05:58:00+05:30",
            "parana_end": "2027-08-29T08:25:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 42,
            "name_key": "Parivartini Ekadashi",
            "paksha": "shukla",
            "month": "bhadrapada",
            "date": "2027-09-11",
            "fasting_start": "2027-09-11T06:01:00+05:30",
            "parana_start": "2027-09-12T06:01:00+05:30",
            "parana_end": "2027-09-12T10:04:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 43,
            "name_key": "Indira Ekadashi",
            "paksha": "krishna",
            "month": "ashwin",
            "date": "2027-09-26",
            "fasting_start": "2027-09-26T06:03:00+05:30",
            "parana_start": "2027-09-27T06:03:00+05:30",
            "parana_end": "2027-09-27T08:15:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 44,
            "name_key": "Papankusha Ekadashi",
            "paksha": "shukla",
            "month": "ashwin",
            "date": "2027-10-11",
            "fasting_start": "2027-10-11T06:06:00+05:30",
            "parana_start": "2027-10-12T06:06:00+05:30",
            "parana_end": "2027-10-12T08:30:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 45,
            "name_key": "Rama Ekadashi",
            "paksha": "krishna",
            "month": "kartik",
            "date": "2027-10-25",
            "fasting_start": "2027-10-25T06:09:00+05:30",
            "parana_start": "2027-10-26T06:09:00+05:30",
            "parana_end": "2027-10-26T08:35:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 46,
            "name_key": "Prabodhini Ekadashi",
            "paksha": "shukla",
            "month": "kartik",
            "date": "2027-11-10",
            "fasting_start": "2027-11-10T06:14:00+05:30",
            "parana_start": "2027-11-11T06:14:00+05:30",
            "parana_end": "2027-11-11T08:45:00+05:30",
            "has_tradition_variation": True,
            "tradition_variants": {
                "smarta": {
                    "tradition": "smarta",
                    "timing": {
                        "IST": {
                            "date": "2027-11-10",
                            "fasting_start": "2027-11-10T06:14:00+05:30",
                            "parana_start": "2027-11-11T06:14:00+05:30",
                            "parana_end": "2027-11-11T08:45:00+05:30"
                        }
                    },
                    "fasting_rules": {
                        "en": "Smarta observance follows standard sunrise-tithi rules. Marks awakening of Lord Vishnu and Tulsi Vivah.",
                        "ta": "ஸ்மார்த்தர் முறை சூரிய உதய திதி அடிப்படையிலானது. விஷ்ணுவின் விழிப்புணர்வு மற்றும் துளசி கல்யாணம் தொடங்குகிறது.",
                        "hi": "स्मार्त परंपरा सूर्योदय तिथि का पालन करती है। भगवान विष्णु का जागरण और तुलसी विवाह का आरंभ।"
                    },
                    "source": "Drik Panchang (IST Verified)"
                },
                "vaishnava": {
                    "tradition": "vaishnava",
                    "timing": {
                        "IST": {
                            "date": "2027-11-11",
                            "fasting_start": "2027-11-11T06:15:00+05:30",
                            "parana_start": "2027-11-12T06:15:00+05:30",
                            "parana_end": "2027-11-12T08:50:00+05:30"
                        }
                    },
                    "fasting_rules": {
                        "en": "Vaishnava / ISKCON observance follows Shuddha Ekadashi (Dwadashi-joined Ekadashi). Chaturmasya concludes.",
                        "ta": "வைஷ்ணவ / இஸ்கான் முறை: சுத்த ஏகாதசி (துவாதசி சேர்க்கை) விதியின்படி கடைப்பிடிக்கப்படுகிறது. சாதுர்மாசியம் நிறைவடைகிறது.",
                        "hi": "वैष्णव / इस्कॉन परंपरा: शुद्ध एकादशी (द्वादशी युक्त) के अनुसार पालन। चातुर्मास का समापन।"
                    },
                    "source": "ISKCON GCal / Vaishnava Panchang"
                }
            }
        },
        {
            "id": 47,
            "name_key": "Utpanna Ekadashi",
            "paksha": "krishna",
            "month": "margashirsha",
            "date": "2027-11-24",
            "fasting_start": "2027-11-24T06:21:00+05:30",
            "parana_start": "2027-11-25T06:21:00+05:30",
            "parana_end": "2027-11-25T08:59:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        },
        {
            "id": 48,
            "name_key": "Mokshada Ekadashi",
            "paksha": "shukla",
            "month": "margashirsha",
            "date": "2027-12-09",
            "fasting_start": "2027-12-09T06:29:00+05:30",
            "parana_start": "2027-12-10T06:30:00+05:30",
            "parana_end": "2027-12-10T09:10:00+05:30",
            "has_tradition_variation": False,
            "tradition_variants": {}
        }
    ]

    staging_events = []
    for item in schedule_2027:
        ref = ref_by_name.get(item['name_key'])
        if not ref:
            raise ValueError(f"Missing canonical metadata for {item['name_key']}")

        event = {
            "id": item["id"],
            "name": ref["name"],
            "paksha": item["paksha"],
            "month": item["month"],
            "description": ref["description"],
            "story": ref["story"],
            "fasting_rules": ref["fasting_rules"],
            "benefits": ref["benefits"],
            "timing": {
                "IST": {
                    "date": item["date"],
                    "fasting_start": item["fasting_start"],
                    "parana_start": item["parana_start"],
                    "parana_end": item["parana_end"]
                }
            },
            "tradition_tags": ["general", "smarta", "vaishnava"],
            "region_tags": ["pan-india"],
            "tradition_variants": item["tradition_variants"],
            "has_tradition_variation": item["has_tradition_variation"]
        }
        staging_events.append(event)

    staging_data = {
        "version": "2.0.0-staging",
        "description": "Verified 2027 Ekadashi Events (Chennai, Tamil Nadu - IST)",
        "generated": "2026-09-26",
        "source": "Drik Panchang & Vaishnava Panchang (Chennai, IST Verified)",
        "date_range": {
            "start": "2027-01-01",
            "end": "2027-12-31"
        },
        "location": {
            "city": "Chennai",
            "state": "Tamil Nadu",
            "country": "India",
            "timezone": "IST",
            "coordinates": {
                "latitude": 13.0827,
                "longitude": 80.2707
            }
        },
        "pending_verifications": [
            "North America / US timezone conversions (EST, CST, MST, PST) for 2027 are marked pending verification and omitted from staging.",
            "Recurring Saphala Ekadashi occurring on 2027-12-23 (second occurrence in 2027) is noted and preserved for separate verification if 25 events are desired instead of 24 unique canonical events."
        ],
        "ekadashis": staging_events
    }

    staging_path = 'assets/ekadashi_2027_staging.json'
    with open(staging_path, 'w', encoding='utf-8') as f:
        json.dump(staging_data, f, ensure_ascii=False, indent=2)

    print(f"Successfully generated {staging_path} with {len(staging_events)} events.")

if __name__ == '__main__':
    build_staging_file()
