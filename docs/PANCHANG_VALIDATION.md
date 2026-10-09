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

## Festivals added in Phase 3 (8 October 2026)

`FestivalRuleTests` (Swift) and `test/unit/festival_rules_test.dart` (Dart)
check these against dates published for New Delhi. Both engines calculate
them with the same rules (`PanchangEngine.phase3FestivalIds`), and the
parity fixture compares them field by field.

| Festival | Rule (Amanta months) | 2026 | 2027 |
| --- | --- | --- | --- |
| Raksha Bandhan | Shravana Purnima on the day it lasts six ghatis after sunrise (the first half is Bhadra), else Aparahna | 28 Aug | 17 Aug |
| Nag Panchami | Shravana Shukla Panchami in Purvahna | 17 Aug | 6 Aug |
| Ratha Yatra | Ashadha Shukla Dwitiya at sunrise | 16 Jul | 5 Jul |
| Durga Ashtami | Ashvina Shukla Ashtami at sunrise | 19 Oct | 7 Oct |
| Varalakshmi Vratam | Shravana Shukla Friday whose next Friday is after Purnima (Drik, New Delhi); many South Indian calendars keep the Friday before | 28 Aug | 13 Aug (from the rule) |
| Onam (Thiruvonam) | Shravana nakshatra six nazhika after sunrise in solar Simha (Chingam); the later one if it occurs twice | 26 Aug | 12 Sep |
| Karthigai Deepam | First day in solar Vrischika with Krittika during Pradosh | 24 Nov | 11 Dec (from the rule) |

Sources for the published dates: [Raksha Bandhan](https://publicholidays.in/raksha-bandhan/),
[Nag Panchami](https://dekhopanchang.com/en/festivals/nag-panchami),
[Onam](https://www.drikpanchang.com/festivals/onam/onam-thiruvonam-date.html?year=2027),
[Ratha Yatra](https://www.drikpanchang.com/festivals/ratha-yatra/jagannatha-rathayatra-date-time.html?year=2027),
[Durga Ashtami](https://dekhopanchang.com/en/festivals/durga-ashtami/2027),
[Varalakshmi Vratam](https://dekhopanchang.com/en/festivals/varalakshmi-vratam),
[Karthigai Deepam](https://www.drikpanchang.com/festivals/karthigai-deepam/karthigai-deepam-date-time.html?year=2026).
Only dates were compared; no text or data was copied.

Known gaps: Holika Dahan 2026 is calculated on 2 March while published
calendars give 3 March (Bhadra and the eclipse are not evaluated). Lohri,
Bhogi, Puthandu, Vishu and Baisakhi need regional solar rules and are not
calculated yet.
