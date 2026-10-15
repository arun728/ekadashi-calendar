import os,json,random,datetime as dt,subprocess,numpy as np
import swisseph as swe
from pathlib import Path
root=Path(os.environ.get('PANCHANG_AUDIT_WORKDIR', '/workspace/panchang-audit'));swe.set_ephe_path(str(root/'ephe'));swe.set_sid_mode(swe.SIDM_LAHIRI)
r=random.Random(314159);utc=dt.timezone.utc
instants=[dt.datetime(2000,1,1,tzinfo=utc)+dt.timedelta(seconds=r.random()*365.25*86400*40) for _ in range(1000)];coords=[(r.uniform(-65,65),r.uniform(-180,180)) for _ in instants]
p=root/'results/lagna-instants.txt';p.write_text('\n'.join(f'{t.isoformat()}|{lat}|{lon}' for t,(lat,lon) in zip(instants,coords)))
e=json.loads(subprocess.check_output([str(root/'runtime/positions-lagna-after')],env={**os.environ,'POSITIONS_IN':str(p)}));errs=[];sid=[]
for row,t,(lat,lon) in zip(e,instants,coords):
 jd=swe.julday(t.year,t.month,t.day,t.hour+t.minute/60+t.second/3600+t.microsecond/3.6e9)
 asc=swe.houses_ex(jd,lat,lon,b'P',swe.FLG_SIDEREAL)[1][0]
 # Production PanchangEngine subtracts the mean Lahiri angle from its ascending longitude.
 mean=swe.get_ayanamsa_ut(jd);nt=row[2]-mean
 engine=(row[7]-(row[2]-((swe.calc_ut(jd,swe.ECL_NUT)[0][2]))))%360
 # Use engine mean Lahiri formula directly, matching the production caller.
 tt=row[6];T=(tt-2451545)/36525;aya=23.857092328+T*(1.3968879428+T*.00030708955);engine=(row[7]-row[2])%360
 err=((engine-asc+180)%360-180)*3600
 errs.append({'errorArcsec':err,'utc':t.isoformat(),'lat':lat,'lon':lon,'engine':engine,'swiss':asc})
 sid.append(((row[8]-swe.sidtime(jd)*15+180)%360-180)*3600)
a=sorted(abs(x['errorArcsec']) for x in errs);out={'n':len(a),'meanArcsec':sum(a)/len(a),'p95Arcsec':a[int(.95*len(a))],'maxArcsec':a[-1],'worst':max(errs,key=lambda x:abs(x['errorArcsec'])),'siderealTimeMaxArcsec':max(abs(x) for x in sid)}
(root/'results/lagna-1000-after.json').write_text(json.dumps(out,indent=2));print(json.dumps(out,indent=2))
