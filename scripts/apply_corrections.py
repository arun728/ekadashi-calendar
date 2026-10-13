import json
import os
import shutil

src_file = 'assets/ekadashi_data.json'
parent_file = r'c:\Users\sakth\OneDrive\Desktop\ekadhesi calendar\assets\ekadashi_data.json'

with open(src_file, 'r', encoding='utf-8') as f:
    data = json.load(f)

events = data['ekadashis']
event_map = {e['id']: e for e in events}

# 1. Update 2026 Events:
# Event 3: Vijaya Ekadashi (Same day: 2026-02-13)
e3 = event_map[3]
e3['has_tradition_variation'] = False
e3['tradition_variants'] = {}

# Event 13: Yogini Ekadashi (Differs: Smarta 2026-07-10, Vaishnava 2026-07-11)
e13 = event_map[13]
e13['has_tradition_variation'] = True
e13['tradition_variants'] = {
    "smarta": {
        "tradition": "smarta",
        "timing": {
            "IST": {
                "date": "2026-07-10",
                "fasting_start": "2026-07-10T05:49:00+05:30",
                "parana_start": "2026-07-11T05:49:00+05:30",
                "parana_end": "2026-07-11T08:23:00+05:30"
            },
            "EST": {
                "date": "2026-07-10",
                "fasting_start": "2026-07-10T05:34:00-05:00",
                "parana_start": "2026-07-11T05:35:00-05:00",
                "parana_end": "2026-07-11T10:06:00-05:00"
            },
            "CST": {
                "date": "2026-07-10",
                "fasting_start": "2026-07-10T05:36:00-06:00",
                "parana_start": "2026-07-11T05:36:00-06:00",
                "parana_end": "2026-07-11T10:06:00-06:00"
            },
            "MST": {
                "date": "2026-07-10",
                "fasting_start": "2026-07-10T05:38:00-07:00",
                "parana_start": "2026-07-11T05:39:00-07:00",
                "parana_end": "2026-07-11T10:06:00-07:00"
            },
            "PST": {
                "date": "2026-07-10",
                "fasting_start": "2026-07-10T05:40:00-08:00",
                "parana_start": "2026-07-11T05:41:00-08:00",
                "parana_end": "2026-07-11T10:06:00-08:00"
            }
        },
        "fasting_rules": {
            "en": "Smarta observance follows standard sunrise-tithi rules on Friday, July 10.",
            "ta": "ஸ்மார்த்த முறை சூரிய உதய திதி அடிப்படையில் வெள்ளிக்கிழமை, ஜூலை 10 அன்று கடைப்பிடிக்கப்படுகிறது.",
            "hi": "स्मार्त परंपरा सूर्योदय तिथि के अनुसार शुक्रवार, 10 जुलाई को व्रत रखती है।",
            "te": "స్మార్త సంప్రదాయం ప్రకారం సూర్యోదయ తిథి ఆధారంగా శుక్రవారం, జూలై 10న ఉపవాసం ఆచరించాలి."
        },
        "source": "Reference Workbook / Drik Panchang"
    },
    "vaishnava": {
        "tradition": "vaishnava",
        "timing": {
            "IST": {
                "date": "2026-07-11",
                "fasting_start": "2026-07-11T05:49:00+05:30",
                "parana_start": "2026-07-12T05:50:00+05:30",
                "parana_end": "2026-07-12T08:24:00+05:30"
            },
            "EST": {
                "date": "2026-07-11",
                "fasting_start": "2026-07-11T05:35:00-05:00",
                "parana_start": "2026-07-12T05:36:00-05:00",
                "parana_end": "2026-07-12T10:07:00-05:00"
            },
            "CST": {
                "date": "2026-07-11",
                "fasting_start": "2026-07-11T05:36:00-06:00",
                "parana_start": "2026-07-12T05:37:00-06:00",
                "parana_end": "2026-07-12T10:07:00-06:00"
            },
            "MST": {
                "date": "2026-07-11",
                "fasting_start": "2026-07-11T05:39:00-07:00",
                "parana_start": "2026-07-12T05:40:00-07:00",
                "parana_end": "2026-07-12T10:07:00-07:00"
            },
            "PST": {
                "date": "2026-07-11",
                "fasting_start": "2026-07-11T05:41:00-08:00",
                "parana_start": "2026-07-12T05:42:00-08:00",
                "parana_end": "2026-07-12T10:07:00-08:00"
            }
        },
        "fasting_rules": {
            "en": "Vaishnava observance on Saturday, July 11, following strict Dashami-Vedha avoidance and Shuddha Ekadashi purity rules.",
            "ta": "வைணவ மரபில் தசமி கலவாத சுத்த ஏகாதசி சனிக்கிழமை, ஜூலை 11 அன்று கடைப்பிடிக்கப்படுகிறது.",
            "hi": "वैष्णव परंपरा दशमी-वेध से मुक्त शुद्ध एकादशी शनिवार, 11 जुलाई को व्रत रखती है।",
            "te": "వైష్ణవ సంప్రదాయం ప్రకారం దశమీ వేధ రహిత శుద్ధ ఏకాదశి శనివారం, జూలై 11న ఆచరించాలి."
        },
        "source": "Reference Workbook / ISKCON List"
    }
}

