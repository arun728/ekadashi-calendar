# Toolbar fixes, Glass audit and Android port review — 25 October 2026

Scope: PR #24, `feature/ios-widget-redesign`. Arun clarified that Calendar must
match Glass Off **only for toolbar icons and grouping**. Filters, entry cards
and other body surfaces must continue following the saved preference. No other
appearance differences listed below are authorized for correction yet.

## Implemented on iOS and Android

- Remove Panchang's calculation-info action and its now-unreachable notes sheet.
  Keep Today leading and Search alone trailing. Search uses the same shared
  renderer, size and trailing alignment as Home and Settings in each mode.
- Calendar keeps Search/Add/Google in the original Off toolbar appearance and
  group in both modes. The scope is the toolbar, not the Calendar body or the
  rest of the application. Existing translated labels and callbacks are retained.
- Update all tests referring to the removed action, including integration and
  screenshot flows. No Android native Home/Lock Screen widget designs changed.

## Remaining differences for Arun's decision — not changed

| Finding | Where / evidence | Recommendation to consider |
| --- | --- | --- |
| Search changes visible bounds when Glass is toggled | iOS Home, Journey, Panchang and Settings: accessibility bounds are 29.33 × 36 pt Off, 40 × 40 pt On on iPhone 17 Pro. Calendar is now identical in both modes (39.67 × 36 pt). These are exposed button bounds, not claims about the complete system hit target. | Choose one common Search size while retaining each background. Panchang already matches Home/Settings within either mode. |
| Search and other toolbar actions use different styling paths | iOS Search has an app-owned clear circle On; Today, Back, Share, Done and other system toolbar actions retain native system styling. Calendar is deliberately kept entirely Off per this request. | Decide whether all other toolbar actions should share the clear treatment, or retain native styling. |
| Primary/secondary action rendering changes more than translucency | iOS Home View Details/Share/Record and shared action styles: On uses custom capsule styling with explicit padding; Off uses native glass button styles. The Home comparison shows a different View Details outline/width. | If desired, preserve action geometry while changing only the surface. No action is missing. |
| City-picker rows become visible gray rounded groups | iOS Home/Panchang shared city picker: Off has flatter rows against its sheet; On has more visible group backgrounds. Captured in both modes. | Decide whether to keep those groups or make the rows as clear as the enabled sheet. |

The four rows above are the additional inconsistencies found in the reviewed
surfaces and style branches; they are not fixes silently included in this patch.
Android's shared Search bounds and tab geometry remain stable in the automated
appearance matrix. Its native/system dialogs do not become Apple's system glass.

## Expected appearance differences and deliberate exceptions

- App cards, menu capsules, Settings groups, filter selection fills and feedback
  become clearer with lighter tint On. The Panchang Daily hero visibly loses
  much of its solid teal fill. These are consequences of the approved opt-in
  style, rather than missing icons or changed functions.
- Sheet and list backgrounds change with the preference, while native keyboard,
  alerts, menus, date pickers and system controls retain their platform styling.
- Native bottom-tab frames/position remain the same. iOS still adapts its native
  material/selected-tab appearance to content; Android keeps its original bar.
- Installed widgets, their rendered preview content and exported share cards
  retain their own approved designs. The surrounding Settings page can change.
- Glass Off remains the default. Accessibility transparency/contrast fallbacks
  remain in place. No other toolbar, card, sheet or widget styling was altered.

## Coverage and evidence

Source audit: every Glass preference branch in iOS `Glass.swift`, `RootView.swift`
and Android `glass_look.dart`, `ios_style.dart`, `glass_tube.dart`,
`settings_group.dart`, plus shared toolbar composition.

Runtime audit on iPhone 17 Pro Simulator (iOS 26.5): both modes across all five
root tabs, four Journey sections, five Panchang sections, Details, Search, shared
city picker and widget preview. There are 36 captured screens and a text
attachment recording Search frames. Additional regressions cover all six
languages, dark/light, Calendar date retention and native tab-bar geometry.
The Android widget-test matrix covers all six languages, dark/light, 393 dp
normal text and 320 dp doubled text, persistence and accessibility fallback.
This is not a claim of inspecting every possible account, premium state, OS or
hardware combination.

Evidence lives in this task's `outputs/toolbar-audit/` directory. Comparison
sheets: `compare-tab-0.jpg`, `compare-tab-1.jpg`, `compare-panchang-daily.jpg`,
`compare-details.jpg`, `compare-city-picker.jpg`, `compare-search.jpg`,
`compare-journey-history.jpg`, `compare-widget-preview.jpg`. Individual screenshots
and manifests are under `focused/` and `screens/`.

## Android port history checked against commits

- `61c047f` (22 October): four Home/Calendar follow-ups — Home ring on the left,
  blocked-record feedback, localized complete Parana window, Vaishnava first and
  the default for absent/invalid preferences. Saved explicit tradition survives.
