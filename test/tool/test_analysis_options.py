"""flutter analyze covers the app, not helpers that only work when copied in.

store-assets/android/tools/*.dart (PR #47) import the app's files with paths
that resolve only after the screenshot run copies them into lib/; analysing
them in place reported 16 errors and warnings on dev (27 Nov 2026).
"""

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class AnalysisOptionsTests(unittest.TestCase):
    def test_store_asset_helpers_are_excluded(self):
        options = (ROOT / "analysis_options.yaml").read_text()
        excluded = re.findall(r"^\s+- (\S+)$", options.split("include:")[0], re.M)
        self.assertIn("store-assets/**", excluded)
        self.assertTrue(list((ROOT / "store-assets").rglob("*.dart")), "the helpers still exist")


if __name__ == "__main__":
    unittest.main()
