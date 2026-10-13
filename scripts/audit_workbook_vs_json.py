import json
from dump_excel import read_sheet_cells, excel_date_to_str
import zipfile

# 1. Load Excel Workbook
path_xlsx = r'c:\Users\sakth\OneDrive\Desktop\ekadhesi calendar\Ekadashi_2026_2027.xlsx'

with zipfile.ZipFile(path_xlsx) as z:
    wb_2026_rows = read_sheet_cells(z, 'xl/worksheets/sheet1.xml')
    wb_2027_rows = read_sheet_cells(z, 'xl/worksheets/sheet2.xml')
    notes_rows = read_sheet_cells(z, 'xl/worksheets/sheet4.xml')

# Parse 2026 Excel rows
# Row 1 is header: A1: Ekadashi, B1: General / Smarta, C1: Smarta (same as General on Drik), D1: Vaishnava (ISKCON), E1: Smarta vs Vaishnava, F1: Notes
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
    smarta = r.get('B', '').strip()
    smarta2 = r.get('C', '').strip()
    vaishnava = r.get('D', '').strip()
    diff = r.get('E', '').strip()
    notes = r.get('F', '').strip()
    if name:
        wb_2026.append({
            'name': name,
            'smarta': smarta,
            'smarta2': smarta2,
            'vaishnava': vaishnava,
            'diff': diff,
            'notes': notes
        })

wb_2027 = []
for r_raw in wb_2027_rows[1:]:
    r = normalize_row(r_raw)
    name = r.get('A', '').strip()
    smarta = r.get('B', '').strip()
    vaishnava = r.get('C', '').strip()
    story = r.get('D', '').strip()
    notes = r.get('E', '').strip()
    source = r.get('F', '').strip()
    if name:
        wb_2027.append({
            'name': name,
            'smarta': smarta,
            'vaishnava': vaishnava,
            'story': story,
            'notes': notes,
            'source': source
        })

print(f"Loaded {len(wb_2026)} events from Excel 2026 sheet.")
print(f"Loaded {len(wb_2027)} events from Excel 2027 sheet.")

# 2. Load JSON
with open('assets/ekadashi_data.json', 'r', encoding='utf-8') as f:
    json_data = json.load(f)

events = json_data.get('ekadashis', [])
print(f"Loaded {len(events)} events from assets/ekadashi_data.json.")

# Separate JSON events by year (based on timing.IST.date)
json_2026 = [e for e in events if e.get('timing', {}).get('IST', {}).get('date', '').startswith('2026')]
json_2027 = [e for e in events if e.get('timing', {}).get('IST', {}).get('date', '').startswith('2027')]
print(f"JSON 2026 events: {len(json_2026)}")
print(f"JSON 2027 events: {len(json_2027)}")

print("\n--- 2026 Comparison ---")
for i in range(max(len(wb_2026), len(json_2026))):
    wb_e = wb_2026[i] if i < len(wb_2026) else {}
    js_e = json_2026[i] if i < len(json_2026) else {}
    
    js_name = js_e.get('name', {}).get('en', 'MISSING')
    js_ist = js_e.get('timing', {}).get('IST', {})
    js_date = js_ist.get('date', 'MISSING')
    
    # Check tradition variants in JSON
    variants = js_e.get('tradition_variants', {})
    sm_variant_date = variants.get('smarta', {}).get('timing', {}).get('IST', {}).get('date', '')
    va_variant_date = variants.get('vaishnava', {}).get('timing', {}).get('IST', {}).get('date', '')
    has_var = js_e.get('has_tradition_variation', False)
    
    wb_name = wb_e.get('name', 'MISSING')
    wb_smarta = wb_e.get('smarta', 'MISSING')
    wb_vaishnava = wb_e.get('vaishnava', 'MISSING')
    wb_diff = wb_e.get('diff', '')
    
    discrepancy = []
    if js_date != wb_smarta:
        discrepancy.append(f"Date mismatch: JSON={js_date} vs WB_Smarta={wb_smarta}")
    if wb_diff == 'Differs':
        if not has_var:
            discrepancy.append(f"WB says differs (V={wb_vaishnava}), but JSON has_variation=False")
        if va_variant_date != wb_vaishnava:
            discrepancy.append(f"Vaishnava variant mismatch: JSON={va_variant_date} vs WB={wb_vaishnava}")
    elif wb_diff == 'Same day':
        if has_var:
            discrepancy.append(f"WB says same day, but JSON has_variation=True (V={va_variant_date})")

    status = "MATCH" if not discrepancy else "DISCREPANCY: " + "; ".join(discrepancy)
    print(f"[{i+1}] WB: {wb_name:25} ({wb_smarta}) | JSON: id={js_e.get('id')} {js_name:25} ({js_date}) | {status}")

print("\n--- 2027 Comparison ---")
for i in range(max(len(wb_2027), len(json_2027))):
    wb_e = wb_2027[i] if i < len(wb_2027) else {}
    js_e = json_2027[i] if i < len(json_2027) else {}
    
    js_name = js_e.get('name', {}).get('en', 'MISSING')
    js_ist = js_e.get('timing', {}).get('IST', {})
    js_date = js_ist.get('date', 'MISSING')
    
    wb_name = wb_e.get('name', 'MISSING')
    wb_smarta = wb_e.get('smarta', 'MISSING')
    wb_notes = wb_e.get('notes', '')
    wb_source = wb_e.get('source', '')
    
    discrepancy = []
    if js_date != wb_smarta:
        discrepancy.append(f"Date mismatch: JSON={js_date} vs WB={wb_smarta}")
    
    status = "MATCH" if not discrepancy else "DISCREPANCY: " + "; ".join(discrepancy)
    print(f"[{i+1}] WB: {wb_name:25} ({wb_smarta}) | JSON: id={js_e.get('id')} {js_name:25} ({js_date}) | {status}")
