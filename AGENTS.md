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
- Calculation-engine work follows Daily Devotion batches 1 and 2; see the
  approved plan below. Do not mix engine work into those batches.

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

## Approved Daily Devotion plan (4 October 2026)

Arun merged subscriptions/rewards PR9 into dev and explicitly approved the
navigation and batches below. Implement on `feature/daily-devotion`, created
from dev `23a81ce5b75f320482c33dae7e069868477219b9`. Earlier v2/UI merge
permissions do not apply to this work. **Do not merge or push to dev or main.**
Feature-branch commits, pushes and CI validation are authorized. Write/update
this plan before implementation and keep completed/pending work accurate.

Navigation: Today, Calendar, Practice, Library, Settings (five bottom tabs).
Global search remains available through an app-bar action and Library search.
Practice contains routines, Japa and the existing Vrat tracker. Library contains
Listen and Learn. Preserve old widget/search/Vrat links, calendar state, history,
earned achievements, notification preferences and the existing glass appearance.
Today retains next Ekadashi/parana and adds daily practice shortcuts. A compact
audio player will sit above navigation and persist across screen changes.

### Batch 1 — daily routines and Japa (implemented; local tests pass, Android CI pending)

- Free: one simple local routine, a basic chanting counter/timer and basic
  practice streak. All existing free Ekadashi/Vrat/search/custom-calendar/widget
  features remain free, including the first three earned achievements.
- Premium: multiple routines, weekday scheduling/reminders, saved mantra goals,
  configurable mala rounds/haptic cues, saved chanting session history and
  weekly insights. Premium expiry must retain data and allow access to existing
  personal history; gate creation/advanced actions rather than erase records.
- Persist practice independently of Vrat and its reward wallet. Recover active
  sessions across restart; avoid duplicate counting/completion on retries.
  Chanting/app opens must not award fasting coins or change reward economics.
- Scheduling respects timezone changes, notification consent and quiet hours;
  no background notification may start before the user enables it.

### Batch 2 — devotional audio and stotra learning (infrastructure implemented; production audio pending)

- Free: a small complete rights-cleared starter collection, selected texts/basic
  meanings and basic playback. No removal of currently free content.
- Premium: offline collections, playlists, repeat/108-cycle playback, sleep timer,
  line-by-line original recitation, synchronized highlighting, pronunciation
  practice, transliteration, bookmarks and spaced revision.
- Document provenance/license, commercial/offline rights, performer permission,
  translations and artwork for each production asset. Traditional text does
  not clear a modern recording or translation. No scraped/stream-ripped songs,
  noncommercial-license assets, cloned voices or unreviewed generated content.
  Test audio fixtures must be clearly distinguished from production recordings.
- Handle interruption/resume and concurrent chanting/playback. Content additions
  need reviewed pronunciation and accurate en/ta/hi/te presentation.

### Batch 3 — full Panchang (next, after batches 1 and 2)

Arun requested a full engine covering Hindu festivals and occasions including
Amavasya, Purnima/Pournami, Ekadashi, Dwadashi, Shivaratri and Pradosham.
Clarify the requested "shiva nami" observance when defining its catalog.
Use a licensed/compatible astronomical engine or independently reviewed
calculations plus a separate regional/tradition-specific observance-rule layer.
Define supported calendars/traditions, locations, leap-month rules, sunrise/DST
handling and reference fixtures before implementation; do not claim all Hindu
festivals from tithi calculations alone. Present daily Panchang in Today and
date/festival details and filters in Calendar. Basic daily summary is planned
free; multi-city comparison, advanced planning/reminders and printable schedules
are proposed premium, to be finalized with Arun before engine implementation.

Family profiles, festival preparation journeys, journals, cloud backup and extra
widgets are later ideas, not part of approved batches 1 and 2.

### Paid access and validation

Reuse server-verified PremiumService for monthly INR99, yearly INR399 and lifetime
INR999; do not add local premium flags or silently change existing prices.
Google Calendar sync and achievements beyond the first three remain premium.
Reward earning remains free: 300 fasting coins redeem six months of premium.
Production billing/backend/legal/rights setup remains separately required.

Use TDD: demonstrate meaningful failing tests, implement, then verify passing
domain, persistence, widget, navigation and integration regressions. Preserve
backend/native gates. Run CI Android API24/33/35 plus notification-denied/GPS-off
coverage, four languages, both themes, large text and screenshots before device
testing. Record actual results; emulator fixtures do not prove real Play billing
or production audio rights. No merge to dev without new explicit instruction.

Implementation details and content boundaries: docs/DAILY_DEVOTION_PLAN.md.
Exact test evidence: docs/review/daily-devotion-validation.md.
