# UI parity review and continuation

Review branch: `feature/ui-parity-resume`, based on `feature/ui-parity` at
`d74893a`. This keeps the latest screen parity implementation and adds the
confirmed fixes below. Reference: Arun's four iPhone screenshots and the
native views in `ios-native/EkadashiCalendar/`.

## Fixes on this branch

- Larger Cupertino magnifying-glass icon (30dp) on all five tab toolbars,
  with at least a 44dp touch target, including narrow screens.
- Cupertino circular sync, sync, and person-minus Google disconnect icons.
  Include the icon font in app assets and offscreen screenshot tests.
- Home's language menu opens above the app instead of pushing a route
  into Home's page stack. Opening it keeps the toolbar and card position.
- Track actual page routes separately from popup overlays. Journey's year
  menus and Panchang's location menu keep their toolbar and layout, while
  pushed screens still use their own toolbar. Android Back dismisses the
  active tab's popup before leaving the app.
- Update Android integration regressions alongside the local widget checks.
  Other source edits only address analyzer lints (braces and const).

The source already contains dark selected-tab pills, glass Home/Details,
Calendar controls and entries, Journey cards and sheets, Panchang controls
and pages, Search/Premium sheets, and Settings/reminder/widget-gallery
parity. The continuation does not change iOS, shared data, translations,
purchase rules, notification behavior, or calendar calculations.

## TDD and local verification

- `38541ca`: failing large-search and Google-glyph tests before the icon fix.
- `af0e990`: failing Home language-menu toolbar/layout test before its fix.
- `fc3a17f`: failing Journey and Panchang menu toolbar/layout tests before
  the shared navigation fix.
- `71e0e31`: failing system-Back dismissal regressions during that fix.
- Expanded checks cover all six language transitions, preservation of the
  selected fast and Details target, previously opened tabs retaining dates
  and sections, and 320dp screens with 2x text. All 28 focused icon, language,
  overlay, and shell tests pass.
- Analyzer: no issues. Full Flutter suite: **661 tests pass** (13 October
  2026), including regression, localization, offscreen UI, SQLite, and the
  Swift/Dart Panchang fixture comparison.
- Swift core: 214 tests pass; Python runner/tool tests: 26 pass. Their sources
  are unchanged since these local runs. SQLite FFI tests use the system
  library via the workspace's local library path, without an app change.

Rendered PNGs under `build/ui-screenshots/offscreen/` cover all six languages
and additional light/dark Settings, Premium, and Panchang layouts. These use
mock native channels and are layout evidence, not device captures.

## Device verification

On Android, use this branch's build:

1. Home: browse to another fast, open the language menu, and select Hindi,
   Tamil, then English. The top search/title and card must stay in place
   while the menu is open. The same fast remains selected; Details and
   Settings use the new language.
2. Journey: open History and its year menu (also Statistics' year menu).
   The toolbar and section chips must stay in place. Android Back closes
   the menu and leaves Journey open.
3. Panchang: open the city menu, cancel with Android Back, then reopen and
   choose a city. The toolbar stays visible, and cancel preserves the date
   and location. Changing language on Home preserves the selected Panchang
   date and section when returning.
4. Check the large search glyph on every tab and the Google sync/disconnect
   glyphs in Calendar. Compare against the same screens on iPhone.

Native Android builds/emulator tests and iOS app/XCUITests were not run:
Android SDK/ADB and Xcode are unavailable here. Real Google authorization,
store purchases, and platform glass rendering require device validation.
No new iOS fix is claimed; its native menus are the parity reference.

No CI is authorized. Every pushed commit includes `[skip ci]`. Keep the PR
draft for Arun's device review, and do not merge or push to dev/main.
