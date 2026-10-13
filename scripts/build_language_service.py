import sys
import os
from generate_language_service import en_keys_to_te, extra_keys

sys.stdout.reconfigure(encoding='utf-8')

def build_service():
    target_path = 'lib/services/language_service.dart'
    
    # Let's read the existing file
    with open(target_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the end of 'hi': { ... }
    # In language_service.dart, lines 328 to 482 are 'hi'
    # We will insert 'te' right after 'hi'
    
    # Build te block
    te_lines = ["    'te': {"]
    for k, v in en_keys_to_te.items():
        clean_v = v.replace("'", "\\'")
        te_lines.append(f"      '{k}': '{clean_v}',")
    te_lines.append("    }")
    te_block = "\n".join(te_lines)

    # Also add extra keys to en, ta, hi
    # Let's inspect where 'parana_pending' is in en, ta, hi
    # In en: 'parana_pending': 'Parana guidance is currently pending verification.',
    # In ta: 'parana_pending': 'பாரணை வழிகாட்டல் சரிபார்ப்பில் உள்ளது.',
    # In hi: 'parana_pending': 'पारण मार्गदर्शन सत्यापन प्रक्रिया में है।',
    
    extra_en_lines = []
    for k, v in extra_keys['en'].items():
        extra_en_lines.append(f"      '{k}': '{v}',")
    extra_en_str = "\n" + "\n".join(extra_en_lines)

    extra_ta_lines = []
    for k, v in extra_keys['ta'].items():
        extra_ta_lines.append(f"      '{k}': '{v}',")
    extra_ta_str = "\n" + "\n".join(extra_ta_lines)

    extra_hi_lines = []
    for k, v in extra_keys['hi'].items():
        extra_hi_lines.append(f"      '{k}': '{v}',")
    extra_hi_str = "\n" + "\n".join(extra_hi_lines)

    # Insert into en
    en_marker = "'parana_pending': 'Parana guidance is currently pending verification.',"
    if en_marker in content:
        content = content.replace(en_marker, en_marker + extra_en_str)
    else:
        print("Warning: en_marker not found")

    # Insert into ta
    ta_marker = "'parana_pending': 'பாரணை வழிகாட்டல் சரிபார்ப்பில் உள்ளது.',"
    if ta_marker in content:
        content = content.replace(ta_marker, ta_marker + extra_ta_str)
    else:
        print("Warning: ta_marker not found")

    # Insert into hi
    hi_marker = "'parana_pending': 'पारण मार्गदर्शन सत्यापन प्रक्रिया में है।',"
    if hi_marker in content:
        content = content.replace(hi_marker, hi_marker + extra_hi_str)
    else:
        print("Warning: hi_marker not found")

    # Insert te block after hi block
    hi_end_marker = "      'parana_pending': 'पारण मार्गदर्शन सत्यापन प्रक्रिया में है।'," + extra_hi_str + "\n    }"
    replacement_hi_te = hi_end_marker + ",\n\n" + te_block
    if hi_end_marker in content:
        content = content.replace(hi_end_marker, replacement_hi_te)
    else:
        # Fallback search
        idx = content.find("    'hi': {")
        if idx != -1:
            end_hi = content.find("\n    }\n  };", idx)
            if end_hi != -1:
                content = content[:end_hi] + "\n    },\n\n" + te_block + content[end_hi+6:]
                print("Inserted te using fallback index")

    # Add supportedLanguages list
    lang_list_code = """
  /// Supported languages with codes and native labels
  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'ta', 'name': 'Tamil', 'native': 'தமிழ்'},
    {'code': 'te', 'name': 'Telugu', 'native': 'తెలుగు'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
  ];
"""
    if "static const List<Map<String, String>> supportedLanguages" not in content:
        content = content.replace("class LanguageService extends ChangeNotifier {", "class LanguageService extends ChangeNotifier {" + lang_list_code)

    with open(target_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ Successfully updated lib/services/language_service.dart with full Telugu support")

if __name__ == '__main__':
    build_service()
