# Home: what it must do

Each rule names the test that checks it on each platform. A change to Home
updates this list in the same commit: a new or changed rule gets its tests
on both platforms, and review checks the list, not only the code. "Gap"
means no test checks the rule yet; fill gaps before changing that area.

Started on 27 November 2026, after "All years" was found to stay on January
2027's first Ekadashi when picked from 2027 (added 17 November in fd54526 and
fdbbf6a; its only test started from the current year).

## Year menu (2026, 2027, All years)

Every starting point to every other option. Unless a rule says otherwise,
"next Ekadashi" means the current one until its Parana ends, else the next.

| From → to | Home shows | iOS test | Android test |
|---|---|---|---|
| 2027 → All years | the next Ekadashi | `AppModelTests.testAllYearsOpensOnTheNextEkadashiEvenFromAnotherYear`, `YearAndUpdateUITests.testAllYearsAfter2027OpensOnTheNextEkadashi` | `home_all_years_test` |
| 2026 (another card browsed) → All years | the next Ekadashi | `AppModelTests.testAllYearsOpensOnTheNextEkadashiEvenFromAnotherYear` | `home_all_years_test` |
| 2026 → All years (December, before Parana) | the current Ekadashi | `YearAndUpdateUITests.testHomeStartsInCurrentYearAndAllYearsIncludesBothCalendars` | `year_rollover_test` "All years leads the menu…", `integration_test/year_update_android_test` |
| All years → 2026 | 2026's next Ekadashi | Gap | `home_all_years_test` (the 2026 step) |
| All years → 2027 | 2027's first Ekadashi (when 2026's are all past: its next) | Gap | Gap |
| 2026 → 2027 | 2027's first Ekadashi | Gap | `home_all_years_test` (the 2027 step) |
| 2027 → 2026 | 2026's next Ekadashi | Gap | Gap |
| A year → Calendar | Calendar opens on that year | `AppModelTests.testHomeCityTraditionAndYearApplyAcrossTheApp` | `home_engine_test` "the year menu and Calendar stay on the same year" |
| Parana ends in All years | moves to the next Ekadashi, across New Year | `AppModelTests.testHomeScopeAndCivilYearRollOverAcrossCitiesTraditionsAndLanguages` | `year_rollover_test` "All years leads the menu and survives Parana rollover" |

## Tradition menu (Vaishnava, Smarta)

| Rule | iOS test | Android test |
|---|---|---|
| Vaishnava is the default; a saved choice survives restarts | `AppModelTests.testVaishnavaIsTheDefaultForMissingOrInvalidTraditionAndSavedChoicesSurvive` | `ekadashi_settings_test` "Chennai until something is picked or detected…" |
| Switching stays on the Ekadashi on screen | Gap | `home_engine_test` "switching the tradition stays on the Ekadashi on screen" |
| Menu order is Vaishnava, then Smarta | `AppModelTests.testHomeTraditionOrderIsVaishnavaThenSmarta` | `android_home_followup_test` "…menu order…" |

## City (detected, picked, launch)

| Rule | iOS test | Android test |
|---|---|---|
| Every launch detects the place again, even after a city was picked | `AppModelTests.testLaunchLocationRefreshPreservesTheWidgetOccurrence` (partly) | `home_engine_test` "reopening the app shows the place detected now…", `ekadashi_settings_test` |
| A picked city moves the Panchang tab; "Use current location" lets detection decide | Gap | `ekadashi_settings_test` "a city picked on Home wins over detection…" |
| A fresh install calculates only the detected place (not Chennai first) | Gap (Android-only work) | `home_launch_test` "a first launch without a saved city or last fix…" |
| A fix within 5 km with the same name is the same place (no recalculation) | Gap (Android-only work) | `ekadashi_settings_test` "a fix within 5 km…" |
| A new place shows its next Ekadashi before its full years | Gap (Android-only work) | `home_launch_test` "a new place shows the next Ekadashi…", `ekadashi_preview_test` |
| Declined location: Chennai, its next Ekadashi | Gap | Gap |

## Opening Home

| Rule | iOS test | Android test |
|---|---|---|
| Opens on the next Ekadashi; the year's first (often passed) card never flashes | Gap | `home_launch_test` "Home opens on the next Ekadashi without first showing…" |
| A widget or `ekadashi://` link opens its exact card across years | `AppModelTests.testWidgetDeepLinkSelectsExactHomeCardAcrossYearsWithoutDetailsSheet` | `android_widget_navigation_test` |
