# Offline premium roadmap

Approved by Arun on 18 October 2026. This document is written before feature
code on `feature/premium-journey`, branched from the latest remote `dev`.
It supersedes the dormant financial-rewards proposal for this work.

## Delivery and product boundaries

- One branch and draft PR against `dev` per phase. Finish and obtain approval
  for a phase before merging or starting the next phase from updated `dev`.
- iOS implementation and tests first. Push the reviewed iOS candidate before
  starting the Android port; Android follows Arun's iOS approval, preserving
  the standing iOS-first rule. No merge to `dev`/`main` without approval.
- Test first: demonstrate meaningful failing tests, implement, run new tests
  and required local regression suites. Every commit carries `[skip ci]`.
  Do not trigger CI without a new explicit request.
- All four phases work offline. No rewards accounts, remote ledger, backend,
  coins with monetary value, discounts, refunds, or redemption.
- Existing store-verified monthly, annual and lifetime purchases receive the
  same premium features. No local paid flag or purchase-verification bypass.
- Retain three free recorded Journey entries and three free achievement
  unlocks. History, editing, existing statistics/streaks and already-earned
  badges remain accessible after expiry. Do not silently make Journey free.
- Support English, Hindi, Tamil, Telugu, Gujarati and Bengali; preserve
  existing translations and use each language's script on visible surfaces.
- Preserve history, occurrence identities, earned achievements and one-time
  announcement markers across upgrades. No subscription feature may erase
  personal records. Never copy another provider's artwork or content.

## Phase 1 — Journey points, badges and annual collection

Status: iOS candidate and Android port implemented and locally validated.
Branch and PR stay `feature/premium-journey`, PR #25. Arun
authorized the Android port on 18 October after reviewing iOS screenshots.

### Scoring and annual scope

Implement for both 2026 and 2027, with annual points separate from lifetime
points. Use the engine-generated Home city/tradition schedule, not the older
bundled file: the 2027 bundle omits Saphala on 23 December, while the engine
includes occurrence `ekadashi:2027:25`. Annual totals are derived, never a
hard-coded assumption of 24 occurrences. The reference 2026 schedule has 24
and 2027 has 25; targets follow actual canonical schedule identities.

| Rule | Points |
| --- | ---: |
| Fully observed occurrence | 100 |
| Partially observed occurrence | 50 |
| Missed or unrecorded occurrence | 0 |
| All occurrences in a calendar quarter fully observed | 150 |
| All occurrences in January–December fully observed | 1,000 |

Reference perfect totals: 2026 = 2,400 + 600 + 1,000 = 4,000;
2027 = 2,500 + 600 + 1,000 = 4,100. Empty/incomplete schedules must not
accidentally earn completion bonuses. Do not award extra points for method,
badges, streaks, returning after a gap, or repeated saves. No multipliers,
negative points, public rankings, pressure to adopt a stricter fasting method,
or assertion that points measure devotion.

### Badge catalogue

Lifetime observed counts: First Step (1), Taking Root (5), In Bloom (10),
Twelve Lights (12). Reuse existing `first_vrat`, `vrat_5`, `vrat_10`,
`vrat_12` identities. Consistency: Steady Flame (3; existing
`consistent_observance`), Growing Rhythm (6), Unbroken Thread (12),
Twenty-Four Together (24). Streaks can cross year boundaries.

Encouragement: Welcome Back (fully observe after a missed occurrence),
Every Effort Counts (three partial observances). These award badges only.
Annual: First/Second/Third/Fourth Chapter for each completed calendar quarter,
and A Year of Dedication for every fully observed occurrence in that year.
Create distinct 2026 and 2027 annual identities; preserve the old
`full_year_observance` identity and any previously earned instance.

Earned badges remain earned after corrections; displayed points/progress
recalculate from current history. Premium expiry does not remove awards.
Locked badges show exact requirements and progress. Earned badges sort first,
then upcoming achievements in a deterministic order.

