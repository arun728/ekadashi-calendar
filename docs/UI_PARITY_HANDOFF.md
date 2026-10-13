# UI parity continuation

Continuation branch: `feature/ui-parity-resume`, based on
`feature/ui-parity` at `d74893a`. The earlier local continuation from
`5f0f8f0` is preserved locally on `archive/ui-parity-resume-5f0f8f0`;
its overlapping implementation was not applied over Claude's newer work.

## Reference and completed implementation

Use Arun's iPhone screenshots from 12 October 2026 and the native views in
`ios-native/EkadashiCalendar/` as the reference. Preserve platform-specific
widget rendering and verified store entitlement rules.

- Dark selected-tab capsule with teal icon and label.
- Home header states, teal language action, glass Ekadashi card, prominent
  Details button, grey disabled record action and Details navigation.
- Calendar toolbar, Google action menu, All default, individual glass
  filters, narrow weekday grid, month/year wheels, glass entries and
  multi-day entry editor.
- Journey overview/history/statistics/achievements, glass status rows,
  recording sheet and achievement unlock presentation.
- Panchang toolbar, location/date controls, glass chips/cards, sheets,
  Muhurta control and pushed pages.
- Search sheet/results, Premium sheet, reminder picker entitlement flow,
  Settings details, localized notification channel and widget gallery.
- Larger iOS magnifying-glass action on all five tab toolbars, including
  narrow screens, with a touch target of at least 44dp.
- iOS circular sync, sync and person-minus disconnect glyphs for Google.
  The Cupertino icon font is included in app assets and offscreen renders.

Claude's newer source commits implement the broad screen parity work.
This continuation adds the final search/Google icon requirements, their
TDD regressions, and nonfunctional analyzer cleanup.

## TDD and verification

`38541ca` commits the failing icon tests before implementation: both
all-tab search tests and the Google-symbol test fail on `d74893a`, while
the dark-tab regression passes. The targeted icon, shell and Calendar
suite subsequently passes all 28 tests.

Full local validation results will be recorded below when complete.
Linux SQLite FFI tests require `libsqlite3.so`; this workspace supplies
the system library through its local test environment without app changes.

## Remaining validation

Android emulator/native build checks and the iOS app/XCUITests require
their respective SDKs and were not run here. Rendered Flutter PNGs use
mock native channels; they are layout evidence, not device captures.
Review the supplied screens on Android and iPhone before claiming exact
visual parity, particularly platform glass, system controls and fonts.

No CI is authorized. Every pushed commit includes `[skip ci]`; do not
trigger workflows or merge into dev/main without Arun's instructions.
