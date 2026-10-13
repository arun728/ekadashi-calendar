import math
from datetime import datetime, timezone, timedelta

def calculate_sunrise(lat, lon, date, zenith=90.8333):
    # NOAA Solar Calculation Algorithm
    # zenith: 90 deg 50 min = 90.8333 deg (standard for sunrise with refraction)
    year = date.year
    month = date.month
    day = date.day
    
    # Day of the year
    n = date.timetuple().tm_yday
    
    # Approximate time
    lng_hour = lon / 15.0
    t = n + ((6.0 - lng_hour) / 24.0)
    
    # Sun's mean anomaly
    M = (0.9856 * t) - 3.289
    
    # Sun's true longitude
    L = M + (1.916 * math.sin(math.radians(M))) + (0.020 * math.sin(math.radians(2 * M))) + 282.634
    L = L % 360
    
    # Sun's right ascension
    RA = math.degrees(math.atan(0.91764 * math.tan(math.radians(L))))
    RA = RA % 360
    
    # Right ascension value needs to be in the same quadrant as L
    Lquadrant = (math.floor(L / 90.0)) * 90.0
    RAquadrant = (math.floor(RA / 90.0)) * 90.0
    RA = RA + (Lquadrant - RAquadrant)
    RA = RA / 15.0
    
    # Sun's declination
    sinDec = 0.39782 * math.sin(math.radians(L))
    cosDec = math.cos(math.asin(sinDec))
    
    # Sun's local hour angle
    cosH = (math.cos(math.radians(zenith)) - (sinDec * math.sin(math.radians(lat)))) / (cosDec * math.cos(math.radians(lat)))
    
    if cosH > 1:
        return None # Sun never rises
    if cosH < -1:
        return None # Sun never sets
        
    H = 360.0 - math.degrees(math.acos(cosH))
    H = H / 15.0
    
    # Local mean time of rising
    T = H + RA - (0.06571 * t) - 6.622
    
    # Adjust to UTC
    UT = (T - lng_hour) % 24.0
    
    # Convert to IST (+05:30)
    ist_hours = (UT + 5.5) % 24.0
    hour = int(ist_hours)
    minute = int(round((ist_hours - hour) * 60))
    if minute == 60:
        hour += 1
        minute = 0
    return f"{hour:02d}:{minute:02d}"

cities = [
    ("Delhi", 28.6139, 77.2090),
    ("Chennai", 13.0827, 80.2707),
    ("Mumbai", 19.0760, 72.8777),
    ("Kolkata", 22.5726, 88.3639),
    ("Guwahati", 26.1445, 91.7362)
]

print("Sunrise on 2026-02-13:")
for city, lat, lon in cities:
    sr = calculate_sunrise(lat, lon, datetime(2026, 2, 13))
    print(f"  {city:<12}: Calculated={sr}")

print("\nDrik Panchang official sunrises on 2026-02-13:")
print("  Delhi       : 07:01")
print("  Chennai     : 06:33")
print("  Mumbai      : 07:08")
print("  Kolkata     : 06:06")
print("  Guwahati    : 06:00")
