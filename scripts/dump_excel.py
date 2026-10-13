import zipfile
import xml.etree.ElementTree as ET
import datetime

path = r'c:\Users\sakth\OneDrive\Desktop\ekadhesi calendar\Ekadashi_2026_2027.xlsx'

def excel_date_to_str(val):
    try:
        f = float(val)
        if 40000 < f < 60000:
            base = datetime.date(1899, 12, 30)
            return (base + datetime.timedelta(days=int(f))).strftime('%Y-%m-%d')
    except Exception:
        pass
    return str(val)

def read_sheet_cells(z, target):
    sheet_tree = ET.fromstring(z.read(target))
    ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    rows_data = []
    for row in sheet_tree.findall('ns:sheetData/ns:row', ns):
        row_dict = {}
        for c in row.findall('ns:c', ns):
            col_ref = c.attrib.get('r')
            # Extract cell value
            # Can be inlineStr: <is><t>...</t></is>
            # Or <v>...</v>
            val = ''
            is_elem = c.find('ns:is', ns)
            if is_elem is not None:
                text_parts = [elem.text for elem in is_elem.findall('.//ns:t', ns) if elem.text]
                val = ''.join(text_parts)
            else:
                v_elem = c.find('ns:v', ns)
                if v_elem is not None and v_elem.text:
                    val = v_elem.text
                    val = excel_date_to_str(val)
            row_dict[col_ref] = val
        rows_data.append(row_dict)
    return rows_data

with zipfile.ZipFile(path) as z:
    wb_tree = ET.fromstring(z.read('xl/workbook.xml'))
    ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    sheets = wb_tree.findall('ns:sheets/ns:sheet', ns)
    sheet_info = [(s.attrib['name'], s.attrib['sheetId'], s.attrib['{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id']) for s in sheets]

    rel_tree = ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))
    rns = {'ns': 'http://schemas.openxmlformats.org/package/2006/relationships'}
    rels = {r.attrib['Id']: r.attrib['Target'] for r in rel_tree.findall('ns:Relationship', rns)}

    for name, sheet_id, r_id in sheet_info:
        target = rels[r_id]
        if not target.startswith('xl/'):
            if target.startswith('/'):
                target = target[1:]
            else:
                target = 'xl/' + target
        rows = read_sheet_cells(z, target)
        print(f"\n================ SHEET: {name} ({len(rows)} rows) ================")
        for r in rows:
            print(r)
