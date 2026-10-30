# Journey on current dev — acceptance and delivery plan

Approved 30 October 2026. Branch `feature/journey-dev-refresh` starts at dev
`ed0fad09ad68a3285c0bc22d765bb21823f6c29a`. PR25 at `7b5d146` is a reference,
not a merge source. Keep its branch and PR intact until Arun approves a replacement.
No writes to dev/main, no automatic conflict resolutions, no CI. All commits
carry `[skip ci]`. Implement/test/push iOS first, then Android.

## Complete Journey acceptance checklist

- [x] Use Home city/tradition engine schedules and stable occurrence identities
  for 2026 and 2027. Reference schedules: 24 and 25 occurrences; compute targets
  from actual schedules. Future occurrences cannot earn points.
- [x] Observed 100, partial 50, missed/unrecorded 0; complete quarter +150;
  complete calendar year +1000. Reference targets 4000/4100. Annual totals
  separate from lifetime totals; corrections, deletions and duplicate saves
  recalculate rather than accumulate. Cross-year streaks continue.
- [x] Preserve the six original achievement identities, earned dates, observance
  history, old records and announcement markers. Add milestones 1/5/10/12;
  streaks 3/6/12/24; return-after-missed and three-partial encouragement; four
  quarterly chapters and annual completion per year. Permanent earned badges.
- [x] Matching vector badge art and patterned mandalas: filled observed,
  hatched partial, crossed missed, dashed past unrecorded, outlined future;
  quarter ornaments/year seal; exact unlock requirements/progress and earned dates.
- [x] Group simultaneous unlocks once; mark presented only when shown; support
  optional persisted haptics and reduced motion. Open badge details from collection
  and celebration. Persist pending awards; corrupt/failed badge storage must
  preserve journal access/data, avoid overwriting corrupt bytes and permit retry.
- [x] Preserve three free new records and three free badge unlocks. Existing
  records/history/statistics/streaks/earned badges stay available after expiry.
  Monthly, annual and lifetime receive identical premium access. No paid local
  flag, login, backend, monetary redemption, subscription discounts or later phases.
- [x] Four subtabs: Overview, History, Statistics, Achievements. Current available
  year default; 2026/2027/All years selector on every subtab. Selection shared.
  All-year Overview shows each annual collection; History combines occurrences;
  Statistics combines counts with weighted completion; Achievements filters
  annual badges while retaining lifetime milestones. Categories remain available.
- [x] Overview uses the annual share card's dark teal gradient and readable
  foreground colors. Bright primary Share your year button. Keep lifetime totals,
  next milestone, chapters, scoring explanation and premium messaging.
- [x] Share explicitly renders a self-contained annual image with optional earned
  badge selection, no private notes/location. Preserve rounded inner card over
  opaque green export corners (all four pixels tested), consistent light/dark.
- [x] History year label fully visible. Statistics removes redundant Year: label.
  Observed/Partial/Missed labels fully visible on one row with compact gaps.
- [x] Observed enables Full Fast/Water Only/Fruits-Milk; Partial enables only
  One Meal. All other methods remain visibly grey and disabled; incompatible
  choices normalize on load/status changes/save. Preserve Missed behavior.
- [x] All six languages exactly retain the approved 63 Journey strings, preserve
  dev widget/Glass wording, keep named-placeholder order (especially Tamil),
  correct scripts/date format, and regenerate all shared resources.
- [x] Respect dev's Glass Look controls/sheets in both modes while preserving the
  approved fixed Overview/share palette. Verify narrow/large-text layouts,
  accessibility labels, icon registry and optional haptics.

## Dev foundation and integration boundaries

Keep dev's Home/Calendar/Panchang/widget schedules, performance/cache changes,
selected-year helpers, lifecycle handling, default tradition, Glass Look settings,
premium verification and purchase flows. Add only scoped Journey state, haptic
settings, grouped-award routing and compact recording controls to shared files.
Never replace a shared file wholesale with an older PR25 version. Escalate any
ambiguous requirement or unrelated behavior change before implementing it.

Keep iOS company team `65HTQTRP96`, app `com.apptinel.ekadashi-calendar`, widget
`com.apptinel.ekadashi-calendar.widgets`, App Group
`group.com.apptinel.ekadashi-calendar`; runtime and entitlements use APP_GROUP.
Keep Android production application ID/namespace
`com.applausestudios.ekadashi_calendar` as on main/live v1. Android widgets remain
components of that app, with no new app ID/account/App Group. Preserve dev's
separate preview-build identity. Release signing and version-code continuity
are required for a true v1-to-v2 update.

## Delivery and evidence

1. Commit this checklist before implementation; add/reuse missing-behavior tests
   and record red runs before bringing each platform's implementation over.
2. Build/test iOS on dev's controls and shared state, validate native app/UI tests,
   full Swift core tests, Flutter analyzer/regressions, then push the iOS candidate.
3. Port/test Android on the same branch. Run six-language 320px/large-text cases,
   all Flutter tests, Kotlin/widget regressions and relevant emulator flows.
4. Regenerate resources; audit every changed non-Journey file against dev and
   record why each small integration change is necessary. Confirm untouched
   Home/Panchang/widget production code and assets remain byte-identical.
5. Capture screenshots in both Glass modes; check native app/widget signing and
   production Android identity. Preserve data in migration fixtures. A Play-signed
   v1-to-v2 upgrade, real purchases, physical-device background behavior/haptics
   and native-speaker wording are release checks if unavailable here; do not
   substitute an uninstall/reinstall for upgrade validation.
6. Open a new draft PR to dev with full scope/evidence and a link to PR25.
   Do not merge, close PR25 or trigger CI without explicit approval.

