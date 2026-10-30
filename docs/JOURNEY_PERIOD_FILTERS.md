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
Android parity and final validation are recorded after completion.
