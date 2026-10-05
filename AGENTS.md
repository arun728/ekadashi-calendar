# Repository collaboration rules

These rules record Arun's explicit instructions from 3 October 2026.

- Never push or merge to `dev` or `main` without Arun's explicit permission.
  `main` is protected; do not assume direct push access.
- Work on isolated branches for reviews, fixes and automated tests. Review
  concrete candidate commits and test evidence before requesting integration.
- Restore and integrate Search and all three Android widgets from PR #5 alongside
  the Vrat tracker, the 2026/2027 archive, Telugu and calendar changes. PR #6
  reverted the feature and was not the desired final product state.
- Arun explicitly authorized merging all requested changes to `dev` after all
  unit, native, regression, integration and UI tests pass. Keep `main` untouched.
- Follow TDD for functionality and UI fixes: demonstrate the failing behavior
  before fixing it, then run the relevant regression and full-suite gates.
- Google Calendar import covers the selected entire year and reconciles remote
  deletions atomically. Failed/partial imports preserve previously cached events.
- Audit every UI localization key, placeholders and unintended English fallback
  in Tamil, Hindi and Telugu. Do not enable paid translation billing implicitly.
- Run deterministic domain, regression, integration and UI tests automatically
  on Android emulators wherever practical; capture screenshots and logs. Reserve
  physical-device checks for OEM/hardware and real background reliability.
- Treat `feature/2027-telugu` as the confirmed source of the described 2027
  upgrade. Review and discuss its multi-year implementation/test plan before
  implementing the redesign. Preserve older Ekadashi data, observance history,
  streaks, achievements and one-time notification markers across upgrades.
- Calculation-engine work was previously deferred. The active, newer Panchang
  authorization below supersedes that deferral and any earlier branch plan.

See docs/INTEGRATION_POLICY.md, docs/TESTING.md and
 docs/UPGRADE_INTEGRATION_PLAN.md for the current review and proposed flow.

## Glass UI prototype and monetization (updated 4 October 2026)

Arun explicitly confirmed that all passing automated tests and screenshot/layout
checks are sufficient to merge `feature/android-glass-navigation` into `dev`.
This supersedes the earlier requirement for physical-device testing before that
UI dev merge. Samsung M52/Z Flip 5 checks remain release validation. Keep main
untouched.

After that validated UI merge, develop paid subscriptions and fasting rewards
on a separate branch. Do not merge paid/reward work to dev until Arun finalizes
and tests it and gives new explicit approval. Monthly INR99 / annual INR399 are
subscriptions; lifetime INR999 is a non-consumable purchase. Google Calendar
sync is paid; custom entries and core Ekadashi features remain free. Remove
Vrat enable/disable: recording/history/streaks/statistics are always free, with
three free achievement unlocks and additional achievements in premium. Preserve
all history and existing earned badges. Rewards are non-cash premium-access
credit, not cash refunds. Use Google Play billing and secure server verification;
never grant purchases from a local flag or pending/unverified transaction.

## Panchang engine (approved 4 October 2026)

Arun explicitly authorized a new Panchang implementation on a clean branch from
`dev`. The active branch is `feature/panchang-engine`; do not merge it to `dev`
or `main`. Implement only in this branch and open a PR against `dev`, ready for
review after the requested automated checks pass.

- Navigation keeps five bottom tabs: Today, Calendar, Vrat, Panchang, Settings.
  Panchang replaces the old Search tab; preserve the Vrat tracker. Move Search
  to a search action in the top app bar and preserve `ekadashi://search` links.
- Panchang calculations and labels are English-only and use Indian Standard
  Time (UTC+05:30) with a selectable, curated Indian city for coordinates.
  Never use the device timezone or offer non-Indian cities for Panchang.
- Build a deterministic, offline calculation engine. Do not scrape Drik
  Panchang or copy its text, event database, visual assets, or branding. Public
  Panchang listings may inform feature coverage; cite astronomical references
  and validate calculations against independent published ephemeris/phase data.
- Keep astronomical primitives separate from named observance rules. Explain
  the selected sunrise/sunset/night rule and month convention in documentation;
  make regional/Smarta/Vaishnava differences explicit and extensible. Do not
  claim universal coverage where rule profiles are not reviewed. Existing
  Ekadashi fasting/parana data remains authoritative for the current Vrat UI.
- Panchang's detailed limbs, timings, city-aware observances and browseable
  calendar are premium. Retain a useful free daily preview and use the existing
  server-verified premium entitlement/paywall. Do not gate existing Vrat
  recording/history or the established Ekadashi calendar.
- Follow TDD: first commit/record failing engine and navigation/widget tests,
  then implement. Run analyzer, all existing Flutter tests, UI screenshots,
  Android CI/emulator checks available in this repo, and report unavailable
  checks honestly. Do not merge or mark any other branch ready.

See `docs/PANCHANG_PLAN.md` for research references, the first-release rule
scope, and calculation/UX boundaries.

## Play-only premium for v2 (approved 5 October 2026)

Arun explicitly changed the monetization rules above. This section supersedes
the earlier server-verification, rewards and "Vrat always free" instructions.
Work lives on `feature/play-premium-paywall` (branched from
`feature/panchang-engine`, same five tabs); open a PR to `dev`, mark it ready
for review, and do not merge it to `dev` or `main`.

- No backend for v2. Premium comes only from Google Play Billing's owned
  purchases on the device (`queryPastPurchases` + purchase stream), never from
  a persisted local flag or a pending purchase. Acknowledge completed purchases.
  The paywall needs no Google sign-in. Google sign-in is only for Calendar
  import, and disconnecting Google must not affect premium.
- Products (prices are set in Play Console, never hard-coded): subscription
  `ekadashi_premium` with base plans `monthly` (INR99) and `yearly` (INR499);
  one-time `ekadashi_premium_lifetime` (INR999).
- Hide fasting rewards/coins from the app for now (no wallet, redemption or
  cloud account UI). The `backend/` service is dormant and not used by v2.
- Free vs premium (three premium features for v2):
  1. Google Calendar import (import only): free users get one sync ever, of
     the month being viewed (normally the current month). Every later sync
     needs premium, which imports the whole selected year in one go. Premium
     is re-checked with Google Play at each sync, so a cancelled or expired
     subscription stops syncing until the user pays again; already imported
     events stay on the device.
  2. Vrat: the first three recorded entries are free; recording a fourth new
     entry needs premium. Existing entries stay editable and all history,
     streaks, statistics and earned badges are preserved.
  3. Panchang's full details stay premium; the daily preview stays free.
