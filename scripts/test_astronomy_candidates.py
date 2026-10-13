import json
from datetime import datetime, timezone, timedelta
import math

def day_of_year(year, month, day):
    d = datetime(year, month, day)
    d0 = datetime(year, 1, 1)
    return (d - d0).days + 1

def deg_to_rad(deg): return deg * (math.pi / 180.0)
def rad_to_deg(rad): return rad * (180.0 / math.pi)
def normalize_deg(deg):
    d = deg % 360.0
    return d + 360.0 if d < 0 else d

def calculate_sunrise(lat, lng, date_dt, utc_offset_hours=5.5):
    n = day_of_year(date_dt.year, date_dt.month, date_dt.day)
    lng_hour = lng / 15.0
    t = n + ((6.0 - lng_hour) / 24.0)
    m = (0.9856 * t) - 3.289
    m_rad = deg_to_rad(m)
    l = m + (1.916 * math.sin(m_rad)) + (0.020 * math.sin(2 * m_rad)) + 282.634
    l = normalize_deg(l)
    l_rad = deg_to_rad(l)
    ra = rad_to_deg(math.atan(0.91764 * math.tan(l_rad)))
    ra = normalize_deg(ra)
    l_quad = math.floor(l / 90.0) * 90.0
    ra_quad = math.floor(ra / 90.0) * 90.0
    ra = (ra + (l_quad - ra_quad)) / 15.0
    sin_dec = 0.39782 * math.sin(l_rad)
    cos_dec = math.cos(math.asin(sin_dec))
    lat_rad = deg_to_rad(lat)
    cos_h = (math.cos(deg_to_rad(90.8333)) - (sin_dec * math.sin(lat_rad))) / (cos_dec * math.cos(lat_rad))
    if cos_h > 1 or cos_h < -1: return None
    h = 360.0 - rad_to_deg(math.acos(cos_h))
    h_hour = h / 15.0
    t_local = h_hour + ra - (0.06571 * t) - 6.622
    ut = (t_local - lng_hour) % 24.0
    if ut < 0: ut += 24.0
    local_hours = (ut + utc_offset_hours) % 24.0
    hour = int(local_hours)
    minute = round((local_hours - hour) * 60.0)
    if minute == 60:
        hour = (hour + 1) % 24
        minute = 0
    return datetime(date_dt.year, date_dt.month, date_dt.day, hour, minute)

def find_candidate_sunrises(ek_start_local, ek_end_local, lat, lng):
    """
    Astronomically determine Day 1 and Day 2 candidate sunrises for an Ekadashi tithi.
    In Hindu astronomy, an Ekadashi can touch 1 sunrise or 2 sunrises.
    The primary candidate day (Day 1) is the first calendar day where either:
    1. Sunrise touches Ekadashi tithi, OR
    2. Arunodaya touches Ekadashi tithi, OR
    3. If Ekadashi starts after sunrise, the calendar day on which Ekadashi starts.
    """
    # Start candidate check from the day before or on ek_start_local
    start_date = datetime(ek_start_local.year, ek_start_local.month, ek_start_local.day)
    
    # Check sunrise on start_date
    sr_start = calculate_sunrise(lat, lng, start_date)
    ar_start = sr_start - timedelta(minutes=96)
    
    # If Ekadashi starts AFTER sunrise on start_date, then start_date sunrise did NOT touch Ekadashi!
    # The first sunrise that CAN touch Ekadashi is start_date + 1 day!
    if ek_start_local >= sr_start:
        day1 = start_date + timedelta(days=1)
    else:
        # Ekadashi started BEFORE sunrise on start_date
        # Check if Dashami ended before Arunodaya on start_date
        day1 = start_date
        
    day2 = day1 + timedelta(days=1)
    return day1, day2

def test_all():
    data = json.load(open('assets/ekadashi_data.json', encoding='utf-8'))
    delhi_lat, delhi_lng = 28.6139, 77.2090
    tz_offset = timedelta(hours=5, minutes=30)
    
    print("Testing astronomical candidate sunrise resolution against JSON IST dates:")
    match_count = 0
    mismatches = []
    
    for e in data['ekadashis']:
        eid = e['id']
        name = e['name']['en']
        t = e['tithi']
        
        ek_start = datetime.fromisoformat(t['ekadashi_start'].replace('Z', '+00:00')) + tz_offset
        ek_end = datetime.fromisoformat(t['ekadashi_end'].replace('Z', '+00:00')) + tz_offset
        da_end = datetime.fromisoformat(t['dashami_end'].replace('Z', '+00:00')) + tz_offset
        
        ek_start = ek_start.replace(tzinfo=None)
        ek_end = ek_end.replace(tzinfo=None)
        da_end = da_end.replace(tzinfo=None)
        
        day1, day2 = find_candidate_sunrises(ek_start, ek_end, delhi_lat, delhi_lng)
        
        sr1 = calculate_sunrise(delhi_lat, delhi_lng, day1)
        ar1 = sr1 - timedelta(minutes=96)
        sr2 = calculate_sunrise(delhi_lat, delhi_lng, day2)
        ar2 = sr2 - timedelta(minutes=96)
        
        is_viddha = da_end > ar1
        is_ek_sr1 = ek_start < sr1 and ek_end > sr1
        is_ek_sr2 = ek_start < sr2 and ek_end > sr2
        is_ek_ar2 = ek_start < ar2 and ek_end > ar2
        
        # Smarta
        smarta_day2 = False
        if not is_ek_sr1 and (is_ek_sr2 or is_ek_ar2):
            smarta_day2 = True
        elif is_viddha and is_ek_sr2:
            smarta_day2 = True
            
        smarta_date = (day2 if smarta_day2 else day1).strftime('%Y-%m-%d')
        json_date = e['timing']['IST']['date']
        
        if smarta_date == json_date:
            match_count += 1
        else:
            mismatches.append((eid, name, json_date, smarta_date, ek_start.strftime('%Y-%m-%d %H:%M'), ek_end.strftime('%Y-%m-%d %H:%M'), sr1.strftime('%H:%M')))

    print(f"Matches: {match_count} / 49")
    print(f"Mismatches: {len(mismatches)}")
    for m in mismatches:
        print(f"ID {m[0]:2d} ({m[1]}): JSON={m[2]}, Computed={m[3]} | EK Start={m[4]}, EK End={m[5]}, SR1={m[6]}")

if __name__ == '__main__':
    test_all()
