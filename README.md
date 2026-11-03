# Ekadashi Calendar

Ekadashi Calendar helps devotees plan fasting, follow Parana (fast-breaking)
times, record their observance journey, and explore a location-aware Panchang.
The repository contains a Flutter Android app and a native Swift/SwiftUI iOS
app, with shared data and cross-platform calculation fixtures.

[Android on Google Play](https://play.google.com/store/apps/details?id=com.applausestudios.ekadashi_calendar)
· [Privacy policy](docs/privacy-policy.md)
· [Terms of service](docs/terms-of-service.md)

## Project status

This overview reflects `dev` and roadmap/review status as of **3 November 2026**.
Android v1 is available on Google Play; the repository is developing v2 for
Android and native iOS. The iOS App Store link is still a placeholder, and v2
release validation is ongoing. Features on review branches below are not yet
part of `dev` or a published release.

## App experience on dev

The five tabs are **Home, Calendar, Journey, Panchang, and Settings**, with
unified Search available from the toolbar.

- **Home:** Ekadashi dates, fasting and Parana times for the selected city,
  Smarta or Vaishnava tradition, and enabled year. The offline Panchang engine
  supplies the schedule used by Home, Calendar, reminders, widgets and search;
  bundled content supplies names, stories, benefits and fasting guidance.
  Currently enabled years are 2026 and 2027. A shared lifecycle handles the
  countdown, fasting progress, Parana window and automatic next occurrence.
- **Calendar:** month browsing, Ekadashi dates, custom entries and read-only
  Google Calendar imports. Successful imports reconcile deletions; failed or
  partial imports preserve the existing cache. Import does not write events
  back to Google or provide background two-way sync.
- **Journey:** Ekadashi observance recording, history, statistics, streaks and
  achievements. New observations become recordable at Parana start; existing
  records remain editable. Stable occurrence identities preserve history
  across years, city changes and upgrades.
- **Panchang:** worldwide city selection and date browsing, Key days, daily
  limbs and timings, Muhurta, calculated Ekadashis and Rashi. Calculations use
  the chosen location and timezone. Regional/traditional conventions and
  validation limits are documented; universal agreement with every published
  calendar is not claimed.
- **Search:** Ekadashis, Panchang observances, custom/imported calendar entries,
  and app screens, with year/type filters, regional aliases and typo matching.
- **Reminders and widgets:** Ekadashi and configurable event reminders, plus
  Ekadashi and Upcoming Ekadashis widgets. iOS includes Home and Lock Screen
  families; Android placement and refresh depend on the widget host. Widget
  taps open the corresponding occurrence, and Settings includes previews.
- **Language and appearance:** English, Hindi, Tamil, Telugu, Gujarati and
  Bengali, in that order. Screens, dates, places, widgets and notifications
  follow the app language. Native-speaker wording review remains required.
  iOS uses Liquid Glass on iOS 26 with material fallbacks on older versions;
  both apps include the optional Glass Look setting, off by default.

See [engine schedules](docs/EKADASHI_ENGINE_SCHEDULE.md),
[lifecycle behavior](docs/IOS_EKADASHI_LIFECYCLE.md),
[Android lifecycle](docs/ANDROID_EKADASHI_LIFECYCLE.md),
[iOS widgets](docs/IOS_WIDGET_REDESIGN.md), and
[Android widget parity](docs/ANDROID_WIDGET_PARITY.md) for details.

## Free and Premium

| Area | Free | Premium |
| --- | --- | --- |
| Core Ekadashi experience | Home, calendar, Ekadashi search, share cards, reminders, widgets and custom entries | Included |
| Journey | First three new recorded entries and three achievement unlocks; editing, history, statistics, streaks and earned badges remain accessible | Further recording and achievement unlocks |
| Panchang | Daily preview and free Ekadashi information | Full details, timings, Muhurta, Rashi, festival/observance browsing and related search/reminders |
| Google Calendar import | One successful import of the viewed month per Google account, tracked by the free-sync registry | Subscriptions import the 12-month subscription year; lifetime covers every supported calendar year |

Monthly, annual and lifetime plans use verified store ownership: Google Play
Billing on Android and StoreKit 2 on iOS. Prices are loaded from the store;
Premium needs no Google sign-in. Google sign-in is for Calendar import.
Confirmed subscription expiry removes Premium-imported Google events while
retaining the free month's events and personal observance history. Store or
network errors are not treated as confirmed expiry.

Core calculations and personal records work offline. Purchases, Google import
and the Firebase free-sync registry require their respective services. The
`backend/` billing/rewards service is dormant and is not used for v2 Premium.
See [Android Premium setup](docs/PREMIUM_SETUP.md) and
[iOS configuration and StoreKit rules](ios-native/README.md#configuration).

## Roadmap

The [v2 improvement roadmap](docs/ROADMAP.md) records the original phases:
unified search, one app language, Panchang redesign, Calendar/Home/Journey,
Settings/Premium, widgets, notifications, Android appearance parity, swipeable
sections, Gujarati/Bengali, and engine-based Ekadashi schedules. Much of that
baseline is now on `dev`, including the later widget, lifecycle, Glass controls
and performance follow-ups from PR #24. Some original status rows and branch
references are historical; use the current review status below alongside the
linked plans and validation reports.

The [offline Premium roadmap](docs/PREMIUM_ROADMAP.md) defines the next four
phases. All paid plans receive the same features, with local personal data and
no monetary rewards.

| Phase | Scope | Current status |
| --- | --- | --- |
| 1 — Journey collection | Annual/lifetime points, quarter/year bonuses, annual mandalas, milestone/streak/annual badges, grouped celebrations and optional annual sharing | iOS and Android candidate rebuilt on current `dev` in [PR #32](https://github.com/arun728/ekadashi-calendar/pull/32); awaiting review and integration approval |
| 2 — Personal birth profile | Local birth date/time/place; Lahiri Janma Rashi, Nakshatra, Pada and birth tithi; explicit handling of unknown time and historical timezone ambiguity | iOS draft in [PR #26](https://github.com/arun728/ekadashi-calendar/pull/26); verified-purchase save/edit/delete validation remains incomplete, and Android is pending |
| 3 — Family profiles and traditional birthdays | Multiple local profiles, reviewed Nakshatra/tithi birthday rules and optional per-profile reminders | Planned after the birth-profile phase is validated and approved |
| 4 — My Panchang | Personal daily view combining profile, location Panchang, birthdays and Journey; reviewed personal timing rules and optional daily reminders | Planned after Phase 3 approval; traditional interpretations need explicit review |

Journey points are personal progress indicators. They have no cash value,
redemption, discounts or public ranking. The roadmap preserves the three-free
entry/badge limits, earned awards and personal history. Cloud history/sync,
financial rewards, full Kundali/dashas and daily prediction content are deferred.

**Calculation work under review:**
[PR #33](https://github.com/arun728/ekadashi-calendar/pull/33) proposes improved
Panchang minute matching, GCal-based Vaishnava rules, Purnima fast-day selection,
additional festivals and faster calculations. It remains a draft, with native
app/device validation outstanding. These changes are not the current `dev`
calculation policy. See [Panchang accuracy](docs/PANCHANG_ACCURACY.md) for the
baseline evidence and methodology.

**Release work:** production purchase/restore/expiry flows, configured Google
OAuth/import, physical-device notifications and background/widget reliability,
older supported iOS versions, Android OEM behavior, Play-signed v1 upgrades,
accessibility and native-speaker wording still need release checks. Local
suite results in the docs describe specific candidates, not a release guarantee.

## Repository layout

| Path | Purpose |
| --- | --- |
| `lib/`, `android/` | Flutter Android app and native Kotlin integrations |
| `ios-native/` | Native SwiftUI app, WidgetKit extension, shared widget views and EkadashiCore Swift package |
| `assets/calendar/` | Enabled-year manifest and localized Ekadashi content |
| `assets/panchang/`, `assets/search/`, `lib/l10n/` | Cities, Panchang vocabulary, search catalog and localization resources |
| `test/`, `integration_test/`, `ios-native/*Tests/` | Domain, parity, UI and integration tests |
| `tool/` | Resource generation, validation and emulator tooling |
| `firebase/` | Free Calendar-import registry rules |
| `docs/` | Product plans, calculation conventions, setup and validation reports |
| `backend/` | Dormant billing/rewards prototype |

The legacy Flutter `ios/` directory remains in the tree; native iOS development
happens in `ios-native/`.

## Local development

### Android

Use Flutter **3.38.5** (the version pinned in CI), its Dart SDK, and an Android
SDK/emulator or device. The Dart constraint is `^3.10.4` in `pubspec.yaml`.
From the repository root:

```sh
flutter pub get
python3 tool/generate_localized_lookup.py
flutter gen-l10n
flutter run -d <android-device-id>
```

Google sign-in/import and real billing require the configured client IDs,
Firebase project and correctly signed package. Follow
[Premium and Google setup](docs/PREMIUM_SETUP.md) for build defines and testing;
keep private signing material and credentials out of Git.

### Native iOS

Use macOS, Xcode 26 with the iOS 26 SDK, and XcodeGen. The deployment target is
iOS 17+, with older-version behavior still subject to release validation.
From the repository root:

```sh
cd ios-native
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
# Fill in local configuration before building.
xcodegen generate
open EkadashiCalendar.xcodeproj
```

The generated project is not checked in. Configure signing, the shared App
Group, Google OAuth, Firebase and the App Store ID as described in the
[native iOS README](ios-native/README.md). The scheme includes a local StoreKit
catalog for simulator testing; it does not configure production products.

## Validation and contribution

For app changes, follow the test-first and platform-parity rules in
[AGENTS.md](AGENTS.md). Implement and review iOS first, then port to Android
unless both platforms are explicitly requested together. Preserve shared
fixtures, translations, occurrence identities and stored history.

Core local checks, from the repository root:

```sh
flutter analyze
flutter test
(cd ios-native/EkadashiCore && swift test -c release)
```

[Testing](docs/TESTING.md) covers generated-file checks, formatting, native
Android tests, emulator flows and iOS app/widget/UI tests. Use a dedicated test
emulator for scripts that reset app or launcher data. The
[26 October validation report](docs/PR24_FOLLOWUP_VALIDATION_2026-10-26.md)
records more recent `dev` follow-up evidence than the original testing totals.

Work on a branch from the latest `dev` and open a draft PR against `dev`.
Do not push directly or merge to `dev` or `main` without explicit approval.
The standing instruction is to use `[skip ci]` on pushed commits and not trigger
CI until requested. Markdown-only changes are also excluded by the app workflow.