# Event 16: Shravana Putrada Ekadashi (Differs: Smarta 2026-08-23, Vaishnava 2026-08-24)
e16 = event_map[16]
e16['has_tradition_variation'] = True
e16['tradition_variants'] = {
    "smarta": {
        "tradition": "smarta",
        "timing": {
            "IST": {
                "date": "2026-08-23",
                "fasting_start": "2026-08-23T05:57:00+05:30",
                "parana_start": "2026-08-24T05:57:00+05:30",
                "parana_end": "2026-08-24T06:20:00+05:30"
            },
            "EST": {
                "date": "2026-08-23",
                "fasting_start": "2026-08-23T06:15:00-05:00",
                "parana_start": "2026-08-24T06:16:00-05:00",
                "parana_end": "2026-08-24T10:14:00-05:00"
            },
            "CST": {
                "date": "2026-08-23",
                "fasting_start": "2026-08-23T06:17:00-06:00",
                "parana_start": "2026-08-24T06:18:00-06:00",
                "parana_end": "2026-08-24T10:14:00-06:00"
            },
            "MST": {
                "date": "2026-08-23",
                "fasting_start": "2026-08-23T06:20:00-07:00",
                "parana_start": "2026-08-24T06:21:00-07:00",
                "parana_end": "2026-08-24T10:14:00-07:00"
            },
            "PST": {
                "date": "2026-08-23",
                "fasting_start": "2026-08-23T06:22:00-08:00",
                "parana_start": "2026-08-24T06:23:00-08:00",
                "parana_end": "2026-08-24T10:14:00-08:00"
            }
        },
        "fasting_rules": {
            "en": "Smarta observance on Sunday, August 23, when Ekadashi tithi is present at sunrise.",
            "ta": "ஸ்மார்த்த முறை சூரிய உதய திதி அடிப்படையில் ஞாயிறு, ஆகஸ்ட் 23 அன்று கடைப்பிடிக்கப்படுகிறது.",
            "hi": "स्मार्त परंपरा सूर्योदय तिथि के अनुसार रविवार, 23 अगस्त को व्रत रखती है।",
            "te": "స్మార్త సంప్రదాయం ప్రకారం ఆదివారం, ఆగస్టు 23న వ్రతం ఆచరించాలి."
        },
        "source": "Reference Workbook / Drik Panchang"
    },
    "vaishnava": {
        "tradition": "vaishnava",
        "timing": {
            "IST": {
                "date": "2026-08-24",
                "fasting_start": "2026-08-24T05:57:00+05:30",
                "parana_start": "2026-08-25T05:58:00+05:30",
                "parana_end": "2026-08-25T08:26:00+05:30"
            },
            "EST": {
                "date": "2026-08-24",
                "fasting_start": "2026-08-24T06:16:00-05:00",
                "parana_start": "2026-08-25T06:17:00-05:00",
                "parana_end": "2026-08-25T10:15:00-05:00"
            },
            "CST": {
                "date": "2026-08-24",
                "fasting_start": "2026-08-24T06:18:00-06:00",
                "parana_start": "2026-08-25T06:19:00-06:00",
                "parana_end": "2026-08-25T10:15:00-06:00"
            },
            "MST": {
                "date": "2026-08-24",
                "fasting_start": "2026-08-24T06:21:00-07:00",
                "parana_start": "2026-08-25T06:22:00-07:00",
                "parana_end": "2026-08-25T10:15:00-07:00"
            },
            "PST": {
                "date": "2026-08-24",
                "fasting_start": "2026-08-24T06:23:00-08:00",
                "parana_start": "2026-08-25T06:24:00-08:00",
                "parana_end": "2026-08-25T10:15:00-08:00"
            }
        },
        "fasting_rules": {
            "en": "Vaishnava observance on Monday, August 24, observing on the second day due to Dashami confluence.",
            "ta": "வைணவ மரபில் தசமி கலப்பு காரணமாக திங்கட்கிழமை, ஆகஸ்ட் 24 அன்று விரதம் கடைப்பிடிக்கப்படுகிறது.",
            "hi": "वैष्णव परंपरा दशमी प्रभाव के कारण सोमवार, 24 अगस्त को व्रत रखती है।",
            "te": "వైష్ణవ సంప్రదాయం ప్రకారం దశమీ ప్రభావం వలన సోమవారం, ఆగస్టు 24న ఉపవాసం ఆచరించాలి."
        },
        "source": "Reference Workbook / ISKCON List"
    }
}

