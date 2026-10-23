# iOS widgets

Native iOS changes on `feature/ios-widget-redesign`, PR #24. The installed
widget kind identifiers remain stable, with two distinct products:

| Widget | Content | Sizes |
| --- | --- | --- |
| Ekadashi (`NextEkadashiWidget`) | Today's Ekadashi with percentage remaining; otherwise the single next Ekadashi | Small, medium, circular and rectangular Lock Screen |
| Upcoming Ekadashis (`UpcomingEkadashiWidget`) | The next five strictly future Ekadashi dates, each linked individually | Medium and large |

Today is evaluated in the Home schedule's time zone. Before sunrise on an
Ekadashi date the ring is full. It counts down from fasting start to Parana
start and reaches 0% at that boundary. On the following civil date the first
widget switches to the next fast even while yesterday's Parana is open.
Upcoming excludes today's fast, includes the nearest future fast, deduplicates
by occurrence UID and crosses enabled year boundaries. At the end of the
available schedule it shows the remaining real dates, without inventing any.
Timeline updates include percentage boundaries, fasting/Parana boundaries and
local midnight; iOS controls delivery.

Settings has a widget-type selector, not separate Today and Next states. The
first preview offers Small, Medium and Lock Screen, follows the same automatic
today/next behavior as the installed widget, and shows both Home Screen appearances.
Switching from Upcoming Large resets the single-widget selection to Medium.
The second preview shows five individually tappable rows and only its supported medium/large sizes. All
previews use the real Home city, tradition, language, engine schedule and clock.
No fake dates or simulated fasts are used in Settings.

Installed widget taps and preview taps select the displayed occurrence's
**Home card**, including its year. They clear Home's previous detail navigation
and preserve the occurrence selection through cold launch and year changes.
The stable occurrence URL format remains compatible with installed widgets.

Both Lock Screen accessories use the app's Panchang symbol in bright monochrome white, without the app icon's opaque square. The circular accessory reserves a centered inset for the symbol, countdown or remaining percentage, and today's progress ring. It is constrained to the actual circle, tested at 48, 62 and 76 points. The rectangular accessory uses the same symbol alongside the Ekadashi name, status and date. WidgetKit still controls system vibrancy and Always-On dimming.

English, Hindi, Tamil, Telugu, Gujarati and Bengali are covered, including
gallery names/descriptions, preview controls, dates, timing labels and units.
Medium widgets use balanced timing columns. Compact text has bounded lines and
scaling, large Upcoming widgets reserve room for longer translations, and ring
strokes stay within their allocated bounds. Colors remain app teal `#00A19B`, charcoal
`#121212` and ivory `#FAF5E8`.

## TDD evidence

The original redesign's failing tests are in `114960d`. The follow-up failing
tests were committed in `3f9543b`, `0c2f4e8` and `6f92829` before their fixes:

- Four core tests produced seven expected assertion failures for missing first
  future date, incorrect five-item cap, stale data and the gallery description.
- Two app navigation tests produced thirteen expected failures: wrong Home
  selection/year and the unwanted details sheet, including cold launch.
- A native pixel-bounds test produced eighteen expected overflow failures.
  Broader coverage using each language's longest name and larger text found
  additional large-widget overflow before that layout was corrected.
- UI tests reproduced missing widget-type controls. Additional cold-launch and
  already-open-details regressions reproduced incorrect paging and stale Home
  navigation before the final navigation fix.
- The missing-snapshot refresh-message test first failed ten assertions: both
  widgets used English in the five other supported locales. The fix uses the
  preview/WidgetKit locale, including a saved language if snapshot decoding fails.

The size/Lock Screen follow-up began with failing tests in `7b38a83`:
registration and UI checks found the unwanted single-widget Large option, while
rendered artwork measured only 22 pixels wide in 48-, 62- and 76-point slots.
The implementation removes that family and preview, retains Upcoming Medium
and Large, and sizes the circular artwork/count against the host geometry.

