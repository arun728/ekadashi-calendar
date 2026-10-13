import json
import zipfile
from dump_excel import read_sheet_cells

path_xlsx = r'c:\Users\sakth\OneDrive\Desktop\ekadhesi calendar\Ekadashi_2026_2027.xlsx'

with zipfile.ZipFile(path_xlsx) as z:
    wb_2026_rows = read_sheet_cells(z, 'xl/worksheets/sheet1.xml')
    wb_2027_rows = read_sheet_cells(z, 'xl/worksheets/sheet2.xml')
    notes_rows = read_sheet_cells(z, 'xl/worksheets/sheet4.xml')

def normalize_row(row_dict):
    res = {}
    for k, v in row_dict.items():
        col = ''.join(filter(str.isalpha, k))
        res[col] = v
    return res

wb_2026 = []
for r_raw in wb_2026_rows[1:]:
    r = normalize_row(r_raw)
    name = r.get('A', '').strip()
    if name:
        wb_2026.append({
            'name': name,
            'smarta': r.get('B', '').strip(),
            'vaishnava': r.get('D', '').strip(),
            'diff': r.get('E', '').strip(),
            'notes': r.get('F', '').strip(),
        })

wb_2027 = []
for r_raw in wb_2027_rows[1:]:
    r = normalize_row(r_raw)
    name = r.get('A', '').strip()
    if name:
        wb_2027.append({
            'name': name,
            'smarta': r.get('B', '').strip(),
            'vaishnava': r.get('C', '').strip(),
            'story': r.get('D', '').strip(),
            'notes': r.get('E', '').strip(),
            'source': r.get('F', '').strip(),
        })

with open('assets/ekadashi_data.json', 'r', encoding='utf-8') as f:
    json_data = json.load(f)

events = json_data.get('ekadashis', [])
events_2026 = [e for e in events if e.get('timing', {}).get('IST', {}).get('date', '').startswith('2026')]
events_2027 = [e for e in events if e.get('timing', {}).get('IST', {}).get('date', '').startswith('2027')]

print("=== 2026 AUDIT DETAILS ===")
for i, wb_e in enumerate(wb_2026):
    js_e = events_2026[i]
    variants = js_e.get('tradition_variants', {})
    sm_var = variants.get('smarta', {}).get('timing', {}).get('IST', {}).get('date', 'None')
    va_var = variants.get('vaishnava', {}).get('timing', {}).get('IST', {}).get('date', 'None')
    has_var = js_e.get('has_tradition_variation', False)
    js_date = js_e.get('timing', {}).get('IST', {}).get('date')

    print(f"\n[{i+1}] {wb_e['name']} (2026)")
    print(f"    App: date={js_date}, has_var={has_var}, smarta_var={sm_var}, vaishnava_var={va_var}")
    print(f"    Workbook: Smarta={wb_e['smarta']}, Vaishnava={wb_e['vaishnava']}, Diff={wb_e['diff']}, Notes={wb_e['notes']}")

print("\n=== 2027 AUDIT DETAILS ===")
for i, wb_e in enumerate(wb_2027):
    js_e = events_2027[i]
    variants = js_e.get('tradition_variants', {})
    sm_var = variants.get('smarta', {}).get('timing', {}).get('IST', {}).get('date', 'None')
    va_var = variants.get('vaishnava', {}).get('timing', {}).get('IST', {}).get('date', 'None')
    has_var = js_e.get('has_tradition_variation', False)
    js_date = js_e.get('timing', {}).get('IST', {}).get('date')

    print(f"\n[{i+1}] {wb_e['name']} (2027)")
    print(f"    App: date={js_date}, has_var={has_var}, smarta_var={sm_var}, vaishnava_var={va_var}")
    print(f"    Workbook: Smarta={wb_e['smarta']}, Vaishnava={wb_e['vaishnava']}, Notes={wb_e['notes']}, Source={wb_e['source']}")
