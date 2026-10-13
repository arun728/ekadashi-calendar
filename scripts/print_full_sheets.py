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

def read_sheet(z, sheet_name):
    wb_tree = ET.fromstring(z.read('xl/workbook.xml'))
    ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    sheets = wb_tree.findall('ns:sheets/ns:sheet', ns)
    r_id = None
    for s in sheets:
        if s.attrib['name'] == sheet_name:
            r_id = s.attrib['{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id']
            break
    rel_tree = ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))
    rns = {'ns': 'http://schemas.openxmlformats.org/package/2006/relationships'}
    rels = {r.attrib['Id']: r.attrib['Target'] for r in rel_tree.findall('ns:Relationship', rns)}
    target = rels[r_id]
    if target.startswith('/'):
        target = target.lstrip('/')
    if not target.startswith('xl/'):
        target = 'xl/' + target

    sheet_tree = ET.fromstring(z.read(target))
    rows = []
    for row in sheet_tree.findall('ns:sheetData/ns:row', ns):
        cols = {}
        for c in row.findall('ns:c', ns):
            col_letter = ''.join(filter(str.isalpha, c.attrib.get('r', '')))
            val = ''
            is_elem = c.find('ns:is', ns)
            if is_elem is not None:
                val = ''.join([elem.text for elem in is_elem.findall('.//ns:t', ns) if elem.text])
            else:
                v_elem = c.find('ns:v', ns)
                if v_elem is not None and v_elem.text:
                    val = excel_date_to_str(v_elem.text)
            cols[col_letter] = val
        rows.append(cols)
    return rows

with zipfile.ZipFile(path) as z:
    for sname in ['2026 Dates', '2027 Dates', 'Notes']:
        print(f"==================== {sname} ====================")
        rows = read_sheet(z, sname)
        for r in rows:
            print(r)
