import re
import sys

with open('scripts/iskcon_2027.html', 'r', encoding='utf-8') as f:
    text = f.read()

# Look for all festival cards
# Find patterns like dpFestivalCard or similar
cards = re.findall(r'<div class=\"[^\"]*Card[^\"]*\">(.*?)</div>', text, re.DOTALL)
print("Cards found:", len(cards))

# Let's search for lines containing 'Ekadashi'
with open('scripts/iskcon_lines.txt', 'w', encoding='utf-8') as out:
    for line in text.splitlines():
        if any(w in line for w in ['Ekadashi', 'Parana', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']):
            clean = re.sub(r'<[^>]+>', ' ', line).strip()
            if clean and len(clean) < 200:
                out.write(clean + '\n')

print("Wrote iskcon_lines.txt")
