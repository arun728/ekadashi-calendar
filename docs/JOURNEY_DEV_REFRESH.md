# Journey on current dev — acceptance and delivery plan

Approved 30 October 2026. Branch `feature/journey-dev-refresh` starts at dev
`ed0fad09ad68a3285c0bc22d765bb21823f6c29a`. PR25 at `7b5d146` is a reference,
not a merge source. Keep its branch and PR intact until Arun approves a replacement.
No writes to dev/main, no automatic conflict resolutions, no CI. All commits
carry `[skip ci]`. Implement/test/push iOS first, then Android.

## Complete Journey acceptance checklist

- [ ] Use Home city/tradition engine schedules and stable occurrence identities
  for 2026 and 2027. Reference schedules: 24 and 25 occurrences; compute targets
  from actual schedules. Future occurrences cannot earn points.
- [ ] Observed 100, partial 50, missed/unrecorded 0; complete quarter +150;
  complete calendar year +1000. Reference targets 4000/4100. Annual totals
  separate from lifetime totals; corrections, deletions and duplicate saves
  recalculate rather than accumulate. Cross-year streaks continue.
- [ ] Preserve the six original achievement identities, earned dates, observance
  history, old records and announcement markers. Add milestones 1/5/10/12;
  streaks 3/6/12/24; return-after-missed and three-partial encouragement; four
  quarterly chapters and annual completion per year. Permanent earned badges.
- [ ] Matching vector badge art and patterned mandalas: filled observed,
  hatched partial, crossed missed, dashed past unrecorded, outlined future;
  quarter ornaments/year seal; exact unlock requirements/progress and earned dates.
- [ ] Group simultaneous unlocks once; mark presented only when shown; support
  optional persisted haptics and reduced motion. Open badge details from collection
  and celebration. Persist pending awards; corrupt/failed badge storage must
  preserve journal access/data, avoid overwriting corrupt bytes and permit retry.
- [ ] Preserve three free new records and three free badge unlocks. Existing
  records/history/statistics/streaks/earned badges stay available after expiry.
  Monthly, annual and lifetime receive identical premium access. No paid local
  flag, login, backend, monetary redemption, subscription discounts or later phases.
- [ ] Four subtabs: Overview, History, Statistics, Achievements. Current available
  year default; 2026/2027/All years selector on every subtab. Selection shared.
  All-year Overview shows each annual collection; History combines occurrences;
  Statistics combines counts with weighted completion; Achievements filters
  annual badges while retaining lifetime milestones. Categories remain available.
- [ ] Overview uses the annual share card's dark teal gradient and readable
  foreground colors. Bright primary Share your year button. Keep lifetime totals,
  next milestone, chapters, scoring explanation and premium messaging.
- [ ] Share explicitly renders a self-contained annual image with optional earned
  badge selection, no private notes/location. Preserve rounded inner card over
  opaque green export corners (all four pixels tested), consistent light/dark.
- [ ] History year label fully visible. Statistics removes redundant Year: label.
  Observed/Partial/Missed labels fully visible on one row with compact gaps.
- [ ] Observed enables Full Fast/Water Only/Fruits-Milk; Partial enables only
  One Meal. All other methods remain visibly grey and disabled; incompatible
  choices normalize on load/status changes/save. Preserve Missed behavior.
- [ ] All six languages exactly retain the approved 63 Journey strings, preserve
  dev widget/Glass wording, keep named-placeholder order (especially Tamil),
  correct scripts/date format, and regenerate all shared resources.
- [ ] Respect dev's Glass Look controls/sheets in both modes while preserving the
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

Pending implementation and checks. Update the checklist/results from actual evidence.
