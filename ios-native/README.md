# Ekadashi Calendar for iOS (native)

A native Swift/SwiftUI version of the Android app with the same features:

- tabs: Today, Calendar, Vrat, Panchang and Settings, with Search in the top bar;
- two home-screen widgets (Ekadashi and Upcoming Ekadashis) and reminder notifications for Ekadashi, festivals, Panchang days and calendar entries;
- Google Calendar import with the free-sync registry, and App Store premium;
- English, Tamil, Hindi and Telugu, plus the offline Panchang engine with both Ekadashi traditions.

On iOS 26 the app uses Apple's Liquid Glass (`glassEffect`, glass button styles and the system's glass tab bar and toolbars). On iOS 17–25 it falls back to system materials.

> Status: the shared `EkadashiCore` package is built and tested on Linux (150 tests, 0 failures). The app, the widgets and their Xcode tests were written in a Linux container without Xcode or macOS. They have **not** been compiled, run on a simulator or device, or tested against StoreKit or Google. See [Verification](#verification).

## Layout

| Path | What |
| --- | --- |
| `EkadashiCore/` | Swift package with all domain logic and data, shared by the app and the widgets. It ports the Flutter services: published schedule, localization, Vrat tracker, premium rules, Google import and free-sync registry, search, reminders, widget snapshot, deep links, the Panchang engine and calculated Ekadashi. It bundles the same calendar packs, city list, ARB strings and IANA 2026b timezone data as Android. |
| `EkadashiCalendar/` | SwiftUI app. `App/` holds the launch flow and state, `Features/` one folder per screen, `Services/` StoreKit, notifications, location, Google Sign-In and widgets, and `DesignSystem/` the glass styles. |
| `EkadashiWidgets/` | WidgetKit extension with small "Next Ekadashi", medium "Ekadashi Today" and large "Upcoming Ekadashis" widgets. |
| `Shared/` | Widget views compiled into both the app (widget preview screen) and the extension. |
| `EkadashiCalendarTests/`, `EkadashiCalendarUITests/` | App unit tests, and UI tests that walk every tab, search and the paywall and attach screenshots. |
| `project.yml` | XcodeGen spec. The `.xcodeproj` is generated, not committed. |
| `Config/` | Public build settings. Copy `Secrets.example.xcconfig` to `Secrets.xcconfig` (git-ignored). |

## Build

Requirements: Xcode 26 (iOS 26 SDK) and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
cd ios-native
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # fill in, see below
xcodegen generate
open EkadashiCalendar.xcodeproj
```

The scheme runs with `EkadashiCalendar/Resources/Products.storekit`, so the paywall shows local test products (₹99, ₹499 and ₹999) in the simulator without App Store Connect.

Tests:

```sh
# Domain logic (macOS or Linux, Swift 5.10+)
cd ios-native/EkadashiCore && swift test -c release
# App, widgets and UI screenshots
xcodebuild test -project EkadashiCalendar.xcodeproj -scheme EkadashiCalendar \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

The core tests read the repository's `assets/`, `lib/l10n/` and `test/fixtures/` files. They fail if the iOS copies drift from Android (including `assets/search/search_catalog.json`). The search tests run the shared golden cases in `test/fixtures/search/search_golden.json`, which the Flutter port of the search will run too. In the Flutter suite, `test/tool/dump_panchang_parity_test.dart` fails if the Panchang parity fixture no longer matches the Dart code.

To regenerate the copies:
- data and Swift series files: `python3 tool/ios/generate_core_resources.py`;
- search catalog: copy `assets/search/search_catalog.json` to `EkadashiCore/Sources/EkadashiCore/Resources/search/`;
- parity fixture: run `test/tool/dump_panchang_parity_test.dart` with `UPDATE_IOS_FIXTURES=1`.

CI runs the iOS job in `.github/workflows/android-tests.yml` on macOS with Xcode 26. It runs the package tests, then builds the app and widgets and runs the unit and UI tests on the newest iPhone simulator. The UI screenshots are uploaded as an artifact.

## Configuration

All values are public client identifiers (the same kind Android gets through `--dart-define`). They go in `Config/Secrets.xcconfig`:

- `DEVELOPMENT_TEAM`, and `APP_GROUP` if not `group.com.applausestudios.ekadashi-calendar`. Turn on the App Group for both the app ID and the widget extension ID.
- Google Sign-In: create an **iOS OAuth client** in the Google Cloud project that hosts the Firebase free-sync registry, for bundle ID `com.applausestudios.ekadashi-calendar`.
  - Set `GOOGLE_IOS_CLIENT_ID` and `GOOGLE_REVERSED_CLIENT_ID`.
  - In Firebase Authentication, add the iOS client ID to the Google provider's allowed client IDs, so Firebase accepts its ID tokens.
  - The app asks only for `calendar.readonly`. The paywall never needs Google sign-in.
- `FIREBASE_API_KEY` and `FIREBASE_PROJECT_ID`: the same Web API key and project as Android, so one Google account's free sync is recorded once across both platforms. Without them, the free sync cannot be verified, and the app offers Premium instead of handing it out.
- `APP_STORE_ID`, once the app has a listing. It is used by "Rate app" and the share message.

App Store Connect products:

| Product ID | Type | Base price |
| --- | --- | --- |
| `ekadashi_premium_monthly` | Auto-renewable subscription, group `ekadashi_premium` | ₹99 / month |
| `ekadashi_premium_yearly` | Auto-renewable subscription, same group | ₹499 / year |
| `ekadashi_premium_lifetime` | Non-consumable | ₹999 |

- Prices come from StoreKit and are never hard-coded.
- Configure no introductory offers: the paywall shows full prices only, like Android.
- Android uses one subscription (`ekadashi_premium`) with `monthly` and `yearly` base plans. The App Store needs a separate product per plan, so iOS uses separate IDs inside one subscription group.

## Premium rules (App Store)

These follow the Play-only rules in `AGENTS.md`, adapted to StoreKit 2 with no backend.

**Where premium comes from**
- Premium comes only from cryptographically verified `Transaction.currentEntitlements`.
- It is never granted from a stored flag, an unverified transaction or a pending (Ask to Buy) purchase.
- Completed transactions are finished (Apple's acknowledgement).

**When premium is re-checked**
- At launch and on returning to the foreground.
- Every five minutes while the app is open.
- After every purchase, and at each Google import.

**When premium ends**
- A subscription counts as ended only when StoreKit's subscription status confirms it. An offline or App Store error is never treated as a lapse.
- Only after a confirmed end are the Google events that Premium imported removed. The free month's events stay.

**What is free and what is premium** (same as Android)
- Google import: free users get one sync, of the viewed month. Monthly and yearly subscribers import the 12-month subscription year; lifetime owners import every year the app has data for.
- Vrat: the first three recorded entries are free, and existing entries stay editable. All history, streaks, statistics and earned badges are kept. Three badges unlock free; the rest need Premium.
- Panchang:
  - free: the daily preview, today's vrat and festival names, the calculated Ekadashi list and the guide;
  - Premium: the full limbs, Muhurta, Rashi and the festival finder.

**Other paywall details**
- Restore uses `AppStore.sync()`. "Manage" opens Apple's subscription sheet.
- Buying lifetime while subscribed first warns that the subscription must be cancelled in Apple's settings.

## Android → iOS parity

| Android | iOS | Verified by |
| --- | --- | --- |
| Published 2026/2027 schedule; IST/EST/CST/MST/PST chosen by location, else the device timezone | `CalendarRepository`, `AppTimezone`, `LocationService` | Core tests (data byte-identical to `assets/`) |
| Home cards: countdown, fasting and Parana times, details, Vrat button; re-tapping Today jumps to the next Ekadashi | `TodayView`, `EkadashiDetailsView` | Not run |
| Calendar: every data year, month grid, Ekadashi/Google/custom filters, custom entries, Google import and disconnect | `CalendarView`, `EntryEditorView`, `GoogleCalendarPickerView`, `GoogleSyncCoordinator` | Core tests for the sync, free-registry and deletion-reconciliation rules; UI not run |
| Vrat tracker: overview, history, statistics, achievements, record sheet, unlock dialog | `VratView`, `RecordVratSheet`, `VratTracker` | Core tests (Android JSON schema, streaks, 3 free entries/badges); UI not run |
| Panchang, worldwide and English-only: Daily, Muhurta, Ekadashi (Smarta and Gaudiya), Rashi, Festivals and Guide; city search, GPS or manual coordinates and IANA timezone | `PanchangView` and panels, `PanchangEngine`, `CalculatedEkadashiEngine` | Core tests: field-by-field parity with the Flutter engine (112 days in 8 cities, 240 fasts) plus the published Drik, ISKCON Bangalore and GCAL gates; UI not run |
| One search for the whole app (iOS first, Phase 1 of `docs/ROADMAP.md`; Android port pending): Ekadashis, Panchang festivals and observances (Premium), custom and Google entries, and screens; year filter first, then type chips; aliases and names in all four languages; suggestions and recents (explicit submissions only) | `GlobalSearchView`, `UnifiedSearch`, `SearchCorpus`, `SearchCatalog` | Core tests and the shared golden cases; UI test searches an Ekadashi, a festival and a type word |
| Reminders: 2 days and 1 day before, fasting start, Parana; test notification | `ReminderPlanner`, `NotificationService` (respects iOS's 64-pending limit) | Core tests for the plan; delivery not run |
| Festival, Panchang and calendar reminders, chosen days before at a chosen time (iOS first, docs/ROADMAP.md Phase 7) | `EventReminderPlanner`, `PendingNotification.merge`, `EventRemindersView` | Core tests; UI test adds one; delivery not run |
| Three widgets (next, today, upcoming) with deep links | `EkadashiWidgets`, `WidgetSnapshot` in the App Group | Core tests for snapshot and state; widgets not run |
| `ekadashi://` links (dashboard, today, parana, calendar?date=, vrat, panchang, panchang?date=, more, settings, search) | `AppRoute`, `onOpenURL` and notification taps | Core tests |
| en/ta/hi/te | `Localizer` reads the Android ARB strings, plus an iOS override table for 17 strings that name Google Play or Android settings | Core tests: every key used by the app exists in all four languages |
| Background refresh (WorkManager) | `BGAppRefreshTask` keeps reminders, widgets and premium current | Not run |

## Platform differences

**Permissions and background work**
- iOS asks for location and notification permission only once. After a denial, the app opens its Settings page instead.
- There is no exact-alarm permission. Notifications are calendar triggers, and the next 64 are scheduled.
- Background App Refresh is best-effort and controlled by iOS. Widgets therefore carry a timeline with every fasting and Parana boundary, and states change on time even if the app has not run.

**Purchases and accounts**
- StoreKit and App Store accounts replace Google Play Billing, so there is no in-app account sign-in for premium.

**Interface**
- Achievement and status icons use SF Symbols in place of Material icons.
- The app icon is the same image as the Flutter iOS `AppIcon`; a new icon design was not attempted.

## Verification

Done:
- `swift test -c release` in `EkadashiCore` on Linux (Swift 6.3.3): **150 tests, 0 failures**. This includes:
  - parity with the Flutter Panchang engine and calculated fasts;
  - published-date accuracy gates;
  - a check that the bundled data matches Android exactly;
  - a test that fails when the app uses a translation key missing in any language.

Not done (no Xcode or macOS here), and needed before a release:
1. Run `xcodegen generate` and build with Xcode 26, fixing any compile errors.
2. Run the app unit tests and the screenshot UI tests on iOS 26 and iOS 17 simulators.
3. Test StoreKit purchase, restore, Ask to Buy, cancellation and expiry with the local configuration, then in the sandbox.
4. Test Google sign-in, calendar import and the free-sync registry with the production OAuth client.
5. On a device, check notifications, widgets, Background App Refresh and location.