### Visual experience

- Annual mandala: one segment per canonical occurrence; full observation
  fills, partial uses a patterned fill, missed/unrecorded use distinguishable
  marks, future stays outlined. Use patterns and accessible text, not colour
  alone. Completed quarters add ornament, annual completion reveals a seal.
  It must remain attractive with gaps and work with 24 or 25 segments.
- Coherent original vector badge art: lamp, leaves, lotus, ring of lamps,
  flame, arcs, woven thread, wreath, sunrise, petals, matching quarterly
  medallions and a year-labelled lotus seal. Preserve the app icon registry
  for controls; custom badge art is drawn as artwork, not ad hoc SF Symbols.
- Overview: year picker, annual/lifetime points, observed/partial counts,
  current streak, mandala, next milestone and calendar-quarter progress.
- Collection: inspect a badge, locked/unlocked artwork, exact criterion,
  year and progress. Reduced motion, VoiceOver, Dynamic Type and narrow layouts.
- Group simultaneous unlocks in one celebration; optional haptics follow
  settings, respect reduced motion, provide View badge and dismiss actions.
- Optional user-initiated annual share card: mandala, year, points, selected
  earned badges and observed/partial totals. No notes or location by default.
  Sharing never happens automatically.

### Local integrity and storage

History is authoritative; calculate scores from unique canonical occurrence
UIDs rather than trusting persisted totals. Saving/editing/deleting recalculates
without duplicate earnings. Changing city/tradition does not duplicate an
occurrence. Quarter/year bonuses have deterministic year/quarter identities.
Future occurrences cannot score or earn awards. Past records may contribute
retrospectively because this is a personal honour-based journal.

Persist award and announcement markers with safe write ordering; mark a
celebration consumed when presented, and never lose observance history if a
secondary reward write fails. Reloading, repeated refresh, retries and store
expiry must not announce the same badge repeatedly. Preserve legacy awards.
No cloud dependencies. Local erasure can lose records; export/import backup
is a future enhancement, not a new login/sync feature in Phase 1.

### Test and review gates

Test partial/missed/unrecorded scoring, perfect 2026/2027, all four quarters,
year isolation, cross-year streaks, duplicate UIDs, location/tradition changes,
edits/deletions, future records, missing schedules, every badge condition,
legacy migration, free limits, monthly/annual/lifetime equality, expiry,
storage failure and one-time grouped celebrations. Add UI tests for year
selection, points, mandala, badge detail, premium CTA, grouped unlock and share.
Run Swift package tests and an iOS simulator build/UI checks, plus existing
Flutter analyzer/test gates as available. Document failures and unavailable
checks without claiming completion. Present the iOS draft PR for approval
before starting the Android implementation.

## Phase 2 — Personal birth profile

Status: planned; requires its own phase start after Phase 1 approval.

- Collect birth date, local birth time and birthplace; calculate at the exact
  UTC birth instant, never reuse sunrise Panchang values as birth results.
- Expose Janma Rashi (Moon sign), Janma Nakshatra, Pada and birth tithi with
  plain-language explanations. Keep the Lahiri convention explicit.
- Resolve the birthplace's historical timezone/DST. Handle nonexistent and
  ambiguous local times; request clarification rather than silently choosing.
- If time is unknown, scan the date and report stable values or alternatives
  and transition times. Do not fabricate precision.
- Store profiles locally with edit/delete. Never log birth details or send
  them to an astrology service. No full Kundali, dashas or planetary predictions.
- Validate independent reference instants across supported birth years,
  locations, signs, star/pada boundaries, leap dates and historical timezones.
  Document supported date range and uncertainty before making accuracy claims.

## Phase 3 — Family profiles and traditional birthdays

Status: planned, after validated Phase 2.

- Multiple named local profiles; names remain user text, profiles editable
  and removable, with explicit export/backup design considered separately.
