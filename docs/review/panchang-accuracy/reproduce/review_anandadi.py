import os
import json,sys,datetime as dt
from pathlib import Path
import swisseph as swe
root=Path(os.environ.get('PANCHANG_AUDIT_WORKDIR', '/workspace/panchang-audit'));swe.set_ephe_path(str(root/'ephe'));swe.set_sid_mode(swe.SIDM_LAHIRI)
names='Ananda Kaladanda Dhumra Prajapati Saumya Dhwanksha Dhwaja Srivatsa Vajra Mudgara Chhatra Mitra Manasa Padma Lumbaka Utpata Mrityu Kana Siddhi Shubha Amrita Musala Gada Matanga Rakshasa Chara Sthira Vardhamana'.split()
results={}
for group in ['16','edges']:
 ref=json.load(open(root/f'results/reference-{group}.json'))
 before=json.load(open(root/f'results/engine-{group}.json'))
 after=json.load(open(root/f'results/engine-after-{group}.json'))
 score={'before':0,'after':0,'total':0,'excludedNoSunrise':0,'mismatches':[]}
 for city,rows in ref.items():
  old={d['date']:d for d in before[city]['days']};new={d['date']:d for d in after[city]['days']}
  for day in rows:
   if day['date'][:4] not in ['2026','2027']:continue
   if day['sunrise'] is None:score['excludedNoSunrise']+=1;continue
   t=dt.datetime.fromisoformat(day['sunrise'].replace('Z','+00:00'));jd=swe.julday(t.year,t.month,t.day,t.hour+t.minute/60+t.second/3600+t.microsecond/3.6e9)
   lon,flags=swe.calc_ut(jd,swe.MOON,swe.FLG_SWIEPH|swe.FLG_SIDEREAL);assert flags&swe.FLG_SWIEPH
   longitude=lon[0];nak=int(longitude/(360/27));extended=21 if 276+2/3<=longitude<280+8/9 else nak+1 if nak>=21 else nak
   weekday=dt.date.fromisoformat(day['date']).weekday();expected=names[(extended-[4,8,12,16,20,24,0][weekday])%28]
   score['total']+=1
   for label,engine in [('before',old),('after',new)]:
    match=engine[day['date']]['anandadi']==expected;score[label]+=match
    if not match and len(score['mismatches'])<8:score['mismatches'].append([label,city,day['date'],engine[day['date']]['anandadi'],expected])
 for label in ['before','after']:score[label+'Accuracy']=100*score[label]/score['total']
 results[group]=score
(root/'results/anandadi-before-after.json').write_text(json.dumps(results,indent=2));print(json.dumps(results,indent=2))
