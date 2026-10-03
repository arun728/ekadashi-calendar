import importlib.util
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location('translation',Path(__file__).parents[2]/'tool/translate_resources.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
class TranslationTests(unittest.TestCase):
    def test_placeholder_roundtrip_reordering_and_html(self):
        original = 'Observe {value0} & break at {value1}'
        protected = module.protect(original)
        self.assertIn('translate="no"',protected)
        self.assertEqual(module.restore(protected,original),original)
    def test_missing_or_changed_placeholder_is_rejected(self):
        with self.assertRaises(ValueError): module.restore('Translated text','in {value0} days')
        with self.assertRaises(ValueError): module.restore('in {wrong} days','in {value0} days')
    def test_nested_icu_is_rejected_before_a_paid_call(self):
        with self.assertRaises(ValueError): module.protect('{count, plural, one{day} other{days}}')
    def test_cost_multiplies_languages_and_applies_monthly_credit(self):
        self.assertEqual(module.estimate_cost(21000,5),0)
        self.assertEqual(module.estimate_cost(200000,5),10)
    def test_source_hash_changes_only_for_actual_content(self):
        self.assertEqual(module.fingerprint('a'),module.fingerprint('a'))
        self.assertNotEqual(module.fingerprint('a'),module.fingerprint('b'))
if __name__ == '__main__': unittest.main()