- Calculate upcoming Nakshatra and tithi birthdays; define and review the
  solar/lunar month, leap month, repeated/skipped tithi and day-selection rules.
  Explain the selected tradition; no universal rule claims.
- Show next occurrences and full local dates; optional per-profile reminders,
  configurable lead time and notification permission flow.
- Schedule locally, refresh on app use, respect OS pending-notification limits,
  timezone changes and device restarts. Disable/delete cancels pending alerts.
- Test recurrence edge cases, family isolation, persistence, permission denial,
  DST, duplicate alerts and deletion/disable behavior.

## Phase 4 — My Panchang

Status: planned, after Phase 3 approval.

- Personal daily view combines the selected profile, current location's
  Panchang, birth-star-related information, upcoming birthdays and Journey.
- Any Tarabalam/Chandrabalam or personal timing feature requires explicit,
  independently reviewed traditional rules and explanations before release.
- Add selected timing windows and optional local daily notifications with
  time/language/profile controls. Core calendar reminders remain unaffected.
- Consider a future search for suitable windows based on transparent chosen
  rules; defer complex ceremony-specific Muhurta recommendations.
- Clearly distinguish computed astronomy from traditional interpretation.
- Test profile/location separation, day boundaries, optional notifications,
  premium gating, offline restart and accessibility across all languages.

## Explicitly deferred

Daily Rasi Palan, original/licensed prediction content, full Kundali/dashas,
financial rewards, server identity, cloud history/sync, public leaderboards,
transferable rewards and changes making all Journey functionality free.

## Execution evidence

### Phase 1 local evidence (18 October 2026)

- Plan committed first: `816e090`, before feature code, from remote `dev`
  at `d9d4cda7f5f000750ab38e4bed3fed19a89dd3b3`.
- Separate test-first commits cover scoring/catalogue (`f4d2b69`), annual UI
  (`bd852dd`), pending celebrations (`aa459b6`), corrupt reward metadata
  (`096fed6`, `272b549`), Home timezone (`1db1a0b`), vector/share rendering
  (`fa60b86`), next-goal selection (`b64296e`) and the recording/paywall
  flow (`3017355`). Red runs preceded the corresponding implementation.
  The final recording-flow red run failed on the missing stable row identity;
  its implementation adds explicit occurrence and celebration control IDs.
- `flutter analyze`: no issues. Full `flutter test`: **726 passed**.
- Full release `swift test` in `ios-native/EkadashiCore`: **272 passed**.
  This includes all existing package tests and the new Journey domain,
  persistence, migration, boundary and six-language checks.
- Simulator: iPhone 17 Pro, iOS 26.5. The previous full native run passed
  all 11 app tests, all three then-existing Journey UI tests and 13 of 14
  existing screenshot/UI tests. The remaining notification test attempted
  to inspect a row before the lazy Settings list created it. Its correction
  scrolls that row into view and keeps the original off/disabled assertions.
- Final focused simulator run: **11 native app tests and 5 UI tests passed**,
  including all four Journey UI tests and the corrected notification test.
  The end-to-end recording test observes three fasts, dismisses celebrations,
  confirms 300 points, and verifies the fourth entry opens Premium.
- Visually inspected exported badge-collection and annual-share screenshots,
  plus the mixed-status 25-segment 2027 mandala. Rendering tests cover both
  annual schedules, every badge at small/large sizes and consistent share
  output in light/dark mode.
- Evidence is local under ignored `outputs/premium-journey/`: analyzer and
  Flutter logs, `core-verified.log`, `ios-recording-red.log`, `ios-final.log`,
  `ios-verified.log` and Xcode result bundles/screenshots. CI was not run.

All 63 new Journey strings are present in English, Hindi, Tamil, Telugu,
Gujarati and Bengali. They now live in the shared ARB resources; both
platforms must match `test/fixtures/journey_translations.json` exactly. Arun explicitly authorized assistant-written
translations after the configured Claude session could not authenticate.
Language-key, placeholder and script checks pass; native-speaker wording
review remains release validation.