- `82b6322`: contain the ring stroke and preserve editing saved observances.
- `d29950d` (22 October): optional Android Glass Look, Off by default, stable tabs,
  translations and accessibility behavior. Emulator and M52 evidence is in
  `ANDROID_GLASS_LOOK.md`.
- **Latest Android port before this task: `f7ab401`, 23 October 22:07 IST.** It
  ports iOS `1990167`: pre-start countdown, Now with filling 0–100% progress until
  Parana starts, Parana at 100%, retention overnight through Parana end and then
  next occurrence; Home, widgets/previews, Calendar and Details, both traditions,
  all languages/timezones. Only the fasting date has the green Calendar marker.
  Saved records remain editable. Debug test-clock isolation and Release
  exclusion are covered. See `ANDROID_EKADASHI_LIFECYCLE.md`.
- There were **no later tracked feature/fix commits** on this PR before this
  task's red-test commit. The later iPhone Google-import repair restored an
  ignored local iOS Secrets configuration; it did not introduce an iOS source
  change needing an Android port. Google sign-in and import were confirmed by
  Arun on iPhone after that configuration was restored.
- The two toolbar fixes in this patch are implemented on both platforms.
  The iOS-only WidgetKit layouts and native circular/rectangular accessories are
  platform-specific; Android retains its approved native widget layouts and
  KEYGUARD host availability remains OEM-dependent. They are not missing ports.

## Google Calendar verification boundary

Android has its own Google Sign-In gateway and configured Web client plus
Firebase API/project build definitions. iOS's missing local client-ID issue does
not apply to that Android configuration. Presence was checked without logging
secret values. The older store-signed emulator installation is preserved; current
checks use the separate `.glasspreview` package because their signatures differ.

Automated import/reconciliation uses a deterministic Google account fixture,
real app screens and Android SQLite. It does not validate Google's real account
OAuth consent, package/signing-certificate registration or live calendar access.
A real-account import must be described separately from these checks.

## TDD and validation

Separate red commit `aee1372`: missing Panchang removal and Calendar Search
rendering reproduced in Flutter and native UI tests. Native red Calendar evidence
showed On height 40 pt versus Off 36 pt before the fix.

Passing full gates: analyzer has no issues; all **809 Flutter tests**;
**284 Swift core tests**; **36 iOS application/rendering tests**. Focused native
UI tests verify Panchang Search size/right alignment/navigation in both modes,
and Calendar toolbar pixels, Search geometry and Google-menu callbacks.
The evidence-only broad native audit also passes. One older fixed-progress test
initially ran with San Francisco Simulator GPS; its fixture requires Chennai
for its hard-coded 28% assertion, so that run is rerun with Chennai GPS.

Final additional UI/emulator results and device installation are recorded below.

- Android 16/API 36 ARM64 emulator: both integration tests passed in 2m47s.
  App navigation and real SQLite passed; free current-month Google import,
  account free-sync bookkeeping, premium gate, full-year import and remote-event
  deletion reconciliation passed using the deterministic Google fixture.
  Screenshots/logs are in `outputs/toolbar-audit/android-import/`.
- The signed Debug update was installed over the existing app on Arun's iPhone
  and launched to Calendar. Both the app and widget extension use Apptinel team
  `65HTQTRP96` and `group.com.apptinel.ekadashi-calendar`. Google client ID,
  callback scheme and Firebase API/project settings are populated. Existing app
  data was not cleared. No CI or merge was run.

- Real Android Google Sign-In entry check: Import opens Google's own account-add
  activity (`com.google.android.gms/.auth.uiflows.addaccount.ErrorActivity`),
  which reports “There was a problem connecting to accounts.google.com.” The app
  does not crash; backing out returns to Calendar with “Google sign-in cancelled.”
  No credentials or consent were entered. This demonstrates the native entry
  path but **does not establish a successful live import or OAuth configuration**.
  A screenshot is retained as `android-google-network-error.png`. Full real-account
  verification remains pending when Google connectivity/account access is available.
- Manual emulator checks confirm Panchang has Today leading and Search alone
  trailing in both modes, and Calendar keeps its grouped toolbar with Glass On.
  Captures: `android-calendar-off.png`, `android-calendar-on.png`,
  `android-panchang-off.png`, `android-panchang-on.png`. Preview preference was
  restored Off. No store-app data or device clock was changed.

- Android Calendar toolbar comparison: the exported Off/On toolbar crop had
  **0 changed pixels** at a 20/255 per-channel threshold, including its grouped
  Search/Add/Google controls; the body still visibly follows the preference.
- The six-language iOS dark/light appearance test passed after restoring the
  Chennai Simulator-location fixture (503.9 s). The initial San Francisco failure
  is retained in the logs rather than described as a product fix.

- Final iOS toolbar + six-language dark/light UI run: **3 passed, 0 failed**
  (`/private/tmp/ekadashi-toolbar-final-ui.xcresult`). The additional tab geometry,
  Calendar date retention and all-tabs/Details/feedback/widget-navigation checks
  passed in the preceding run. Together with the evidence-only audit, seven
  distinct native UI scenarios passed. Final captures are under `final-ui/`.