# Event 21: Rama Ekadashi (Same day: 2026-11-05)
e21 = event_map[21]
e21['has_tradition_variation'] = False
e21['tradition_variants'] = {}

# Event 22: Prabodhini / Devutthana Ekadashi (Differs: Smarta 2026-11-20, Vaishnava 2026-11-21)
e22 = event_map[22]
e22['has_tradition_variation'] = True
e22['tradition_variants'] = {
    "smarta": {
        "tradition": "smarta",
        "timing": {
            "IST": {
                "date": "2026-11-20",
                "fasting_start": "2026-11-20T06:11:00+05:30",
                "parana_start": "2026-11-21T06:11:00+05:30",
                "parana_end": "2026-11-21T08:28:00+05:30"
            },
            "EST": {
                "date": "2026-11-20",
                "fasting_start": "2026-11-20T06:51:00-05:00",
                "parana_start": "2026-11-21T06:52:00-05:00",
                "parana_end": "2026-11-21T10:18:00-05:00"
            },
            "CST": {
                "date": "2026-11-20",
                "fasting_start": "2026-11-20T06:53:00-06:00",
                "parana_start": "2026-11-21T06:54:00-06:00",
                "parana_end": "2026-11-21T10:18:00-06:00"
            },
            "MST": {
                "date": "2026-11-20",
                "fasting_start": "2026-11-20T06:56:00-07:00",
                "parana_start": "2026-11-21T06:57:00-07:00",
                "parana_end": "2026-11-21T10:18:00-07:00"
            },
            "PST": {
                "date": "2026-11-20",
                "fasting_start": "2026-11-20T06:58:00-08:00",
                "parana_start": "2026-11-21T06:59:00-08:00",
                "parana_end": "2026-11-21T10:18:00-08:00"
            }
        },
        "fasting_rules": {
            "en": "Smarta observance on Friday, November 20, when Ekadashi tithi is present at sunrise.",
            "ta": "ஸ்மார்த்த முறை சூரிய உதய திதி அடிப்படையில் வெள்ளிக்கிழமை, நவம்பர் 20 அன்று கடைப்பிடிக்கப்படுகிறது.",
            "hi": "स्मार्त परंपरा सूर्योदय तिथि के अनुसार शुक्रवार, 20 नवंबर को व्रत रखती है।",
            "te": "స్మార్త సంప్రదాయం ప్రకారం శుక్రవారం, నవంబర్ 20న వ్రతం ఆచరించాలి."
        },
        "source": "Reference Workbook / Drik Panchang"
    },
    "vaishnava": {
        "tradition": "vaishnava",
        "timing": {
            "IST": {
                "date": "2026-11-21",
                "fasting_start": "2026-11-21T06:11:00+05:30",
                "parana_start": "2026-11-22T06:12:00+05:30",
                "parana_end": "2026-11-22T08:30:00+05:30"
            },
            "EST": {
                "date": "2026-11-21",
                "fasting_start": "2026-11-21T06:52:00-05:00",
                "parana_start": "2026-11-22T06:53:00-05:00",
                "parana_end": "2026-11-22T10:19:00-05:00"
            },
            "CST": {
                "date": "2026-11-21",
                "fasting_start": "2026-11-21T06:54:00-06:00",
                "parana_start": "2026-11-22T06:55:00-06:00",
                "parana_end": "2026-11-22T10:19:00-06:00"
            },
            "MST": {
                "date": "2026-11-21",
                "fasting_start": "2026-11-21T06:57:00-07:00",
                "parana_start": "2026-11-22T06:58:00-07:00",
                "parana_end": "2026-11-22T10:19:00-07:00"
            },
            "PST": {
                "date": "2026-11-21",
                "fasting_start": "2026-11-21T06:59:00-08:00",
                "parana_start": "2026-11-22T07:00:00-08:00",
                "parana_end": "2026-11-22T10:19:00-08:00"
            }
        },
        "fasting_rules": {
            "en": "Vaishnava observance on Saturday, November 21, following strict Dashami-Vedha avoidance.",
            "ta": "வைணவ மரபில் தசமி வேதம் தவிர்த்து சனிக்கிழமை, நவம்பர் 21 அன்று விரதம் கடைப்பிடிக்கப்படுகிறது.",
            "hi": "वैष्णव परंपरा दशमी-वेध से मुक्त होकर शनिवार, 21 नवंबर को व्रत रखती है।",
            "te": "వైష్ణవ సంప్రదాయం ప్రకారం దశమీ వేధ రహితంగా శనివారం, నవంబర్ 21న ఉపవాసం ఆచరించాలి."
        },
        "source": "Reference Workbook / ISKCON List"
    }
}

