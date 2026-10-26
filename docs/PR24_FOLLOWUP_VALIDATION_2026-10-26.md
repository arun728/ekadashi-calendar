# PR #24 follow-up validation — 26 October 2026

Branch: `feature/ios-widget-redesign`. Scope compared with `3116369` (the preceding toolbar/Android-port commit). This report covers the approved Glass controls, city grouping, Premium, sheet dismissal, sharing and Home action follow-ups. Existing lifecycle/widget work remains on the same PR. No merge or CI run is authorized or performed.

## Per-change results before push

| Change | iOS validation | Android validation |
| --- | --- | --- |
| Search size, position and enclosure | Same 44 pt target and frame across all five tabs and Glass modes; native screenshot/pixel checks | Shared 44 dp toolbar component; widget tests and emulator navigation |
| Calendar Search/Add/Google grouping | Group and bounds preserved, surface follows Glass; Today remains readable; Google cancellation returns safely | Glass no longer forcibly disabled on Calendar; same group; emulator screenshots and widget checks |
| Calendar/Panchang Today Glass surface | Native geometry/surface checks, date-picker Today/Done navigation | Widget appearance/navigation checks and emulator capture |
| City organization on both tabs | Current/search/recent/popular groups, both modes; real Mumbai search/recent reopen; native render tests | 24-case matrix: six languages, two themes, normal/2× text; Home/Panchang and both modes in each case; location-error feedback |
| App-owned sheet dismissal and close roles | Premium X, Search down, Share/city Cancel; pull-down baseline passed; pushed pages retain Back | Emulator opens/dismisses Premium, city, Share and Search from four tabs; unit tests cover short/cancelled pulls, locks, nested scrollers, wheels and page gestures |
| Editor Cancel/Save/Done controls | Entry Save/Cancel, record Cancel/Save/Delete, reminder Save/Cancel, Calendar month Cancel/Done, Panchang date Today/Done, Google-picker render | Shared SheetBar target/enclosure tests and existing editor/picker/navigation regression suites |
| Save left / Share right | Native UI assertions in both modes; existing image renderer/save path retained | Widget assertions and actual emulator sheet screenshots; Cancel and pull-down tested |
| Settings Glass Look icon | Shared SF Symbol and native UI screenshot | Matching Cupertino role, fixture parity and emulator screenshot |
| Monthly → Yearly → Lifetime suggestion | Actual foreground StoreKit test purchases; wait for verified current-plan ownership before checking suggestion | Billing ownership-stream widget/integration tests, pending/cancelled ownership cases; no mock preference grants |
| Owned Lifetime remains selected/enabled | Actual StoreKit Lifetime purchase; selected enabled tile; no duplicate-buy action | Ownership tests verify selected enabled Lifetime and no duplicate-buy action |
| Customer-facing product name | All three StoreKit-resolved product names and subscription group name; OCR of Apple's actual Edit Subscription sheet | Live Play subscription already named Ekadashi Premium for both base plans; Lifetime title corrected and saved in Play Console |
| Home action shapes and pressed separation | Independent 48 pt circles, outlined bounds, ≥8 pt gaps; before/after tap and Share return | Same 48 dp circles and visible outline; golden diffs confined to Share outline, widget and real-emulator pressed bounds |
| Blocked-record feedback avoids action row | Actual six-language UI taps; dynamic row-height anchor and opacity transition; no action movement | 24-case language/theme/size matrix, both modes; real-emulator banner clearance; past-fast Cancel/Save/achievement flow also tested |

The Android emulator uses the isolated `glasspreview` package. No user's installed app or data was cleared. After the Simulator-only instruction, no further phone installation occurred.

## Required gates

