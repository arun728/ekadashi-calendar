# Journey period filters and Record tab

Approved 31 October 2026, PR32. Completes the uniform-grid work interrupted by
the session limit and scopes displayed Overview/Statistics progress.

- Selected-year metrics, streaks, totals and next-milestone progress use that
  year's canonical occurrences. A future year therefore has no earned progress.
- Annual capacities remain visible (2027: 25 occurrences, 4,100 maximum points).
  Lifetime Points always uses the original all-history summary.
- All years includes every supported calendar from 2026, including future years.
  Completion uses complete-calendar capacity: 24 + 25 = 49 for 2026/2027.
  Only eligible records earn progress; future occurrences remain unrecorded.
  The current year's card appears first, then other years in descending order.
- In 2026 the cards show 2026 then 2027; January rollover shows 2027 above 2026. A single-year streak does not carry
  another year's run; All years retains cross-year consistency where continuous.
- Next milestone is selected using the scoped progress and applicable existing
  earned state. No persisted award state, history or premium limits are changed.
- Overview contains no record buttons/rows. Journey recording stays in the Record
  subtab, formerly History; stable internal IDs and saved data remain compatible.
- Record is translated in English, Hindi, Tamil, Telugu, Gujarati and Bengali.
- Overview metrics, achievement cards and Statistics tiles use uniform heights
  measured from their tallest content. Text remains unconstrained vertically;
  language and accessibility sizes can change the shared height without clipping.

TDD evidence: core year-isolation/January tests failed before implementation;
six-language Record-label test failed for all six old History values; native
Statistics layout test initially required the new uniform count-card component.
Green iOS: all 334 Swift core tests and native presentation/period UI tests pass.
Android parity is complete on the same branch. Android year-scope tests failed
before the new summary APIs existed; the Overview widget test reproduced the
future-year progress leak and recording rows before implementation.

Final local validation:
- 334 Swift core tests passed, with zero failures.
- 12 native presentation tests and the selected-year Overview UI flow passed.
- 946 Flutter tests passed; Flutter analyzer reported no issues.
- Card geometry checks passed for all six languages, narrow/wide screens and
  enlarged accessibility text, including every Statistics tile.
- Android emulator integration passed both scenarios, covering year filters,
  translations, glass UI, record controls, badge reversal and re-earned alerts.
- Generated resources are current; formatting and diff whitespace checks pass.
- Signed iPhone Debug build succeeded. Physical installation preserves app data.

No CI was triggered and neither dev nor main was changed.

## Correction and calculation audit — 31 October 2026

The previous elapsed-only All-years denominator and exclusion of future-year
cards were incorrect. The regression test now explicitly checks 20 observed
out of 49 = 40.8163265%, displayed as 41%, with 29 unrecorded. Empty history is
0/49; perfect completed history is 49/49. Partial and missed records do not
increase full-observance completion. Counts always partition total capacity.
Overview and Statistics consume the same summary calculation rather than
maintaining separate denominator arithmetic.

Audit scope includes Record's year/status filters and future recording guard,
annual versus lifetime points, partial consistency versus strict badge streaks,
quarter/annual bonuses, duplicate identity handling, edited/deleted records,
badge revocation and repeat celebrations, and share-card annual values.
Existing dedicated tests cover these rules alongside the new capacity tests.