Native tests render every supported family in all six languages, before and
during a fast, at normal and larger text sizes. They render into a transparent
safety margin and assert no content escapes the widget rectangle. Native image
attachments cover both appearances; UI tests exercise five-row preview taps,
Home navigation, branded accessories and translated previews.

## Local verification (17 October 2026)

- Full Swift core release suite on macOS: **269 passed**, zero failures.
- Full Flutter regression suite: **726 passed**, zero failures.
- `flutter analyze --no-fatal-infos`: **no issues**.
- Native app and widget extension: built with Xcode 26.6 (iOS 26.5 SDK) for iPhone 17 Pro.
- Native app/rendering suite: **15 passed**, zero failures in its final run.
- Full native UI suite: **21 passed**, zero failures, including the six-language
  preview sweep, supported-size/reset checks, five-row taps, cold URL launch
  and prior-details navigation.
- `git diff --check`: passed.

Native screenshots were reviewed for translated labels and column separation.
Compact columns use the actual available width when selecting their text size.
Simulator validation covers the shared widget renderer and app URL handling;
physical-device WidgetKit placement, delivery and refresh scheduling remain
release checks.

All commits use `[skip ci]`. No CI requested, no merge to dev or main.

## Circle containment follow-up (18 October 2026)

A physical-device photo exposed square artwork extending outside the circular
slot. Failing tests in `2744207` reproduced 72 circle-boundary assertions across
six languages, three slot sizes and normal/larger text, plus two failures for
white pixels and the opaque square. The previous rectangle-only bounds check
could not catch this. Native comparison renders showed the original app image,
its white template (an opaque white square), and the existing Panchang symbol;
the crisp white Panchang symbol is used in both accessories.

The corrected circular composition reserves inset room for its entire symbol
and day count/percentage instead of enlarging square artwork to the slot edge.
It has a circular safety clip, and Settings uses the same renderer.

- Native app/rendering suite: **17 passed**, including circle containment and
  bright-white/no-square checks.
- Targeted Settings UI tests: **2 passed**, verifying the same symbol in both
  Lock Screen previews and supported size choices.
- Full Flutter suite after Android parity changes: **746 passed**.

The original full iOS UI run above remains historical evidence; the two affected
UI tests were rerun after this follow-up. Actual WidgetKit placement and
Always-On/vibrancy remain physical-device release checks.

## Progress layout follow-up (22 October 2026)

The Home Screen Small/Medium rings now show only the remaining percentage;
the translated word “remaining” is retained in accessibility labels and in the
rectangular Lock Screen widget. Percentage text has its own safe interior box,
including at 100%. The Medium widget places the ring to the right of the name,
increases the title and timing fonts, and chooses a compact vertical layout
when a longer translation or smaller host needs it. The circular Lock Screen
symbol has a smaller, independent frame inside a proportional ring with an
empty annulus between them. Settings uses these same native views.

On Home, the approved status row has the percentage ring on the left and the
existing Today badge on the right, above the full-width date and name. It uses
the viewed occurrence and the Home city's civil date; past and future cards
never display today's progress. A minute timeline keeps it current and handles
local midnight. Progress uses the same fasting-start-to-Parana-start calculation
as widgets, including a full ring before sunrise on the Ekadashi date.

The app and Settings use the real clock. Only explicit Debug UI tests can pin
`EKADASHI_UI_TEST_NOW` with `-ui-testing`; this override is absent from Release
builds. The UI regression pins Chennai to 22 October 2026 at 12:45 IST and checks
the expected 72%, placement, all six languages and all three preview choices.
The language sweep asserts each translated Today badge and occurrence name;
it selects the deep-linked occurrence once so a fresh UI-test launch cannot
silently reset subsequent language captures to English.
Pure rendering tests also cover the UTC/Chennai date difference and both sides
of local midnight.