- `flutter analyze`: **no issues**.
- Complete `flutter test --coverage --reporter expanded`: **860 passed**, no failures. This includes domain, regression, localization, widget/golden, storage/Google reconciliation and UI tests.
- Complete `swift test -c release --enable-code-coverage` in EkadashiCore: **286 passed**, no failures.
- Native hosted app/render suite on iOS 18.6: **40 passed**, no skips or failures. All three StoreKit product names resolve through StoreKit itself.
- Native hosted app/render suite on iOS 26.5: **39 executed, 38 passed, one explicit StoreKit-catalog skip**, no failures; the subsequently added row/default-toast render test also passed on 26.5. The CLI runner on 26.5 returned an empty local catalog; this check was run successfully on 18.6 rather than counted as passing on 26.5.
- **20 distinct native UI scenarios passed**, combining the broad appearance/navigation run and targeted editor, Home feedback and StoreKit runs. Six-language dark/light coverage is one scenario containing a matrix, not 12 separate tests.
- Final Android emulator integration: **passed**, both Glass modes, with actual screen captures and post-tap feedback clearance. The runner logs `+2` because it includes teardown; it is one integration flow, not two independent scenarios.
- Android native JVM regression suite: **89 passed**, no failures.
- Generated resource check: **up to date**. Dart formatting: **31 changed/new files, zero formatting changes**. `git diff --check`: clean.
- Parsed old/new StoreKit catalogs differ only in requested display-name/group-localization fields: product identifiers, prices, periods and other fields are unchanged. Signing, App Groups, bundle identities and native Android widget source are unchanged by this follow-up.

## Coverage: exact scope and limits

- Added/edited executable Dart lines versus `3116369`: **198/198 (100%)**.
- Changed native Swift instrumented lines, combining relevant app/UI runs and package coverage: **141/142 (99.30%) raw**. The remaining line is `TodayView.swift:226`, the compiler-generated coverage entry for `@State private var actionsHeight: CGFloat = 54`. The card and geometry update execute in the native UI tests; Xcode also reports zero for the adjacent existing State initializers. No exclusion was applied to make the raw figure read 100%.
- `PremiumState.swift`, the changed domain rule: **88/88 lines, 30/30 functions, 56/56 regions (100%)** in SwiftPM's LLVM report.
- Entire instrumented Dart suite: **14,225/15,363 lines (92.59%)**, including generated localization files. This is not 100% whole-app/repository coverage and does not cover uninstrumented Kotlin, Swift or external OS/store controllers. Full-repository 100% coverage has not been achieved or claimed.
- Coverage records line execution; it cannot guarantee that no bug remains. UI assertions additionally verify geometry, navigation, ownership and visual output.

Changed-line methodology: intersect added line ranges in `git diff 3116369 --unified=0` with LCOV `DA` and Xcode executable-line entries. Use maximum hits across relevant runs. For Today/Toast use only results built after the final feedback change; for Glass use only results after removal of the unused toolbar helper, so older line numbers cannot create false hits. SwiftPM domain coverage comes from LLVM segments. Declarations/constants absent from compiler executable-line maps are outside this denominator.

| Changed production file | Covered / instrumented changed lines |
| --- | --- |
| `lib/main.dart` | 32/32 |
| `lib/screens/global_search_screen.dart` | 1/1 |
| `lib/screens/panchang_screen.dart` | 2/2 |
| `lib/screens/premium_screen.dart` | 18/18 |
| `lib/screens/share_card_screen.dart` | 12/12 |
| `lib/screens/widgets/city_picker_sheet.dart` | 49/49 |
| `lib/widgets/ios_style.dart` | 84/84 |
| `ios-native/EkadashiCalendar/App/RootView.swift` | 4/4 |
| `ios-native/EkadashiCalendar/DesignSystem/Glass.swift` | 29/29 |
| `ios-native/EkadashiCalendar/DesignSystem/Toast.swift` | 7/7 |
| `ios-native/EkadashiCalendar/Features/Calendar/CalendarView.swift` | 6/6 |
| `ios-native/EkadashiCalendar/Features/Calendar/EntryEditorView.swift` | 2/2 |
| `ios-native/EkadashiCalendar/Features/Calendar/GoogleCalendarPickerView.swift` | 1/1 |
| `ios-native/EkadashiCalendar/Features/Panchang/PanchangView.swift` | 5/5 |
| `ios-native/EkadashiCalendar/Features/Premium/PremiumView.swift` | 9/9 |
| `ios-native/EkadashiCalendar/Features/Search/GlobalSearchView.swift` | 1/1 |
| `ios-native/EkadashiCalendar/Features/Settings/EventRemindersView.swift` | 2/2 |
| `ios-native/EkadashiCalendar/Features/Settings/SettingsView.swift` | 8/8 |
| `ios-native/EkadashiCalendar/Features/Share/ShareCardSheet.swift` | 8/8 |
| `ios-native/EkadashiCalendar/Features/Today/EkadashiDetailsView.swift` | 1/1 |
| `ios-native/EkadashiCalendar/Features/Today/EkadashiLocationSheet.swift` | 8/8 |
| `ios-native/EkadashiCalendar/Features/Today/TodayView.swift` | 44/45 |
| `ios-native/EkadashiCalendar/Features/Vrat/RecordVratSheet.swift` | 2/2 |
| `ios-native/EkadashiCore/Sources/EkadashiCore/Premium/PremiumState.swift` | 4/4 |

