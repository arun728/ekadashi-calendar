import json
import math
from datetime import datetime, timezone, timedelta

def day_of_year(year, month, day):
    d = datetime(year, month, day)
    d0 = datetime(year, 1, 1)
    return (d - d0).days + 1

def deg_to_rad(deg):
    return deg * (math.pi / 180.0)

def rad_to_deg(rad):
    return rad * (180.0 / math.pi)

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
    if cos_h > 1 or cos_h < -1:
        return None
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

def main():
    data = json.load(open('assets/ekadashi_data.json', encoding='utf-8'))
    events = data['ekadashis']
    
    cities = [
        ("New Delhi", 28.6139, 77.2090),
        ("Kolkata", 22.5726, 88.3639),
        ("Mumbai", 19.0760, 72.8777),
        ("Chennai", 13.0827, 80.2707),
        ("Dwarka", 22.2442, 68.9685),
        ("Guwahati", 26.1445, 91.7362),
    ]
    
    print("=" * 80)
    print("PHASE 1 AUDIT: ASTRONOMICAL INPUTS & OBSERVANCE RESOLUTION ACROSS INDIA")
    print("=" * 80)
    
    # Check sunrise calculation accuracy against known reference values
    # For New Delhi on Jan 14, 2026: Drik New Delhi sunrise is 07:15 AM
    delhi_sr = calculate_sunrise(28.6139, 77.2090, datetime(2026, 1, 14))
    print(f"Sample Sunrise Test: New Delhi 2026-01-14 -> {delhi_sr.strftime('%H:%M')} (Expected ~07:15)")
    
    # Audit all 49 events:
    # 1. Tithi durations
    # 2. Closeness of tithi start/end to Sunrise across cities
    # 3. Observance dates across cities
    
    discrepancies = []
    close_calls = []
    
    for e in events:
        eid = e['id']
        name = e['name']['en']
        t = e['tithi']
        
        t_da_end = datetime.fromisoformat(t['dashami_end'].replace('Z', '+00:00'))
        t_ek_start = datetime.fromisoformat(t['ekadashi_start'].replace('Z', '+00:00'))
        t_ek_end = datetime.fromisoformat(t['ekadashi_end'].replace('Z', '+00:00'))
        t_dw_end = datetime.fromisoformat(t['dwadashi_end'].replace('Z', '+00:00'))
        
        ek_duration = (t_ek_end - t_ek_start).total_seconds() / 3600.0
        dw_duration = (t_dw_end - t_ek_end).total_seconds() / 3600.0
        
        # Check if tithi duration is within normal astronomical limits (approx 19 to 26 hours)
        if ek_duration < 18 or ek_duration > 27:
            discrepancies.append((eid, name, f"Abnormal Ekadashi tithi duration: {ek_duration:.2f}h"))
        if dw_duration < 18 or dw_duration > 27:
            discrepancies.append((eid, name, f"Abnormal Dwadashi tithi duration: {dw_duration:.2f}h"))
            
        # Check resolveObservance for each city
        city_results = {}
        for cname, lat, lng in cities:
            tz_offset = timedelta(hours=5, minutes=30)
            local_ek_start = (t_ek_start + tz_offset).replace(tzinfo=None)
            local_ek_end = (t_ek_end + tz_offset).replace(tzinfo=None)
            local_da_end = (t_da_end + tz_offset).replace(tzinfo=None)
            
            # Default date from IST timing in JSON
            ist_date_str = e['timing']['IST']['date']
            base_date = datetime.strptime(ist_date_str, '%Y-%m-%d')
            
            # Day 1 and Day 2 sunrises
            # Notice how base_date is used in Dart:
            # baseCalendarDay = defaultDate ?? DateTime(localEkadashiStart.year, localEkadashiStart.month, localEkadashiStart.day)
            day1 = base_date
            day2 = day1 + timedelta(days=1)
            
            sr1 = calculate_sunrise(lat, lng, day1)
            ar1 = sr1 - timedelta(minutes=96)
            sr2 = calculate_sunrise(lat, lng, day2)
            ar2 = sr2 - timedelta(minutes=96)
            
            # Check proximity of tithi boundary to sunrise/arunodaya
            diff1 = abs((local_ek_start - sr1).total_seconds()) / 60.0
            diff2 = abs((local_ek_end - sr2).total_seconds()) / 60.0
            diff_ar = abs((local_da_end - ar1).total_seconds()) / 60.0
            
            if diff1 < 60 or diff2 < 60 or diff_ar < 60:
                close_calls.append((eid, name, cname, f"Tithi boundary within 60 min of sunrise/arunodaya (diff1={diff1:.1f}m, diff2={diff2:.1f}m, diff_ar={diff_ar:.1f}m)"))
                
            # Observance resolution
            is_viddha = local_da_end > ar1
            is_ek_sr1 = local_ek_start < sr1 and local_ek_end > sr1
            is_ek_sr2 = local_ek_start < sr2 and local_ek_end > sr2
            is_ek_ar2 = local_ek_start < ar2 and local_ek_end > ar2
            
            # Smarta
            smarta_day2 = False
            if not is_ek_sr1 and (is_ek_sr2 or is_ek_ar2):
                smarta_day2 = True
            elif is_viddha and is_ek_sr2:
                smarta_day2 = True
                
            # Vaishnava
            vaishnava_day2 = False
            if is_viddha or is_ek_sr2:
                vaishnava_day2 = True
            elif not is_ek_sr1 and is_ek_sr2:
                vaishnava_day2 = True
                
            smarta_date = day2.strftime('%Y-%m-%d') if smarta_day2 else day1.strftime('%Y-%m-%d')
            vaishnava_date = day2.strftime('%Y-%m-%d') if vaishnava_day2 else day1.strftime('%Y-%m-%d')
            
            city_results[cname] = (smarta_date, vaishnava_date)
            
        # Check if observance dates vary across cities in India
        first_city = cities[0][0]
        ref_smarta, ref_vaish = city_results[first_city]
        for cname, _, _ in cities[1:]:
            c_smarta, c_vaish = city_results[cname]
            if c_smarta != ref_smarta or c_vaish != ref_vaish:
                print(f"LOCATION SENSITIVITY DETECTED for ID {eid} ({name}):")
                print(f"  {first_city}: Smarta={ref_smarta}, Vaishnava={ref_vaish}")
                print(f"  {cname}: Smarta={c_smarta}, Vaishnava={c_vaish}")

    print(f"\nTotal Tithi Duration Anomalies: {len(discrepancies)}")
    for d in discrepancies:
        print(f"  ID {d[0]}: {d[1]} - {d[2]}")
        
    print(f"\nTithi Boundaries within 60 min of Sunrise / Arunodaya: {len(close_calls)}")
    for c in close_calls[:10]:
        print(f"  ID {c[0]}: {c[1]} in {c[2]} -> {c[3]}")

if __name__ == '__main__':
    main()
