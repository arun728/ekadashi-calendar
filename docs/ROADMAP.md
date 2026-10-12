# v2 improvement roadmap (iOS and Android)

This file tracks the phased plan agreed with Arun on 8 October 2026. Update the
status table as each phase moves forward.

## Working rules

- **iOS first, then Android.** Each phase is built and tested in `ios-native/`
  first. Once Arun approves it on his iPhone, it is ported to the Flutter app
  for parity. Small features go to both platforms at once only when Arun says
  so. Apart from platform-specific look (Liquid Glass on iOS), features, content
  and behaviour stay identical.
- **One branch and one draft PR per phase.** Branch from the latest `dev`, open
  the PR to `dev` as a draft, and never push or merge to `dev` (or `main`)
  until Arun says so explicitly.
- **Skip CI on request.** When Arun says "skip ci", put `[skip ci]` in the
  commit messages pushed to that PR.
- **Shared fixtures keep parity.** Search queries, translations and festival
  dates live in shared JSON fixtures that both the Dart and the Swift tests
  read.
- **TDD.** Write the failing test first, then implement, then run the full
  suites.
- **Languages** are always ordered English, Hindi, Tamil, Telugu, Gujarati,
  Bengali. New languages are added at the end, never earlier.

## Status

| Phase | Scope | iOS | Android |
| --- | --- | --- | --- |
| 0 | Housekeeping | Done | Done (same commits) |
| 1 | One search for the whole app | Done (PR #17) | Not started |
| 2 | One app language and Sarvam translation | Done; Sarvam run needs an API key | Not started |
| 3 | Panchang redesign, missing festivals, regional names | Done | Not started |
| 4 | Calendar tab, Home, Journey tab, observance fix, scroll tests | Done | Not started |
| 5 | Settings and Premium card | Done | Not started |
| 6 | Widgets (two widgets) | Done | Not started |
| 7 | Notifications revamp | Done | Not started |
| 8 | Android look and feel parity | n/a | Not started |
| 9 | Swipeable sub-sections and back to search | Done | Not started |
| 10 | Gujarati and Bengali | Done | Done (`feature/android-v2`) |

## Phase 0: housekeeping

- Fixes from iPhone testing on `feature/ios-native`:
  - Google sign-in crash (calls now run on the main thread);
  - Premium now unlocks after a purchase (entitlements also read from each
    product's latest transaction);
  - Disconnect-Google icon;
  - generated Info.plist files are ignored.
- Verbose StoreKit debug logging removed; the one-line `Premium refresh:`
  summary stays.
- This roadmap and the new rules in `AGENTS.md`.
- Merged straight to `dev` without a PR, at Arun's request.

## Phase 1: one search for the whole app

**Sources** (one index):
- published Ekadashi days with fasting and Parana times, for every data year;
- Panchang observances for every data year: festivals, Amavasya, Purnima,
  Shivaratri, Pradosham, Sankashti and Sankranti;
- custom calendar entries and imported Google events (on the phone only);
- screens and settings (notifications, premium, widgets, language, ...).

**Removed** from search: katha, mantra, food and vrat-info content, the
content-download button, and the "More" sheet.

**Matching**
- Keep the current scorer (exact, prefix, contains, every word matched,
  Damerau-Levenshtein typos).
- Add an in-order-letters tier (from vault-hub's `Fuzzy.isSubsequence`), ranked
  below typos, for queries of 3 or more letters.
- One alias table maps every spelling, regional name and the Hindi, Tamil and
  Telugu names to one canonical observance. For example, Diwali, Deepawali and
  दीपावली all find Deepavali; Pongal and Uttarayan find Makar Sankranti.
- The query is parsed: a year ("2027") becomes the year filter, and a type word
  ("amavasai") becomes the type filter.

**Filters**: Year first, then All, Ekadashi, Festivals, Amavasya, Purnima,
Shivaratri, Chaturthi, Pradosham, Navaratri, Sankranti, Jayanti, My calendar.

**Premium**: Ekadashi results are free. Festival and other Panchang
observance results show a lock; tapping one opens the paywall (the festival
finder stays Premium).

**Tests**: a shared golden fixture (query, filters, language → expected top
results) run by both the Swift and the Dart test suites.

**iOS implementation** (`feature/unified-search`):
- `assets/search/search_catalog.json`: observance names in four languages,
  aliases, type words and screens (the iOS copy is checked byte for byte);
- `test/fixtures/search/search_golden.json`: 32 golden cases;
- `PanchangEngine.observances(on:city:)` and `observanceCalendar(year:city:)`
  compute observances only, for the index;
- `UnifiedSearch`, `SearchCorpus`, `SearchCatalog` and `SearchQueryParser`
  in EkadashiCore; `GlobalSearchView` in the app.

**Notes for later phases**:
- Lohri and Bhogi (the day before Makar Sankranti), Puthandu, Vishu and
  Baisakhi need their own regional rules (Phase 3) and are not aliases yet.
- Holika Dahan 2026 is calculated on 2 March (Bhadra is not evaluated);
  published calendars give 3 March. Review in Phase 3.
- Hindi, Tamil and Telugu names and the new search strings need native
  review (Phase 2).

## Phase 2: one app language and Sarvam translation

- The Home language picker is the only one; every tab and subtab follows it.
  Remove the other pickers and the "IST · English" chip on Panchang.
- One ordered language registry (English, Hindi, Tamil, Telugu); a test fails
  if the order changes. New languages are appended.
- Translate all English UI text, including Panchang, with **Sarvam AI**
  (Mayura) into Hindi, Tamil and Telugu as a trial. Existing translations are
  set aside and re-translated so the result can be judged. Record the time and
  cost; Arun's native speakers review. Expand to more languages based on the
  result.
- Tests: every key exists in every language, placeholders match, no unintended
  English left, no hard-coded English in Swift or Dart views, and any language
  added later is checked automatically.

## Phase 3: Panchang redesign, missing festivals, regional names

- New first screen, "Key days": a standard month and year picker, and the
  month's important days (Ekadashi, Amavasya, Purnima, Shivaratri, Pradosham
  and festivals) as cards. Premium, with a lock and the paywall for free users.
- Daily screen as clean cards: sunrise and sunset; the five limbs with end
  times; good times and times to avoid as a timeline; the rest behind "More
  details".
- Remove the Guide subtab and the "IST · English" chip.
- Add the missing festivals as reviewed rules, validated against published
  calendars: Raksha Bandhan, Ugadi/Gudi Padwa, Onam, Durga Ashtami, Karthigai
  Deepam, Varalakshmi Vratam, Ratha Yatra and Nag Panchami.
- Festival names follow the app language and region (Tamil: Thai Pongal;
  Hindi: Makar Sankranti); every name stays searchable.

## Phase 4: Calendar tab, Home, Journey tab

- Calendar: Today at the top left, actions in the toolbar or a menu, tap the
  month title for a month/year picker, swipe between months.
- Observance (recording a fast) stays Ekadashi-only, from the Home and Journey
  tabs. The Calendar tab does not get festival markers or filters.
- Home shows only Ekadashi; festivals and Amavasya belong in Panchang.
- Rename the Vrat tab to **Journey**.
- Bug (both platforms): the observance control is enabled for current and
  future Ekadashis. It must be enabled only for past Ekadashis, and for the
  current one once its Parana start time has passed.
- Android: the Calendar screen must scroll from anywhere, not only from the
  bottom card. Add scroll tests for every screen on both platforms.

## Phase 5: Settings and Premium card

- Dark mode: white text throughout Settings; teal only for icons and toggles.
- A prominent Premium card: benefits, store prices, a clear Subscribe button,
  the subscribed state with Manage, and the renewal terms, Restore and legal
  links both stores require.

## Phase 6: widgets

- Two widgets:
  1. **Ekadashi**: on an Ekadashi, "Today is X Ekadashi", progress through the
     fast and the time left until Parana; otherwise "Next Ekadashi: X" and the
     days to go.
  2. **Upcoming Ekadashis**: a list.
- iOS: redesign to Apple's widget guidelines (glanceable, container
  background, tinted and clear home screen styles), plus the in-app preview.
- Android: two widgets with the same behaviour; the retired widget's provider
  keeps working with the new layout so placed widgets do not break.

## Phase 7: notifications revamp

- The master Notifications toggle gets sub-sections. Today's Ekadashi
  reminders move under **Ekadashi**.
- Users pick other events from a list (festivals, Amavasya, Purnima and other
  Panchang observances, custom entries and Google events), including the
  festivals added in Phase 3.
- For each, the user chooses when to be reminded (for example 1 or 2 days
  before, at a chosen time) so devotees can plan.

### Phase 7 implementation notes (iOS)

- Settings > Notifications: the master switch, then **Ekadashi** (the four
  existing switches, unchanged keys) and **Festivals and events**: the user's
  reminders, each opening an editor, and "Add a reminder".
- The editor picks an event from a searchable list in the app language:
  festivals (alphabetical), monthly observances (Purnima, Amavasya,
  Pradosham, Chaturthis, Masik Shivaratri, the Sankrantis) and My calendar
  (all custom entries, all Google events). Lead times are on the day, 1, 2,
  3 or 7 days before (several at once; 1 and 2 days by default) at a chosen
  time, 7:00 AM by default.
- Festival and Panchang reminders are Premium, like Key days; reminders for
  the user's own and Google entries are free. A locked reminder is kept and
  starts working with Premium.
- Festival dates are calculated at the saved Panchang location and the
  reminder fires on that location's clock; entries fire on the phone's
  clock. Tapping a festival reminder opens that day in Panchang
  (`ekadashi://panchang?date=YYYY-MM-DD`); an entry reminder opens the
  Calendar on that day.
- Stored as JSON under `event_reminders` (the master switch stays
  `notifications_enabled`). Ekadashi and event reminders share iOS's 64
  pending notifications, soonest first; the app plans again on launch,
  background refresh, and when reminders, entries, the Panchang location or
  Premium change.
- Core: `EventReminderSettings`, `EventReminderPlanner`,
  `EventReminderChoice` and `PendingNotification` in `EkadashiCore`
  (`EventReminderTests`, `PendingNotificationTests`).

## Phase 8: Android look and feel parity

- The iOS green-to-black gradient on every Android tab.
- Matching colours, type and spacing, checked with side-by-side screenshots.

## Phase 9: swipeable sub-sections and back to search

- Panchang, Journey and Search sub-sections change with a horizontal swipe
  as well as their chips (iOS: a page-style `TabView`; Android: a
  `PageView`), and the chip bar scrolls to keep the selected chip in view.
  Calendar keeps its swipe between months.
- Journey's sections are glass chips like Panchang's (no segmented control).
- A search result that opens a tab or a calendar day leaves the search, so
  that screen's top bar shows "‹ Search" (`search_return`), which reopens
  the search with the same text, type page and year. Choosing another tab,
  a deep link or a new search forgets it. Results that push a screen
  (Ekadashi, festival, widget preview) keep the system back button.
- Core: `SearchReturn` and `SearchSession` (`SearchReturnTests`).

## Phase 10: Gujarati and Bengali

- Gujarati (ગુજરાતી) and Bengali (বাংলা) are appended after Telugu in both
  apps' language menus, with every UI string, the iOS-only strings, the
  Panchang vocabulary, festival names and search words, the Ekadashi names,
  descriptions, stories, fasting rules and benefits for 2026 and 2027, and
  the Android widget strings.
- Arun chose Claude over Sarvam: the translations were written by Claude, at
  no cost, and await native-speaker review (lib/l10n/translation_review.json).
- Search keeps Gujarati and Bengali letters when matching.
- Tests: every key, native script and placeholder in both languages; every
  Ekadashi field; every Panchang term and observance; layouts in both.

## Testing and CI

- iOS: XCTest unit and UI tests on CI, with screenshots of every tab in each
  language, light and dark, on a small and a large iPhone, uploaded as
  artifacts for review.
- Android: Flutter tests, golden screenshots and emulator integration tests.
- The repository is public, so GitHub-hosted runners (including macOS) do not
  use paid minutes.