# Event 24: Mokshada Ekadashi (Same day: 2026-12-20)
e24 = event_map[24]
e24['has_tradition_variation'] = False
e24['tradition_variants'] = {}

# 2. Update 2027 Events:
# Event 29: Vijaya Ekadashi (Correct to 2027-03-03 as per workbook)
e29 = event_map[29]
e29['timing']['IST']['date'] = "2027-03-03"
e29['timing']['IST']['fasting_start'] = "2027-03-03T06:24:00+05:30"
e29['timing']['IST']['parana_start'] = "2027-03-04T06:23:00+05:30"
e29['timing']['IST']['parana_end'] = "2027-03-04T07:16:00+05:30"

# Event 32: Kamada Ekadashi (Correct to 2027-04-16 as per workbook)
e32 = event_map[32]
e32['timing']['IST']['date'] = "2027-04-16"
e32['timing']['IST']['fasting_start'] = "2027-04-16T05:59:00+05:30"
e32['timing']['IST']['parana_start'] = "2027-04-17T05:58:00+05:30"
e32['timing']['IST']['parana_end'] = "2027-04-17T08:20:00+05:30"

# Write out updated JSON formatted cleanly
with open(src_file, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
print(f"Updated {src_file} successfully.")

if os.path.exists(parent_file):
    with open(parent_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"Updated {parent_file} successfully.")
