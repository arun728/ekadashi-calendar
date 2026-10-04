# Android glass navigation prototype

Branch: `feature/android-glass-navigation`, based on dev after validated PR #7.
**Do not merge before Samsung M52/Z Flip 5 device testing and fresh Arun approval.**
Main remains outside scope. This is a Flutter approximation of the supplied iOS
App Store navigation reference, not Apple's Liquid Glass implementation.

Five existing destinations share one floating rounded capsule. A tightly clipped
18px backdrop blur, translucent light/dark gradient, highlight rim and selected
pill preserve the app's teal branding. Existing Material icon fonts avoid new
font dependencies. All labels and accessibility position hints use the existing
localization delegates. High contrast/accessible navigation disables blur and
uses opaque surfaces; reduced motion disables the pill transition. Touch targets
remain at least 48dp, labels adapt to large text, and full labels remain available
through tooltips and semantics. The capsule hides while the keyboard is open.

Only Android uses this navigation. iOS retains its existing bar. The IndexedStack,
deep links, query/year state and repeated Home/Calendar tab actions are retained.
Home, Search and Vrat controls reserve safe space above the bar. Calendar and
Settings can scroll content behind it and have sufficient trailing padding.
Existing data, search algorithms, whole-year calendar imports and widget behavior are retained.

TDD evidence: the app tests first failed because the old bar lacked the capsule;
29 component tests failed against a placeholder before implementation. Additional
regressions cover app navigation, state retention, repeat taps, keyboard dismissal
and the iOS fallback. Screenshot review revealed that the nested Calendar
Scaffold placed its Add button behind the capsule. Four new layout regressions
first failed at narrow/normal widths and normal/large text. The final design
places Add in the top action tube so it cannot overlap navigation or date cells.
The emulator flow also asserts its visible placement. The full inherited v2 suite and native/emulator CI remain
required. Screenshots in `build/ui-screenshots/offscreen` are Flutter offscreen
renders; `build/ui-screenshots/android` captures are real Android emulator runs.
Do not treat either as Samsung hardware/performance validation.

Build device preview with `bash tool/build-glass-preview.sh`. The ARM64 profile
APK uses debug signing and the separate package
`com.applausestudios.ekadashi_calendar.glasspreview`, label **Ekadashi Glass Preview**.
It coexists with the Play Store app in a separate data sandbox; it does not migrate
or replace personal history. Its OAuth package/signing identity would need separate
registration, so it is a UI preview, not production OAuth or release-upgrade proof.
CI uploads `ekadashi-glass-preview-arm64` for mobile download.

On both Samsung phones check all five destinations, selected/repeated taps, all
four languages, light/dark themes, font enlargement, TalkBack, keyboard open/close,
gesture/three-button navigation and scrolling to final Calendar/Settings controls.
On Z Flip 5 also check folding/resume. Review blur readability, animation smoothness
and battery/rendering behavior. These results and fresh approval gate integration.

Sources:
- https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html
- https://developer.android.com/reference/android/graphics/RenderEffect
- https://docs.flutter.dev/platform-integration/android/platform-views

Flutter can sample the actual Flutter backdrop. A Kotlin RenderEffect applies to
an Android RenderNode; embedding native views adds composition and accessibility
complexity without guaranteeing capture of Flutter content underneath.

The enlarged-font Calendar layout cases also exposed existing narrow-screen
Home location/language and Calendar year-row overflows. The Home header stacks
its controls at large text on narrow widths; the year selector can wrap. These
layout fixes preserve data and existing controls.

## Shared option tubes

Home location/language and paired card actions, Calendar Add/sync/disconnect,
filters, month arrows and paired event actions, Search categories, year/language,
clear/submit and exploration, Vrat sub-tabs/history/status/fasting methods, and
related Settings controls use one shared clipped glass surface. A lone action is
left separate. Only the bottom tab selection is black; other selections are a
translucent teal wash. All control accents use the app teal #00A19B. Compact 12px
chip labels retain system text scaling and 48dp targets. Search toolbar height
scales with text so its clear/submit pair retains at least 48dp. Long options wrap or
scroll horizontally; dropdown menus retain opaque surfaces for readability.

New red/green tests cover all four languages and both themes across all five
destinations, narrow 320dp layouts at 2x text scaling, 2/3/5-option activation and
disabled controls, transparent chip canvases, bottom-only black selection and
month bounds/selected-day preservation. Large-text failures exposed Search
badge and Vrat statistics/milestone/history card rows; these now wrap or constrain
text. Search result category labels now use the existing localized category key.

A GPS-off CI run exposed an emulator attachment deadlock before tests: `am start
-W` waited for a first frame while Dart was deliberately paused awaiting the
integration driver. The launcher now starts without -W, then waits for the Dart
VM service as before. A runner regression demonstrates the old failure. Driver
assertion failures, missing VM service and timeouts still fail the gate.

The Android-only permissions row has separate guide/settings icons in a two-icon
tube, with localized tooltips and 48dp targets. Four direct component regressions
first reproduced its 16dp info target and long-label overflow, then passed for
English, Tamil, Hindi and Telugu at 320dp / 2x text scaling.

Final emulator screenshot review found that the fixed 160dp empty-day footer
placed its message behind the floating bar on short phones. Four red/green
geometry regressions cover 720/732dp heights and five/six-week months. The
selected-day empty status now appears above the grid, below the month controls;
calendar rows and all action targets retain their existing sizes.

Arun subsequently confirmed that passing automated gates and screenshot checks
authorize this UI merge to dev. Physical Samsung checks remain release validation.
Paid subscriptions/rewards belong on a later separate branch and require their
own finalization, testing and approval before any dev merge.

The corrected empty caption exposed the old floating Add button covering a date
cell on short emulator screens. Four existing short-screen cases were strengthened
to assert that Add never intersects the calendar grid; all four failed on the
floating-button implementation. Add now joins sync/disconnect in a three-action
header tube, retaining its key, localized tooltip, callback, 48dp target and
storage-failure disabled state. This prevents date occlusion while retaining
all calendar row sizes. Native integration also asserts grid/action separation.
