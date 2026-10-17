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

The circular Lock Screen widget scales the app artwork and count to the host
slot (tested at 48, 62 and 76 points), with a one-line day countdown, or the
remaining percentage and a progress ring today. The rectangular accessory shows the icon, Ekadashi name, countdown/remaining
percentage and date. Both respect WidgetKit's system rendering mode.

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
