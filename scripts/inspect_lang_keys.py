import re

with open('lib/services/language_service.dart', 'r', encoding='utf-8') as f:
    code = f.read()

m = re.search(r"'en':\s*\{(.*?)\n\s*\},", code, re.DOTALL)
if m:
    en_block = m.group(1)
    keys = re.findall(r"'([a-z0-9_]+)':", en_block)
    print(f'Total keys in EN: {len(keys)}')
    for k in keys:
        print(f"  {k}")
