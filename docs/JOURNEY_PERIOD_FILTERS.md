# Journey period filters and Record tab

Approved 31 October 2026, PR32. Completes the uniform-grid work interrupted by
the session limit and scopes displayed Overview/Statistics progress.

- Selected-year metrics, streaks, totals and next-milestone progress use that
  year's canonical occurrences. A future year therefore has no earned progress.
- Annual capacities remain visible (2027: 25 occurrences, 4,100 maximum points).
  Lifetime Points always uses the original all-history summary.
- All years consolidates 2026 through the calculation's Home-zone current day.
  Future years are excluded; completion totals use eligible occurrences through
  today. Annual cards retain full-year targets and appear newest year first.
- January rollover shows 2027 above 2026. A single-year streak does not carry
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
