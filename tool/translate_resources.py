#!/usr/bin/env python3
"""Offline plan by default. Explicit --apply invokes standard Google NMT using
Application Default Credentials via gcloud, then writes REVIEW CANDIDATES only.
No API credential or runtime translation dependency is included in the app.
"""
import argparse
from collections import Counter
import hashlib
import html
import json
from pathlib import Path
import re
import subprocess
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
TOKEN = re.compile(r'\{[a-zA-Z][a-zA-Z0-9_]*\}')

def fingerprint(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()

def protect(text):
    remaining = TOKEN.sub('', text)
    if '{' in remaining or '}' in remaining:
        raise ValueError('Nested ICU requires segmentation; do not submit it to translation.')
    parts, position = [], 0
    for match in TOKEN.finditer(text):
        parts.extend([html.escape(text[position:match.start()]),
                      '<span translate="no">'+match.group()+'</span>'])
        position = match.end()
    parts.append(html.escape(text[position:]))
    return ''.join(parts)

def restore(translated, original):
    # Google accepts HTML for placeholder protection. Reject injected tags and
    # changed/missing/extra arguments rather than producing a broken ARB file.
    text = html.unescape(re.sub(r'</?span\b[^>]*>', '', translated))
    if re.search(r'<[^>]+>', text):
        raise ValueError('Unexpected markup in translated text')
    if Counter(TOKEN.findall(text)) != Counter(TOKEN.findall(original)):
        raise ValueError('Translation altered ICU arguments')
    protect(text)
    return text

def estimate_cost(source_characters, languages, used_this_month=0):
    billable = source_characters * languages
    remaining = max(0, 500000 - used_this_month)
    return max(0, billable - remaining) * 20 / 1000000

def resources(root):
    arb = json.loads((root/'lib/l10n/app_en.arb').read_text())
    source = {f'ui:{k}': v for k,v in arb.items() if not k.startswith('@')}
    paths = {}
    for path in sorted((root/'assets/calendar').glob('20*.json')):
        pack = json.loads(path.read_text())
        for i,event in enumerate(pack['ekadashis']):
            for field in ('name','description','story','fasting_rules','benefits'):
                key = f"calendar:{pack['year']}:{event['occurrence_uid']}:{field}"
                source[key] = event[field]['en']
                paths[key] = (path,i,field)
    return arb,source,paths

def plan(root, locales, previous):
    arb,source,paths = resources(root)
    review_path = root/'lib/l10n/translation_review.json'
    review = json.loads(review_path.read_text()) if review_path.exists() else {}
    jobs = {}
    for locale in locales:
        path = root/f'lib/l10n/app_{locale}.arb'
        target = json.loads(path.read_text()) if path.exists() else {}
        pending = set(review.get(locale,{}).get('pendingKeys',[]))
        entries = {}
        for key,text in source.items():
            old_hash = previous.get(locale,{}).get(key)
            if key.startswith('ui:'):
                k = key[3:]; exists = k in target and k not in pending
            else:
                path,i,field = paths[key]
                exists = locale in json.loads(path.read_text())['ekadashis'][i][field]
            if not exists or (old_hash is not None and old_hash != fingerprint(text)):
                protect(text)  # Validate everything before a paid request.
                entries[key] = text
        jobs[locale] = entries
    return arb,jobs

def translate(project, region, locale, texts, glossary):
    token = subprocess.check_output(['gcloud','auth','application-default','print-access-token'],text=True).strip()
    data = {'sourceLanguageCode':'en','targetLanguageCode':locale,
            'contents':[protect(t) for t in texts],'mimeType':'text/html'}
    if glossary:
        data['glossaryConfig'] = {'glossary':glossary}
    request = urllib.request.Request(
        f'https://translation.googleapis.com/v3/projects/{project}/locations/{region}:translateText',
        data=json.dumps(data).encode(), headers={'Authorization':'Bearer '+token,
        'Content-Type':'application/json','x-goog-user-project':project},method='POST')
    with urllib.request.urlopen(request,timeout=60) as response:
        result = json.load(response)
    rows = result.get('glossaryTranslations' if glossary else 'translations',[])
    if len(rows) != len(texts): raise ValueError('Incomplete translation response')
    return [restore(row['translatedText'],source) for row,source in zip(rows,texts)]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--languages',default='te,bn,gu')
    parser.add_argument('--project')
    parser.add_argument('--region',default='us-central1')
    parser.add_argument('--glossaries',type=Path,help='JSON mapping target language to glossary resource name')
    parser.add_argument('--used-this-month',type=int,default=0)
    parser.add_argument('--max-characters',type=int,default=500000)
    parser.add_argument('--output',type=Path,default=ROOT/'build/translation-review')
    parser.add_argument('--apply',action='store_true',help='Make paid API calls; output still requires review')
    args = parser.parse_args()
    locales = list(dict.fromkeys(args.languages.split(',')))
    if not locales or 'en' in locales or any(not re.fullmatch('[a-z]{2,3}(?:-[A-Za-z]+)?',l) for l in locales):
        parser.error('Supply valid target language codes, excluding source English')
    snapshot_path = ROOT/'lib/l10n/source_hashes.json'
    previous = json.loads(snapshot_path.read_text()) if snapshot_path.exists() else {}
    arb,jobs = plan(ROOT,locales,previous)
    total = sum(len(t) for job in jobs.values() for t in set(job.values()))
    report = {'mode':'translate-review-candidates' if args.apply else 'dry-run',
      'uniqueCharactersPerTarget':{l:sum(len(t) for t in set(job.values())) for l,job in jobs.items()},
      'characters':total,'estimatedNmtUsd':estimate_cost(total,1,args.used_this_month),
      'assumption':'Standard NMT; monthly allowance remaining is supplied by you. Taxes/storage excluded.',
      'pendingStrings':{l:len(j) for l,j in jobs.items()}}
    args.output.mkdir(parents=True,exist_ok=True)
    (args.output/'plan.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
    if not args.apply: return
    if not args.project: parser.error('--project is required for --apply')
    if total > args.max_characters: parser.error('Character budget exceeded; no translation calls made')
    glossary_map = json.loads(args.glossaries.read_text()) if args.glossaries else {}
    memory_path = args.output/'translation_memory.json'
    memory = json.loads(memory_path.read_text()) if memory_path.exists() else {}
    results = {}
    for locale,job in jobs.items():
        unique = list(dict.fromkeys(job.values()))
        glossary = glossary_map.get(locale)
        missing = [t for t in unique if f'{locale}:{glossary}:{fingerprint(t)}' not in memory]
        while missing:
            batch, size = [],0
            while missing and len(batch) < 100 and size + len(protect(missing[0])) <= 20000:
                text = missing.pop(0); batch.append(text); size += len(protect(text))
            if not batch: raise ValueError('Oversized source string needs segmentation')
            translated = translate(args.project,args.region,locale,batch,glossary)
            for source,target in zip(batch,translated):
                memory[f'{locale}:{glossary}:{fingerprint(source)}'] = target
            # Persist successful request cache so retry does not pay for it again.
            temp = memory_path.with_suffix('.tmp'); temp.write_text(json.dumps(memory,ensure_ascii=False,indent=2));temp.replace(memory_path)
        results[locale] = {k:memory[f'{locale}:{glossary}:{fingerprint(t)}'] for k,t in job.items()}
    # Review payloads only: existing language files and contributor content are
    # never silently overwritten by machine output.
    (args.output/'candidates.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
    print('Review candidates saved. Apply approved translations, then regenerate l10n and run tests.')
if __name__ == '__main__': main()
