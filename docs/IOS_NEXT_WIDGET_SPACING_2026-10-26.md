# iOS Next Ekadashi Small/Medium spacing — 26 October 2026

Follow-up on PR #24, `feature/ios-widget-redesign`. Android is outside this change.

## Changes

Only the **Next** state of the single Ekadashi widget changes. Small retains its countdown, name and date, groups the date with the name, and adds the actual localized city and tradition as two footer lines. Medium distributes its identity/date, fasting timing columns and location/tradition footer vertically, with at least 8 pt category gaps instead of a centered compact block. A 3 pt bottom ink inset protects Indic descenders. The Today renderer and Upcoming widget retain their existing layouts, and Lock Screen layouts do not change.

Settings and WidgetKit share `EkadashiWidgetView`, so dark/light previews use the same layout. No duplicate preview mock, new clock control, schedule/selection change, Android source change or billing/signing change is introduced.

## TDD and validation

Red commit `4f5b57b` precedes implementation. Render tests reproduced Small ignoring both location and tradition in all six languages/appearances, and Medium failing the vertical distribution checks. The subsequent complete native suite found a Telugu descender escaping the edge-to-edge Medium bounds; the ink inset fixes it, and the expanded matrix includes both zero padding and normal 16 pt widget padding.

The layout matrix covers English, Hindi, Tamil, Telugu, Gujarati and Bengali; Smarta/Vaishnava; dark/light; the longest bundled names; long localized location names; future days and the fasting-date countdown just before start; Small 158/170 pt, Medium 320×158/360×170 pt; normal/xxxLarge text; and edge-to-edge/normal widget padding. Pixel checks measure footer clearance and occupied height. Small's rendered output must change when its city or tradition changes.

Before/after attachments independently check the excluded renderers: 96 Today/Upcoming/Lock Screen images must remain identical, while the 24 Next Small/Medium images change. Actual Settings integration runs cover every language, both sizes, both appearance previews and the preview's Home link. Today preview screenshots are captured with a pinned Debug clock.

Final results before push:

- Analyzer: no issues; complete Flutter suite: **860 passed**.
- Complete Swift core suite: **286 passed**.
- iOS 18.6 hosted suite: **45 passed**, no skips or failures.
- iOS 26.5 hosted suite: **45 executed, 44 passed and one known local-StoreKit-catalog skip**, no failures. That catalog check passes on 18.6.
- Actual Next Settings previews and Home links: **passed in all six languages**, Small/Medium with both appearance cards. Actual Today/progress/Lock Screen previews also passed in all six languages.
- Changed executable widget lines: **57/57 (100%)**. This is changed-line execution coverage, not a new claim of whole-app 100% coverage.
- Final pixel comparison: **96 excluded renders byte-identical; only the 24 Next Small/Medium renders changed**.
- Normal Apptinel-signed iPhone app/extension build: succeeded. Installation follows the tested commit push.

Logs/results: `next-spacing-hosted-green` (complete 18.6 suite), `next-spacing-verified` (complete 26.5 suite plus Next integration), `next-spacing-engine-boards` (final engine-backed screenshot boards). The Today integration passed in `next-spacing-final`; that earlier bundle also records the pre-fix Telugu overflow and a test-navigation mistake. It is not described as a wholly passing bundle. The Next test now returns from the preserved Settings preview stack before reopening it; app navigation behavior is unchanged.

Local evidence: `outputs/next-widget-spacing/` (ignored screenshots, manifests and pixel comparison results). Native run logs are alongside the checkout (`../next-spacing-*.log`). No failed bundle is described as passing; final results distinguish the known iOS 26 local StoreKit-catalog skip from the complete iOS 18.6 hosted suite.

## Testing Today without waiting for another Ekadashi

The screenshots use Papankusha Ekadashi, 22 October 2026 in Chennai. Final native render boards use Home's Chennai/Vaishnava engine schedule and pin the clock halfway between fasting start and Parana start, so the ring shows 50%; actual Settings screenshots also use a pinned fasting instant. No phone date change is needed.

For manual testing, launch a **Debug** build from Xcode with `-lifecycle-testing` in Scheme → Run → Arguments. Open Settings → Lifecycle test clock, select the occurrence, keep speed Paused and tap Halfway · 50% (or Fast starts / Parana / Parana ends). Home and Settings widget previews follow that clock. To leave it, remove the launch argument and launch normally. Settings/history and widget test snapshots are isolated, recording/notifications are disabled in the test session, and this feature is compiled out of Release. The normal update installed on Arun's iPhone is launched without test arguments.
