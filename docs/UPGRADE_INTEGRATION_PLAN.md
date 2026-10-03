# Multi-year and 2027 feature integration proposal

Historical design proposal, 3 October 2026. Arun subsequently approved this
implementation and the tested combined candidate for `dev`. The implemented
behavior and current gates are recorded in `V2_IMPLEMENTATION.md` and `TESTING.md`.
Calculation-engine work remains deferred. Statements below about future work,
missing translations and awaiting permission describe the original assessment.

## Reviewed source and comparison

Arun confirmed `feature/2027-telugu`, commit
`6283e08d77ca3376ad0b483ba2c31fda29e82d28`, as the upgrade source. The repository's
older `upgrade` branch is not the source of these 2027 features.
Compared this branch with main `e8041e4fef67273d026e26c03c72ca62dc586fab` and read
the changed production code, native widget, data schema, integration setup and
existing tests. It has 41 changed files and 5,107 insertions/886 deletions.

| Area | Main | 2027 branch | Integration consequence |
|---|---|---|---|
| Official data | 24 rows for 2026 | Same asset path replaced with 24 rows for 2027 | Bundle both year packs; never overwrite archives |
| IDs | Integers 1–24 | Integers 1–24 reused | Unsafe for PR4's history dictionary keyed only by integer |
| Languages | en/ta/hi UI and content | Adds te UI and all five content fields for all 24 2027 events | 2026 Telugu still needs content or an explicit English fallback |
| Calendar range | Hardcoded 2026 | Hardcoded Jan–Dec 2027 | Derive range from selected year and available packs |
| Calendar entries | Official Ekadashis only | SQLite custom and Google-imported entries | Keep official, personal and imported records distinct |
| Category filters | None | All/Ekadashi/Google/Custom | Year and category are independent filters |
| Google Calendar | None | Read-only import for the focused month | Not export or two-way sync; OAuth still needs validation |
| Widgets | None on main | Separate home_widget provider and payload | Overlaps Ragul's native widget architecture on dev |

The 2027 branch's analyzer currently reports two test compilation errors:
`ekadashi_widget_service_test.dart` returns a String where Future<bool?> is
required, and `google_calendar_service_test.dart` omits required calendarIds.
The attempted Flutter test run also hit this environment's native SQLite asset
certificate/download setup. There is no passing upgrade-suite result to claim.
The branch's checklist saying “ready” is not runtime validation.

## Core design

Introduce one CalendarRepository used by Home, Calendar, Tracker, search,
notifications and widgets. It combines immutable versioned year packs and
queries by year, occurrence ID, location/timezone and tradition. Start with
bundled 2026 and 2027 packs plus a manifest of available years and revisions.
A later year is an added pack, not a replacement of the previous calendar.
Do not assume every year has exactly 24 events: annual totals come from the
validated, tradition-adjusted occurrences for that year.

A stable string occurrence UID must distinguish 2026 event 1 from 2027 event 1.
For the existing data, assign an explicit UID such as `ekadashi:2026:01` in each
pack. Keep the localized content ID separate, since stories/names can be reused
across yearly occurrences. Do not derive identity from translated names or the
phone's current date. Later calculation revisions must keep these assigned UIDs
stable. Location/tradition timing variants belong to an occurrence; a recorded
observance also retains its original local date, timezone, tradition and name
snapshot, so travel or a data update cannot silently rewrite history.

Use separate records for official occurrences, observances, earned achievements,
custom entries and imported Google entries. Never count a personal appointment
or Google holiday toward a fasting streak. The existing SQLite repository is a
reasonable base for durable user records; migrate PR4's SharedPreferences data
transactionally in a separate reviewed change rather than clearing preferences.
A year-pack repository can remain lightweight/in-memory at this scale.

## Proposed customer flow

Recommended pending discussion: put a Year dropdown beside the Calendar header
and year selectors in Tracker History/Statistics. Preserve the existing
All/Ekadashi/Google/Custom category filters below the calendar header.

- Default to the current year if available; otherwise choose an available year
  and show its year clearly. Populate options from packs and retained history.
- Selecting 2026 browses 2026; it does not reset lifetime streaks or achievements.
- Home automatically shows the next actual upcoming event across years.
- Notifications and widgets use current/upcoming occurrences across years,
  independently of the year being browsed. Browsing history must never schedule
  old reminders or roll the home widget back to the past.
- Tapping a historical event shows its saved occurrence details. A widget/search
  deep link selects the occurrence's year before opening it.
- If a history record remains but its pack is temporarily unavailable, show the
  saved record and an honest unavailable-details state; never delete the record.

Arun is being asked to choose between this flow and one global year selector.
No dependent implementation will begin before the design discussion.

## Preserve tracker history and achievements

PR4 currently uses Map<int,VratHistory> and getRecord(integer). Simply
concatenating both JSON arrays would overwrite/reuse records and count an old
observance against a different year's event. Migrate keys before loading both.

Migration steps: back up the original serialized history and achievement flags;
resolve each old record using its saved date/year and legacy ID; write the new
UID and preserve every note/status/timestamp/location/tradition field; retain
unresolvable records for reconciliation; verify counts and identities; commit
schema version only after success. A crash/retry must be idempotent and must
not replay achievement notifications. Retain the backup until verified.

