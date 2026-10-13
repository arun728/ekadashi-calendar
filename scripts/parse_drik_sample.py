import re

def parse_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()

    times = re.findall(r'dpMuhurtaTime\">(.*?)</div>', text)
    infos = re.findall(r'dpMuhurtaInfo\">(.*?)</div>', text)
    print("FILE:", path)
    for i in infos:
        print("INFO:", re.sub(r'<[^>]+>', '', i).strip())
    for t in times:
        print("TIME:", re.sub(r'<[^>]+>', '', t).strip())

parse_file(r'C:\Users\sakth\.gemini\antigravity-ide\brain\412e32c4-8a7d-4bd1-be75-5f4dfb98c05f\.system_generated\steps\194\content.md')
print("="*40)
parse_file(r'C:\Users\sakth\.gemini\antigravity-ide\brain\412e32c4-8a7d-4bd1-be75-5f4dfb98c05f\.system_generated\steps\202\content.md')
