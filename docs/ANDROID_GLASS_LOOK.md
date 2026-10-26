# Android Home follow-up and optional Glass Look

The four approved Home/Calendar follow-ups were implemented first in `61c047f`,
after failing tests in `9cc2eed`. See `ANDROID_FOLLOWUP_2026-10-22.md` for behavior.
Calendar already localized both AM/PM endpoints; new rendered-card tests protect
that behavior in every language and tradition.

Glass Look is a saved Appearance setting beneath Dark Mode, **Off by default**.
Off preserves the existing Android renderer; On applies clearer app-owned cards,
capsules, Settings groups, secondary actions, feedback and sheet backgrounds.
The regular bottom navigation remains unchanged in both modes, including size,
position and behavior. The choice is independent of Dark Mode. High contrast and
accessible navigation retain the existing accessibility treatment. Text opacity
and touch targets are not reduced with the backgrounds.

This is a Flutter implementation in the existing Android app. The Kotlin host,
Home/Lock Screen widget renderers, native widget previews and Android signing
identifiers are unchanged. It approximates the approved clearer iOS appearance;
Android system-owned dialogs, keyboards and materials retain their platform UI.
The two new strings reuse the exact approved iOS wording in all six languages.
Generated ARB adapters and shared Swift resources are kept in sync.

## Test evidence

TDD: `48f00cf` reproduces the missing Glass Look switch before implementation.
The Android dark/light Off golden images were rendered from the committed
pre-Glass source (`82b6322`, including the final ring-paint correction) in a temporary copy with Flutter's Android platform
variant. The final Off renderer must match both images. A toggle round trip also
compares the original and restored Home pixels. On must visibly change them.

Focused appearance tests cover all six languages, both themes, 393dp at normal
text and 320dp at doubled text size, persistence, independent Dark Mode, Calendar
date retention, all five tab rectangles, Home action clearance and accessibility
fallback. Home progress additionally covers city-midnight removal, minute
refreshes, invalid intervals and 0/72/100 percent at text scales up to 3.

The device driver pre-installs and grants the isolated test app permissions,
settles route animations before measuring rectangles, and exports screenshots
on the host. Integration cases cover Home, blocked-recording feedback, Calendar
markers and traditions, then Glass Look in six languages and dark/light themes.
These checks run on the dedicated emulator and the connected Galaxy M52. The
wife's Z Flip 5 is deferred. Physical tests use the existing separate
`com.applausestudios.ekadashi_calendar.glasspreview` package, preserving the
regular app's data. A normal, non-test build is installed afterward.

The complete emulator and Galaxy M52 integration runs both passed, exporting **56 screenshots each**. Screenshot review reproduced a clipped ring stroke; `7e4d742` measured 437 pixels painting outside its frame before `82b6322` changed the stroke to paint inside. The saved-record edit regression (`175e638`) also passes after the final recording guard correction. The final normal build includes both targeted corrections; their rendered-ink and editing checks are covered in the full Flutter suite.

Final local verification after both targeted corrections:

- Full Flutter suite: **799 passed**; analyzer: **no issues**.
- Swift core release suite: **270 passed**; Android JVM suite: **86 passed**.
- Focused appearance/layout suite: **27 passed**; Apptinel configuration: **2 passed**.
- Full integration flows passed on Android 16 emulator and physical Galaxy M52
  (Android 13), exporting 56 screenshots per device before the final two targeted
  corrections. The full Flutter suite covers those final corrections.
- The final non-test ARM64 profile build was installed on the M52 as
  **Ekadashi Glass Preview**. A normal-build On/Off smoke check confirmed the
  corrected ring and stable tab bar, then restored Glass Off and Home.
  The regular app remains installed and its data was not removed.

All changes remain on PR #24. No CI was triggered and no merge was performed.
