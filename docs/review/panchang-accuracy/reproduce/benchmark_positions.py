import os,json,random,datetime as dt,subprocess,numpy as np
import swisseph as swe
from skyfield.api import load,load_file
from skyfield.framelib import ecliptic_frame
from pathlib import Path
root=Path(os.environ.get('PANCHANG_AUDIT_WORKDIR', '/workspace/panchang-audit'));swe.set_ephe_path(str(root/'ephe'));swe.set_sid_mode(swe.SIDM_LAHIRI)
rng=random.Random(271828);utc=dt.timezone.utc
samples=[dt.datetime(1900,1,1,tzinfo=utc)+dt.timedelta(seconds=rng.random()*(dt.datetime(2101,1,1,tzinfo=utc)-dt.datetime(1900,1,1,tzinfo=utc)).total_seconds()) for _ in range(10000)]
p=root/'results/position-instants.txt';p.write_text('\n'.join(x.isoformat() for x in samples))
e=json.loads(subprocess.check_output([str(root/'runtime/positions-extended')],env={**os.environ,'POSITIONS_IN':str(p)}));e=np.array(e)
j=np.array([swe.julday(x.year,x.month,x.day,x.hour+x.minute/60+x.second/3600+x.microsecond/3.6e9) for x in samples])
sun=[];moon=[];aya=[]
for jd in j:
 s,f=swe.calc_ut(jd,swe.SUN,swe.FLG_SWIEPH);m,g=swe.calc_ut(jd,swe.MOON,swe.FLG_SWIEPH)
 assert f&swe.FLG_SWIEPH and g&swe.FLG_SWIEPH
 sun.append(s);moon.append(m);aya.append(swe.get_ayanamsa_ex_ut(jd,swe.FLG_SWIEPH)[1])
sun=np.array(sun);moon=np.array(moon)
def stats(v):
 v=np.abs(v);return {'n':len(v),'mean':float(np.mean(v)),'p95':float(np.percentile(v,95)),'max':float(np.max(v)),'worstUtc':samples[int(np.argmax(v))].isoformat()}
def angle(a,b):return ((np.array(a)-np.array(b)+180)%360-180)*3600
out={'seed':271828,'range':'1900-01-01 to 2100-12-31','swissVersion':swe.version,'swissFlagsChecked':True,'swiss':{'sunLongitudeArcsec':stats(angle(e[:,0],sun[:,0])),'moonLongitudeArcsec':stats(angle(e[:,1],moon[:,0])),'apparentLahiriArcsec':stats(angle(e[:,2],aya)),'moonLatitudeArcsec':stats(angle(e[:,3],moon[:,1])),'moonDistanceKm':stats(e[:,4]-moon[:,2]*149597870.7),'sunDistanceKm':stats((e[:,5]-sun[:,2])*149597870.7)}}
ts=load.timescale(builtin=True);ep=load_file(str(root/'ephe/de440s.bsp'));t=ts.tt_jd(e[:,6]);earth=ep['earth']
for body,col in [('sun',0),('moon',1)]:
 app=earth.at(t).observe(ep[body]).apparent();lat,lon,dist=app.frame_latlon(ecliptic_frame)
 out.setdefault('jplDE440sMatchedTT',{})[body+'LongitudeArcsec']=stats(angle(e[:,col],lon.degrees))
 out['jplDE440sMatchedTT'][body+'DistanceKm']=stats((e[:,5]*149597870.7 if body=='sun' else e[:,4])-dist.km)
 if body=='moon':out['jplDE440sMatchedTT']['moonLatitudeArcsec']=stats(angle(e[:,3],lat.degrees))
(root/'results/positions-10000.json').write_text(json.dumps(out,indent=2));print(json.dumps(out,indent=2))