Current and longest streaks evaluate the full chronological occurrence sequence
using agreed opt-in/tradition rules. December→January does not reset a streak.
Annual statistics use the selected year and its actual denominator. Already
earned achievements and one-time notification markers survive migration,
restart, disabling tracking, and later year selection. Keep the current six
milestones; adding new annual badges would be a separate product decision.

## 2027-specific issues to resolve

1. Calendar bounds, initial focus and Today must come from available years and
   selected location date rather than literal 2027/device-local dates.
2. Newly added calendar/filter/editor/sync/widget copy is largely hardcoded
   English despite Telugu support. Localize every new surface and test all
   supported languages, not just the language picker and existing Home.
3. Google import upserts returned events but does not reconcile remote deletions.
   Define atomic reconciliation for the imported calendar/time window, including
   canceled events, pagination, recurrence and timezones. Keep custom entries.
4. Scope imported IDs/cache/selections by account + calendar ID + event ID;
   define account switching, sign-out, deselection and offline cache behavior.
5. Timed events ending at midnight need exclusive-end handling. Current
   CalendarEntry.occursOn compares inclusive dates and can mark an extra day.
6. Database init errors currently make Calendar controls ready even when writes
   cannot succeed. Show a recoverable error; verify restart and ownership/closing
   of repository instances rather than silently retrying independent stores.
7. Keep one widget architecture. Fold the useful 2027 localization/builder tests
   into the corrected dev widget repository instead of shipping a second cache
   and provider with separate event-selection behavior. Its current widget also
   has English “Start fasting” copy and updates static cached text.
8. Resolve the branch's compile errors and validate a single supported SDK/lock
   graph. Read-only OAuth needs debug and Play App Signing SHA/config checks.

## Implementation order after the current PRs are ready

1. Finish/fix acceptance blockers for tracker and widgets/search. Run all required
   automated suites, emulator scenarios and the small physical-device matrix.
   Present exact candidate commits and results. Await Arun's explicit permission
   before any push/merge into dev. Main remains protected and separately gated.
2. On an isolated branch from the approved dev head, stabilize occurrence UIDs,
   shared repository and archive packs; implement migration and year selectors.
3. Integrate Telugu and move localization to ARB; preserve offline content.
4. Integrate custom calendar CRUD/category filters with the shared year context.
5. Integrate Google import and reconciliation behind isolated auth/repository
   boundaries. Export/two-way sync are outside the existing implementation and
   need a separate scope decision.
6. Consolidate widget/deep-link/search/notification queries over the shared repo.
7. Run migration and full app acceptance matrix; present a reviewable candidate
   and await approval for dev. A release into main needs separate approval.

A merge-tree check against the current dev head found conflicts in Android strings, main.dart, CalendarScreen, LanguageService and pubspec.lock. Avoid one large branch merge: main.dart, CalendarScreen, language resources,
widget wiring and dependency files overlap existing dev changes.

## Native identity and reminder migration

The stable occurrence UID must also reach native scheduling, notification taps,
search and widget caches. Current WorkManager names and notification IDs are
built from the reused integer event ID: simply appending 2027 can replace a
still-pending 2026 reminder with the same ID. Introduce a versioned channel/payload
contract carrying occurrence UID and calendar year, namespace unique work names,
and allocate stable platform integer notification IDs where Android requires
integers. Reconcile legacy pending work during migration, preserving already
delivered/one-time markers. Old deep links must resolve to their original year.
Test 2026/2027 ID 19 together, cancel only the intended occurrence, migrate during
a fasting/Parana window, and verify cached widgets and taps select the right year.
This is part of the future integration proposal, not an implemented change.

## Test plan before implementation is accepted

| Layer | Required cases |
|---|---|
| Domain/data | Load both years, stable unique IDs, dynamic annual totals, wrong/missing pack, schema/revision validation, locale fallback, date ordering, UTC/IANA offsets and DST, Dec→Jan upcoming lookup |
| Tracker regression | Same legacy integer in both years never collides; cross-year current/longest streak; annual isolation; backfill/edit/delete; disabled mutation blocked; year with only retained history; earned achievements remain/no duplicate popup |
| Migration integration | Real v1/preferences and PR4 history fixtures, exact count/field preservation, malformed/unresolved rows, crash/rollback/retry, restart, account independence and no data purge |
| Calendar/UI | Select 2026/2027, month boundary arrows, Today behavior, category filters, add/edit/delete/relaunch, old Details/search/widget links select correct year, screenshots in en/ta/hi/te, small screens/large fonts |
| Google integration | Fake auth + actual SQLite, cancellation/denied scopes/expired session, empty calendars, multiple pages, recurrence, same ID in two calendars/accounts, deleted/moved events, all-day/exclusive midnight ends, offline/retry, custom records preserved |
| Android emulator | APIs 24/33/35, permission denial/revocation, GPS off/fake GPS, offline, process recreation, reminders remain disabled after language/year changes, launcher widget A→B→C and reboot/timezone changes |
| Device/release | Samsung M52/Z Flip 5 real OEM restrictions and long background reliability, GPS/travel, Samsung launcher/fold/cover screen, signed upgrade from Play Store v1; real Google OAuth account smoke with authorized test account |

Capture screenshots, logs, API/locale/timezone details and failures automatically.
Use native-language review for translation correctness; automated tests cover
missing keys, placeholders, plurals, formatting, glyph rendering and layout.