## Validation results

Implementation acceptance is complete on both platforms; release-only checks below
remain explicitly separate. No production signing key or live store purchase was exercised.

| Check | Result |
|---|---|
| Full Flutter suite | 929 passed |
| Full Swift core/resource suite | 324 passed |
| Kotlin/widget unit suite | 89 passed, 11 suites |
| iOS app/widget/Glass/Journey UI | 61 checks passed across iOS 26.5 and 18.6; the initially skipped catalog check passes on 18.6 |
| Final shared-resource iOS render/Glass rerun | 8 passed |
| Android Pixel 9a full Journey flow | Passed, including persisted One Meal, paywall, all six languages and both Glass modes |
| Analyzer / formatting / generated resources | Clean |
| Company app/widget device build | Signed build and codesign verification passed |
| Built Android identity | com.applausestudios.ekadashi_calendar, versionCode 5, versionName 2.0.0 |
| Existing dev translations | Every value retained; 63 approved Journey values added per language; 586 shared keys |
| Evidence | 18 iOS and 27 Android screenshots, both Glass modes, plus test logs in the local evidence directory |

The existing catalog integration check was initially skipped on the iOS 26
command-line runner, then passed on iOS 18.6 with the local StoreKit catalog
(1 passed, no skip/failure). Real store purchase/restore, physical background behavior,
haptics/accessibility, native-speaker wording and a Play-signed installed-v1 upgrade
remain release validation. Main source is 1.1.1+4; dev remains 2.0.0+5. Production
Play signing/version-code continuity must also be checked against Play Console.

## Final shared-file scope audit

| File/area | Scoped Journey change; dev foundation retained |
|---|---|
| iOS AppModel | Badge haptic state, queue deduplication, schedule zone supplied to Journey. Dev initializer, performance caches, widget navigation, lifecycle and default tradition retained. |
| iOS RootView | Grouped-award sheet and actual-presentation markers. Dev scenePhase task, tab routing and Glass system-bar policy retained. |
| Settings on both platforms | One Journey haptic-preference row using dev's existing controls; no existing sections removed. |
| Android main.dart | Three Journey bridges: premium refresh awards, tracker schedule/zone initialization and grouped awards after Home saves. Dev's Home button/blocked-state toast, timing, lifecycle and navigation retained. |
| Android ios_style.dart | Opt-in compact chip layout only, default false. Dev's Glass rendering, modal dismissal, toolbar/sheet controls and all other chip users retained. |
| iOS project/entitlements | Two entitlement strings use APP_GROUP; company team, bundle IDs, URL name and group default stay from dev. |
| Localization | Add approved Journey keys/metadata to dev ARBs, regenerate; iOS-only override table is byte-identical to dev after moving Journey to shared resources. |

Automated diff audit confirms these production areas remain byte-identical to dev:
Android native code/build configuration; assets; iOS Shared, Today, Calendar and
Panchang features; iOS widget code/assets (only the entitlement alias differs);
Panchang and purchase-verification services; package/dependency configuration.
Existing dev AppModel/Screenshot/Home parity tests are retained. Only unchanged-from-
base Journey tests were updated for the new Journey labels and presentation.

Draft replacement PR: #32. PR25 remains unchanged at 7b5d146; dev at ed0fad0 and
main at e8041e4 are unchanged. No old-branch merge, force-push, CI or dev/main write.


### iOS candidate evidence

- Test-first commit `8e93412`; initial compile fails because JourneySummary and
  method/filter APIs are absent. Platform red run then catches missing Journey
  translations and literal entitlement groups before their fixes.
- 324 Swift core tests pass. Dev's full Flutter baseline passes 887 tests,
  analyzer clean. Native app/widget/Glass unit tests plus all six Journey UI
  flows pass: 60 passed, one existing StoreKit catalog check skipped because
  this command-line iOS 26 runner does not provision its local catalog.
- Both Glass modes have Journey screenshots. Device build succeeds and codesign
  verifies company team, both bundle IDs and matching runtime/signed App Group.
- Dev Home/Calendar/Panchang/widget code, assets and Android implementation/IDs
  remain unchanged. Scoped shared changes: badge haptic preference, pending
  grouped-award routing, Home timezone supplied to Journey, and a Settings row.
  Dev's scene lifecycle, caches, widget links and default tradition are retained.
- Android completion and shared-resource evidence are recorded in the final results above.


## Follow-up audit and share polish (30 October 2026)

See [JOURNEY_REGRESSION_AUDIT.md](JOURNEY_REGRESSION_AUDIT.md) for the comparison
against PR25, the existing strict streak/partial semantics, test coverage gaps,
and red/green evidence. Both platforms now initially include every earned badge
on the annual share card; users can deselect them. The personal/no-monetary-rewards
sentence is removed from the visible Overview in every language. Scoring and
streak policy are unchanged. Full Flutter suite now passes 937 tests and Swift
core passes 325.


## Approved consistency/reversal update (30 October 2026)

The latest user-approved policy supersedes the original strict-current-streak
and permanent-badge rules. See [JOURNEY_CONSISTENCY_AND_REVERSAL.md](JOURNEY_CONSISTENCY_AND_REVERSAL.md).
Current consistency ends at the latest recorded event and counts full or partial
observances, with internal gaps/misses breaking it. Full-observance streak badges
and annual completion remain strict. Editing/deleting history relocks badges
whose original requirements no longer hold. iOS first, then Android; simulator
flows prove three entries -> streak three -> delete middle -> streak one and
badge locked. Final gates: 941 Flutter, 330 Swift core, 89 Kotlin, 62 native passed
(one known catalog skip), analyzer and generated files clean.