The Android port is authorized and included in the same branch and PR.
Real-device accessibility/haptics and store purchase/restore testing remain
release validation. The established StoreKit entitlement flow is unchanged. No
merge, backend, financial reward or later roadmap phase is included.


### Android port evidence (18 October 2026)

- Same feature branch and PR #25; no new product phase or purchase backend.
  An isolated checkout protects this work from simultaneous birth-profile
  development in the original checkout.
- Test-first commits: `006d139` for scoring/persistence and annual UI,
  `a8a96db` for vector rendering/grouped celebrations/sharing, `3cd574e` for
  narrow localized layouts and the full emulator flow. Red logs reproduce
  the absent features, missing grouped presentation, localized overflow and
  the Cupertino-switch parity regression before their fixes. `3eff3a4` adds
  the reduced-motion regression. `a797a35` demonstrates the Tamil placeholder
  ordering bug; named argument substitution now preserves translated order.
- Points, annual/quarter bonuses, catalogue identities and unlock ordering,
  corrected-history progress, permanent earned badges, pending presentation
  markers, free limits and Home timezone follow the Swift implementation.
- Original 100-unit badge paths and 24/25-petal mandalas are reproduced with
  Flutter Canvas. All controls use the existing AppIcons registry. The
  celebration respects reduced motion and the persisted haptic preference.
- Both platforms read the same approved strings. Journey overrides were
  removed from the iOS-only table after moving them to shared ARBs; effective
  iOS wording is unchanged. Native localization tests also verify the copy.
- The emulator test records observed/partial/missed entries, confirms 150
  points and the fourth-entry paywall, inspects badges and all categories,
  checks both years, the explicit annual share preview and the haptic toggle.
  It captures all Journey screens and the five non-English overviews.
- Local validation: 752 Flutter tests and 273 Swift core tests pass, with a
  clean Flutter analyzer and generated-file check. The final Pixel 9a
  emulator flow passes (including framework teardown), with 20 screenshots
  across both years, every Journey surface and all six languages. Logs are under ignored
  `outputs/premium-journey/android-*`; PNGs under
  `build/ui-screenshots/android/journey_*.png`. Store billing is unchanged;
  emulator tests do not claim a real Google Play purchase or physical haptic.


### Journey feedback implementation (30 October 2026)

- iOS first (`aadd601`), then matching Android work on PR #25. Overview uses
  the share card's dark teal gradient and a primary Share your year action.
  The exported card keeps a rounded inner surface over an opaque green matte;
  all four corners are tested so receivers cannot replace transparency with white.
- All four Journey subtabs share the year selection, defaulting to the current
  available year. All years combines History and Statistics and shows each
  annual Overview collection separately. Achievements shows the selected year's
  annual badges alongside lifetime milestones, or every year when All years
  is selected. History's year control resists compression; Statistics drops Year:.
- Observed, Partial and Missed remain on one row with compact scaling labels.
  Observed enables Full Fast, Water Only and Fruits/Milk; Partial enables only
  One Meal. Incompatible choices reset when status changes. Disabled methods
  stay visible and grey. Missed behavior and premium limits are preserved.
- TDD evidence: `d426294` adds the iOS policy/year tests; the native export
  pixel test fails on transparent corners before the opaque matte fix.
  `fa66724` adds Android parity tests before implementation, including all six
  languages at 320px and 1.4x text size. The focused Android run passes 26 tests.
- Local regression checks: 275 Swift core tests and 765 Flutter tests pass;
  all 13 native app tests and all five Journey UI flows pass, including the
  strengthened year/method test. Analyzer and generated-file checks are clean.
  The final Pixel 9a emulator flow passes, capturing 23 refreshed Android
  screenshots; iOS feedback screenshots and the opaque export are saved too.
- No merge from dev or conflict resolution was attempted. Each conflict still
  requires Arun's review and approval; dev wins outside Journey, while shared
  and Journey sections require individual decisions.
