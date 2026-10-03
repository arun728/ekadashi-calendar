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
No data, search algorithm, calendar import or widget logic is changed.

TDD evidence: the app tests first failed because the old bar lacked the capsule;
29 component tests failed against a placeholder before implementation. Additional
regressions cover app navigation, state retention, repeat taps, keyboard dismissal
and the iOS fallback. Screenshot review revealed that the nested Calendar
Scaffold placed its Add button behind the capsule. Four new layout regressions
first failed at narrow/normal widths and normal/large text; the FAB now reserves
the parent navigation inset. The emulator flow also asserts its visible placement. The full inherited v2 suite and native/emulator CI remain
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
layout fixes preserve data and existing controls. Total new Flutter cases:36.
