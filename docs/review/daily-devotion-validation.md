# Daily Devotion verification

## Failing-first evidence

- Initial PracticeService contract: restored count expected 2, actual 0;
  cross-year streak expected 1, actual 0; advanced start failed to reject free use.
- Initial navigation contract: Today destination absent.
- Initial reminder planner: weekday/DST plan returned no events; quiet-hour tests
  could not produce an allowed event.
- Routine step replacement regression: old checkmark expected false, actual true.
- Initial audio contract: uncleared/premium selection did not reject; repeat did
  not track 108 cycles; free track selection did not retain the track.
- Audio race regression: new selected track was second, native driver still loaded
  first. Serialized selection now preserves the latest requested source.
- Initial learning contract: bookmarks did not restore; next revision was null.
- Four-language large-text UI tests caught cramped editor title/content layout.
  Scrollable dialogs and bounded visible-control tests preserve the assertions.
- Existing Telugu large-text hero overflow after adding a Today banner was fixed
  by moving the daily-practice shortcut to the app bar.

Failures were corrected, not waived. Raw development logs are retained in the
session workspace; current CI provides reproducible passing evidence.

## Gates

Local validation: 343 Flutter tests passed (including existing regressions,
new unit/widget flows, and screenshots in four languages). Analyzer: no issues.
Nine Python tooling tests passed; edited shell scripts passed syntax checks.
The final teal-control UI revision also passed the complete 343-test suite.

Android emulator CI remains a required gate. Its matrix covers API24/33/35,
notification denial and GPS off, including the real native audio plugin with a
synthetic test signal. Exact commit/run links and artifact interpretation will
be recorded in the draft PR after actual results exist. No merge is authorized.
No physical-device testing or production-audio clearance is claimed.