TDD began with `ea93ad0`: the original implementation failed 51 internal-clearance
assertions in two native rendering tests, and the Home UI test failed because
the progress ring was missing. This adds checks that outer rectangle/circle
containment alone could not provide. A pre-existing app-model test now explicitly
selects English before asserting English display strings, restoring the saved
language afterwards.

The changes in this follow-up are iOS-only. Android code, resources and designs
are untouched; no CI or merge was requested.

Final local verification on the booted iPhone 17 Pro (iOS 26.5):

- Native app/rendering suite: **21 passed**, zero failures.
- Affected Simulator UI suite: **9 passed**, zero failures, including the
  six-language Home/progress-preview sweep, prior preview/navigation regressions
  and five individually linked Upcoming rows.
- Full Swift core suite: **269 passed**, zero failures.
- Full Flutter suite: **746 passed**, zero failures.
- `flutter analyze`: **no issues**; `git diff --check`: passed.

Native attachments include Home and Small/Medium/Lock Screen Settings previews
for each supported language, plus both-appearance rendering sheets with long
Ekadashi names. Simulator results validate the shared renderers; system
WidgetKit delivery and physical-device appearance remain release checks.


## Footer, recording feedback and Home defaults (22 October 2026)

Today Medium reserves an extra six points above the city/tradition footer.
Its compact variant slightly reduces the other stack gaps to retain the minimum
host height. The same native renderer is used by Settings previews; Next Medium
and the other widget families keep their layouts. A native pixel test measures
the gap between timing ink and footer ink in all six languages, alongside the
existing containment and larger-text checks.

The grey Home observance action now accepts a tap before Parana and shows the
same localized message as Details, using the existing transient toast. It stays
grey until recording opens; a minute timeline refreshes eligibility. Current and
future occurrences in both traditions use the same gate; existing records stay
editable. Calendar localizes the complete break-fast window, including both
AM/PM markers, through the existing clock formatter.

Home lists Vaishnava before Smarta and defaults to Vaishnava when no valid saved
preference exists. An explicit saved selection of either tradition survives.
The new tests first reproduced the default, disabled-tap, unlocalized Calendar
AM/PM and footer-spacing failures in `5dc06e1`, before implementation. The
recording tests cover all future events, all six languages, both traditions and
the second before/at Parana.

The four requested app changes were subsequently approved and ported to Android;
see [the Android follow-up](ANDROID_FOLLOWUP_2026-10-22.md). The widget footer
spacing adjustment remains iOS-only.

Final local verification for this follow-up:

- **25 native app/rendering tests passed**, including measured footer separation.
- **All 27 Simulator UI tests passed**, including the six-language recording /
  Calendar sweep and previous preview, Home-link, reminder, search and navigation
  regressions (iPhone 17 Pro, iOS 26.5).
- **269 Swift core tests passed**; **746 Flutter tests passed**.
- `flutter analyze`: **no issues**; `git diff --check`: passed.

The deterministic Debug test clock also drives Home's date/selection and record
eligibility, so the fixed-date UI regressions remain repeatable after today.
Release builds continue using live time. Final native screenshots were inspected
for Tamil feedback, Calendar time endpoints and both Medium preview appearances.
No CI was run and no merge was made.


## Optional Glass Look (22 October 2026)

The iOS-only Settings appearance preference and its validation are documented in
[Optional Glass Look](IOS_GLASS_LOOK.md). It starts Off, preserving the current
app appearance, and does not alter WidgetKit designs or exported share cards.
The subsequently approved Android implementation is documented in
[Android Glass Look](ANDROID_GLASS_LOOK.md); Android widget designs remain unchanged.

## Lifecycle correction (23 October 2026)

The later approval replaces civil-date-only status and remaining-progress
behavior on iOS: keep the occurrence current through Parana end; fill progress
from fasting start to Parana start; show a pre-start seconds countdown, Now,
then Parana. Calendar/Details and isolated Debug-only testing are described in
[IOS_EKADASHI_LIFECYCLE.md](IOS_EKADASHI_LIFECYCLE.md). Android waits for iOS approval.
