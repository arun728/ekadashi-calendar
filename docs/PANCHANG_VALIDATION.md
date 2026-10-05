# Worldwide Panchang validation

Candidate: `feature/panchang-location-details`, stacked on PR #11. These checks
describe the implemented profile, not full Drik product parity or certification
by a religious calendar authority. See [PANCHANG_RESEARCH.md](PANCHANG_RESEARCH.md)
for sources, conventions and remaining coverage.

## Independent fasting comparison

The offline candidate was exported separately for Smarta and Gaudiya/ISKCON for
2026 and 2027. The Gaudiya output was compared with unmodified `gaurabda==0.8.4`.
All four locations have 24 fasts in 2026 and 25 in 2027. Raw reference fixtures
remain unchanged in `test/fixtures/panchang/gaurabda_raw_2026_2027.json`.

| Location | 2026 raw date differences | 2027 raw date differences | Largest matching-date Parana difference, 2026 / 2027 |
| --- | --- | --- | --- |
| New Delhi | Jun 25→26; Aug 23→24 | Jun 14→15 | 1.44 / 1.26 minutes |
| New York | None | None | 1.40 / 1.14 minutes |
| London | None | None | 1.37 / 1.26 minutes |
| Sydney | None | None | 1.17 / 1.20 minutes |

Arrows describe raw reference → candidate. A separate diagnostic changes only
the public Python port's no-match Mahadvadashi sentinel (`256` → `0`); it explains
all three differences. With that explicitly labelled diagnostic, no fasting-date
differences remain for these locations/years. This does not validate the private
Abhay or Drik implementations. Smarta currently has synthetic rule coverage,
not this Gaudiya-reference comparison.

Delhi's September 12, 2027 Vijaya decision is particularly sensitive: Shravana
ends within seconds of the next sunrise. An independent sidereal Moon fixture
guards consistent true/mean equinox conversion, and the result is flagged as
near a decision boundary. The resulting very narrow Parana interval requires
tradition-specific verification; fixture agreement is not a second-level timing
guarantee.

Reproduce without modifying production data:

```sh
dart run tool/panchang_audit.dart 2026 /tmp/panchang-2026.json
dart run tool/panchang_audit.dart 2027 /tmp/panchang-2027.json
python tool/compare_panchang_reference.py /tmp/panchang-2026.json
python tool/compare_panchang_reference.py /tmp/panchang-2027.json
python tool/compare_panchang_reference.py /tmp/panchang-2026.json --diagnostic
python tool/compare_panchang_reference.py /tmp/panchang-2027.json --diagnostic
```

The Python comparator is a development tool requiring `gaurabda==0.8.4`. The
app ships neither that package nor Swiss Ephemeris.

## Automated and visual checks

Regression coverage includes:

- Independent monthly apparent Sun/Moon fixtures in both years, three Lagna
  fixtures, published Delhi and USNO New York rise/set checks.
- Civil date bounds across 23/25-hour DST, Lord Howe's half-hour transition,
  date-line locations, polar no-rise days and sunset after midnight.
- Every offline city coordinate/timezone, saved/corrupt locations, and retention
  of the notification scheduler's selected timezone.
- Synthetic repeated/skipped tithis, Arunodaya contamination, Mahadvadashi and
  Parana conditions, plus full 2027 Gaudiya dates and Parana at four locations.
- Six bottom destinations at 320/393/700dp and 1×/2× text scale in four locales;
  a narrow premium Muhurta layout, saved-location festival filtering and paid
  access revocation; actual 2027 Daily/Muhurta/Ekadashi/Rashi screenshots.
- Android integration additionally saves New York coordinates/timezone and
  captures the worldwide Panchang and More screens, alongside existing archive,
  tracker, search, billing, permission and native-widget checks.

Failing regression tests were recorded before the astronomy, weekday, lunar
rise/set, subtabs and navigation fixes. The final gate results and hosted Android
run are recorded in the PR. No local Android SDK or iOS build result is claimed.

Existing published schedules, tracker identities, reminders and widgets remain
in production use. Replacing those schedules needs wider calendar validation
and explicit history/reminder migration tests; calculated data stays a preview.
