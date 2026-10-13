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

def resolve_observance_dart(t_da_end, t_ek_start, t_ek_end, t_dw_end, lat, lng, tradition, default_date=None):
    tz_offset = timedelta(hours=5, minutes=30)
    local_ek_start = t_ek_start + tz_offset
    local_ek_end = t_ek_end + tz_offset
    local_da_end = t_da_end + tz_offset
    
    if default_date is not None:
        base_calendar_day = default_date
    else:
        base_calendar_day = datetime(local_ek_start.year, local_ek_start.month, local_ek_start.day)
        
    day1 = base_calendar_day
    day2 = day1 + timedelta(days=1)
    
    sr1 = calculate_sunrise(lat, lng, day1)
    ar1 = sr1 - timedelta(minutes=96)
    sr2 = calculate_sunrise(lat, lng, day2)
    ar2 = sr2 - timedelta(minutes=96)
    
    # Strip tzinfo for wall-clock compare
    sr1 = sr1.replace(tzinfo=None)
    ar1 = ar1.replace(tzinfo=None)
    sr2 = sr2.replace(tzinfo=None)
    ar2 = ar2.replace(tzinfo=None)
    local_ek_start = local_ek_start.replace(tzinfo=None)
    local_ek_end = local_ek_end.replace(tzinfo=None)
    local_da_end = local_da_end.replace(tzinfo=None)
    
    is_viddha = local_da_end > ar1
    is_ek_sr1 = local_ek_start < sr1 and local_ek_end > sr1
    is_ek_sr2 = local_ek_start < sr2 and local_ek_end > sr2
    is_ek_ar2 = local_ek_start < ar2 and local_ek_end > ar2
    
    fasts_on_day2 = False
    if tradition == 'vaishnava':
        if is_viddha or is_ek_sr2:
            fasts_on_day2 = True
        elif not is_ek_sr1 and is_ek_sr2:
            fasts_on_day2 = True
    else: # smarta
        if not is_ek_sr1 and (is_ek_sr2 or is_ek_ar2):
            fasts_on_day2 = True
        elif is_viddha and is_ek_sr2:
            fasts_on_day2 = True
            
    return day2 if fasts_on_day2 else day1

def main():
    data = json.load(open('assets/ekadashi_data.json', encoding='utf-8'))
    delhi_lat, delhi_lng = 28.6139, 77.2090
    
    print("Comparing resolveObservance WITH defaultDate vs WITHOUT defaultDate for New Delhi:")
    mismatches = []
    for e in data['ekadashis']:
        eid = e['id']
        name = e['name']['en']
        t = e['tithi']
        da_end = datetime.fromisoformat(t['dashami_end'].replace('Z', '+00:00'))
        ek_start = datetime.fromisoformat(t['ekadashi_start'].replace('Z', '+00:00'))
        ek_end = datetime.fromisoformat(t['ekadashi_end'].replace('Z', '+00:00'))
        dw_end = datetime.fromisoformat(t['dwadashi_end'].replace('Z', '+00:00'))
        
        ist_date = datetime.strptime(e['timing']['IST']['date'], '%Y-%m-%d')
        
        # Test Smarta
        smarta_with = resolve_observance_dart(da_end, ek_start, ek_end, dw_end, delhi_lat, delhi_lng, 'smarta', default_date=ist_date)
        smarta_without = resolve_observance_dart(da_end, ek_start, ek_end, dw_end, delhi_lat, delhi_lng, 'smarta', default_date=None)
        
        # Test Vaishnava
        vaish_with = resolve_observance_dart(da_end, ek_start, ek_end, dw_end, delhi_lat, delhi_lng, 'vaishnava', default_date=ist_date)
        vaish_without = resolve_observance_dart(da_end, ek_start, ek_end, dw_end, delhi_lat, delhi_lng, 'vaishnava', default_date=None)
        
        if smarta_with != smarta_without or vaish_with != vaish_without:
            mismatches.append((eid, name, ist_date.strftime('%Y-%m-%d'),
                               smarta_with.strftime('%Y-%m-%d'), smarta_without.strftime('%Y-%m-%d'),
                               vaish_with.strftime('%Y-%m-%d'), vaish_without.strftime('%Y-%m-%d'),
                               (ek_start + timedelta(hours=5.5)).strftime('%Y-%m-%d %H:%M')))
            
    print(f"Total Mismatches when defaultDate is missing: {len(mismatches)}")
    for m in mismatches:
        print(f"ID {m[0]:2d} ({m[1]}): JSON IST Date={m[2]}, EK Start IST={m[7]}")
        print(f"    Smarta:    with={m[3]}, without={m[4]}")
        print(f"    Vaishnava: with={m[5]}, without={m[6]}")

if __name__ == '__main__':
    main()
