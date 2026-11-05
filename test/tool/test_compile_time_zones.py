"""Exercise the timezone build range without downloading data or using app code."""
import datetime as dt
import pathlib
import shutil
import subprocess
import tempfile
import unittest
from zoneinfo import ZoneInfo

ROOT = pathlib.Path(__file__).resolve().parents[2]
COMPILER = ROOT / "tool/time_zones/compile.sh"


@unittest.skipUnless(shutil.which("zic"), "zic is required")
class CompileTimeZonesTests(unittest.TestCase):
    def test_preserves_history_and_materializes_recurring_rules_through_2101(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            source = root / "source"
            source.write_text(
                "Rule Research 2000 max - Mar lastSun 1:00u 1:00 D\n"
                "Rule Research 2000 max - Oct lastSun 1:00u 0 S\n"
                "Zone Research/Example 0:13:35 - LMT 1910\n"
                " 0:00 Research R%sT\n"
            )
            subprocess.run(["bash", str(COMPILER), str(source), str(root / "out")], check=True)
            with (root / "out/Research/Example").open("rb") as stream:
                zone = ZoneInfo.from_file(stream, key="Research/Example")
            for year, month, expected in [(1900, 7, 815), (2026, 7, 3600),
                                           (2050, 7, 3600), (2100, 7, 3600),
                                           (2101, 7, 3600), (2101, 1, 0)]:
                date = dt.datetime(year, month, 15, 12, tzinfo=dt.timezone.utc)
                self.assertEqual(zone.utcoffset(date).total_seconds(), expected)
            # A bounded TZif has no POSIX footer to rescue an encoder that
            # discards that footer. The 2100 transition must exist explicitly.
            from zoneinfo._common import load_data
            with (root / "out/Research/Example").open("rb") as stream:
                _, transitions, *_ = load_data(stream)
            july = dt.datetime(2100, 7, 1, tzinfo=dt.timezone.utc).timestamp()
            self.assertTrue(any(t > july for t in transitions))

    def test_reports_compilation_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            bad = root / "invalid"
            bad.write_text("this is not timezone source\n")
            result = subprocess.run(["bash", str(COMPILER), str(bad), str(root / "out")],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
