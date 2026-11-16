"""Smoke-test the public Android Pages sources and their location catalog."""

import json
import re
import unittest
from pathlib import Path

DOCS = Path(__file__).resolve().parents[1] / "docs"


class AndroidPagesTest(unittest.TestCase):
    def test_public_urls_and_navigation(self):
        layout = (DOCS / "_layouts/android.html").read_text()
        self.assertIn('id="main-content"', layout)
        for file, path in (
            ("index.md", "/"),
            ("privacy-policy.md", "/privacy-policy.html"),
            ("terms-of-service.md", "/terms-of-service.html"),
        ):
            page = (DOCS / file).read_text()
            self.assertRegex(page, r"(?m)^layout: android$")
            self.assertIn(f"permalink: {path}\n", page)
            self.assertIn(f"'{path}' | relative_url", layout)

    def test_home_covers_android_v2(self):
        home = (DOCS / "index.md").read_text()
        for value in (
            "34,152", "2026b", "2026 and 2027", "Smarta", "Vaishnava",
            "English", "Hindi", "Tamil", "Telugu", "Gujarati", "Bengali",
            "Journey", "Muhurta", "Rashi", "three", "12 months", "Google Play",
            "Monthly", "Yearly", "Lifetime",
        ):
            self.assertIn(value, home)
        self.assertNotRegex(home, r"Coming Soon|IST, EST|App Store")

    def test_policy_explains_cloud_data_and_removal(self):
        policy = (DOCS / "privacy-policy.md").read_text()
        for value in (
            "Firebase Authentication", "Firestore", "calendar.readonly", "Disconnect Google",
            "Limited Use", "Retention and deletion", "GitHub Pages", "Android backup",
        ):
            self.assertIn(value, policy)
        self.assertNotRegex(policy, r"100% Local Storage|Zero Third-Party")

    def test_terms_distinguish_purchase_types(self):
        terms = (DOCS / "terms-of-service.md").read_text()
        for value in ("auto-renew", "one-time", "end of", "refund", "consumer rights"):
            self.assertIn(value, terms.lower())
        self.assertNotIn("sourced from Drik Panchang", terms)

    def test_location_catalog(self):
        catalog = json.loads((DOCS / "assets/locations.json").read_text())
        self.assertEqual(catalog["release"], "2026b")
        self.assertEqual(len(catalog["cities"]), 34152)
        self.assertEqual(len({row[0] for row in catalog["cities"]}), 34152)
        self.assertGreater(len(catalog["zones"]), 500)
        for identifier in ("Asia/Kolkata", "Europe/London", "Pacific/Chatham", "UTC"):
            self.assertIn(identifier, catalog["zones"])
        zones = set(catalog["zones"])
        self.assertTrue(all(row[-1] in zones for row in catalog["cities"]))


if __name__ == "__main__":
    unittest.main()