## TDD and failure investigation

Separate red commits: `b442058`, `f298109`, `7b5cc10`, `29483e3`, `dba12f8`, `f71987b` (all `[skip ci]`). They reproduce missing enclosures/grouping, wrong upgrade selection, sheet pull failures, wrong Share order/icon, 48×42 Home icons, missing Android Share outline and feedback/action overlap. Implementation followed those failing runs.

The final sweep also corrected test defects rather than weakening assertions: narrow Panchang tests now ensure chips are visible and assert actual selection; Google consent cancellation targets SafariViewService; the record test reselects the saved historical card after reload; StoreKit waits for **ownership**, because Lifetime is already the selected suggestion after Yearly. Manage is scrolled into the visible Settings area before tapping. Earlier failures remain in the local logs; the corrected cases have later passing runs. No failed run is counted as a green bundle.

The full Android JVM sweep caught an existing time-dependent test fixture: it assumed a fast starting today at 06:00 UTC had already started. At this run's pre-06:00 UTC time the first item correctly remained upcoming, so its expected ID was wrong. The fixture now starts the first fast yesterday, preserving the five-future-item assertion at any run hour. The failing run was 88/89; the corrected full suite passed 89/89. No production widget behavior was changed.

## Evidence and reproducibility

Local artifacts (ignored test output, not app assets): `outputs/controls-followup/SCREENSHOTS.md`, `changed-line-coverage.json`, the measurement script, `ios/`, `android/` and `stores/`. The gallery contains actual screenshots, including the latest Home feedback placement.

Final log names, alongside the repository checkout:

- `../controls-reviewed-final-analyze.log`, `../controls-reviewed-final-flutter.log`
- `../glass-home-final-swift-coverage.log`
- `../controls-verified-android-build.log`, `../controls-verified-android-drive.log`
- `../controls-reviewed-native-jvm-final.log`, `../controls-generated-final.log`

Native results in `/private/tmp/`:

- `ekadashi-controls-verified-final.xcresult`: iOS 26.5 app/render suite and final three Home/record/localization UI scenarios.
- `ekadashi-controls-hosted-18-final.xcresult`: all 40 hosted tests, including product catalog and added row/default-toast render.
- `ekadashi-controls-surface-26-final.xcresult`: added render test on 26.5.
- `ekadashi-controls-storekit-confirmed.xcresult`: two actual StoreKit UI scenarios.
- Earlier broad/targeted passing methods: `ekadashi-controls-comprehensive-final`, `ekadashi-editor-integration-final`, `ekadashi-editor-rerun-final`, `ekadashi-record-month-final`. Those bundles include historical selector/catalog failures as described above; only their named passing methods contribute to the 20-scenario count.

## External limitations retained

Apple owns Edit Subscription. Its `[Environment: Xcode]` label and swipe policy cannot be changed using the public manage-subscriptions API. The local name is verified; hiding that footer or forcing that system controller to pull down is **not implemented or claimed**. App-owned Premium and the other modal screens do dismiss as tested. See [the implementation record](GLASS_SHEETS_PREMIUM_FOLLOWUP.md#apple-owned-subscription-screen) for official API references.

Google Play checkout/purchases with a live account were not performed in the isolated emulator package. Android purchase behavior is covered by deterministic verified-ownership tests and the actual Play metadata was checked; this is not a live purchase claim. No App Store Connect production metadata edit is claimed from a local StoreKit catalog.
