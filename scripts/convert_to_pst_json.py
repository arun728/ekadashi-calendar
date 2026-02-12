import json
from datetime import datetime, timedelta


# DST Rules for US (approximate, but accurate for 2026)
# DST starts 2nd Sunday March: March 8, 2026
# DST ends 1st Sunday Nov: Nov 1, 2026
DST_START_2026 = datetime(2026, 3, 8, 2, 0)
DST_END_2026 = datetime(2026, 11, 1, 2, 0)

def get_pst_offset(dt_obj):
    # Check if inside DST
    # Naive check is fine since we know the transition dates for 2026
    if DST_START_2026 <= dt_obj < DST_END_2026:
        return "-07:00" # PDT
    else:
        return "-08:00" # PST

def convert_time_to_iso(date_str, time_str, is_end_time=False):
    # date_str: YYYY-MM-DD
    # time_str: HH:MM AM/PM
    if not date_str or not time_str:
        return None
    
    dt_str = f"{date_str} {time_str}"
    try:
        dt = datetime.strptime(dt_str, "%Y-%m-%d %I:%M %p")
        offset = get_pst_offset(dt)
        return dt.strftime(f"%Y-%m-%dT%H:%M:%S{offset}")
    except ValueError:
        return None

def main():
    with open("ekadashi_data_pst_2026_raw.json", "r") as f:
        raw_data = json.load(f)
    
    final_ekadashis = []
    
    for idx, item in enumerate(raw_data):
        # Determine DST for the fasting date (usually just 00:00)
        fasting_date = item['fasting_date']
        
        # Parana
        parana_date = item['parana_date']
        parana_start_iso = convert_time_to_iso(parana_date, item['parana_start'])
        parana_end_iso = convert_time_to_iso(parana_date, item['parana_end'])
        
        # Fasting start? Use 00:00 of fasting date? 
        # Or just the date string as per user request "exact dates start fasting".
        # The existing JSON has "fasting_start" as a timestamp. 
        # But we don't have Tithi start. I will omit it strictly or just put 00:00 if needed.
        # User asked for "exact dates start fasting". Date string is enough?
        # But existing JSON has "fasting_start".
        # I'll stick to Date String in a "date" field, and timings in separate fields.
        
        ekadashi_entry = {
            "id": idx + 1,
            "name": {
                "en": item['name']
            },
            "timing": {
                "PST": {
                    "date": fasting_date,
                    "parana_start": parana_start_iso,
                    "parana_end": parana_end_iso
                    # "fasting_start": ... omitted as we didn't scrape it
                }
            }
        }
        final_ekadashis.append(ekadashi_entry)

    final_json = {
        "version": "1.5",
        "generated": datetime.now().strftime("%Y-%m-%d"),
        "source": "Drik Panchang (San Jose)",
        "year": 2026,
        "notes": "Parana times for San Jose, CA. Includes DST adjustments.",
        "ekadashis": final_ekadashis
    }

    with open("assets/ekadashi_data_pst_2026.json", "w") as f:
        json.dump(final_json, f, indent=2)
    
    print("Created assets/ekadashi_data_pst_2026.json")

if __name__ == "__main__":
    main()
