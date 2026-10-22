# Optional Glass Look (iOS)

The user's final contract is **Off by default**. Off preserves the current app's
appearance, including its system-managed glass/materials, native tab bar and
button styles. Off is not a new solid or flat theme. The only new Settings UI is
the Glass Look switch and its explanation under Appearance, below Dark Mode.

On selects the darker, clearer surface appearance requested from the Simulator
reference screenshots. It leaves the page visible through low-strength blur,
with restrained highlights and borders. App-owned cards, capsules, action
buttons, feedback and sheet backgrounds share this treatment. Text retains its
own contrast. The existing native bottom tab bar is used in **both** modes: its
position, size, selection and scrolling/minimization behavior stay unchanged.

The choice applies immediately, persists independently of language and Dark
Mode, and starts Off when missing or invalid. Its two UI strings are written in
English, Hindi, Tamil, Telugu, Gujarati and Bengali. It does not change schedule,
tradition, fasting progress, recording eligibility or WidgetKit designs. The
exported share-card image remains unchanged. System-owned menus, alerts,
keyboards and share interfaces continue to use the user's iOS appearance.

Reduce Transparency takes priority over the opt-in style. Reduced Motion is
respected by press feedback. No app setting overrides system accessibility.

## Validation contract

TDD started with `0d4984d`: the UI test reproduced the missing opt-in switch,
and the localization test reproduced both missing strings in all six languages.
Native rendering tests compare Off with a frozen pre-feature panel/capsule
implementation in dark and light appearances. The toggle UI test compares Home
before enabling and after disabling, excluding the live system status bar. The
Off Home screenshot also matched the pre-implementation screenshot exactly
outside the live status bar and home indicator (zero changed pixels).

A physical-device regression reproduced the reported **19-point vertical shift**
when switching Glass Look on. The final implementation retains the native
TabView bar throughout. Tests compare all five tab-item rectangles before and
after enabling/disabling in every language. Dark/light screenshots and bounds
checks also cover all six languages. The checks verify
that Home actions stay above the bar, there is exactly one native bar and no
replacement overlay, and the page background continues behind it.

Additional coverage checks preference persistence, independent Dark Mode,
accessibility precedence, six-language Settings/Home screenshots in both themes,
Calendar date retention, recording feedback and widget preview links.

Validation uses the iPhone 17 Pro Simulator on iOS 26.5 and the user's physical
iPhone 16 Plus on iOS 27.0.1 (24A446), with Xcode 26.6. Native material rendering
can vary with OS and hardware, so the enabled app-owned surfaces use controlled
blur/fills. The native tab bar deliberately keeps the existing system behavior.

Device tests use isolated in-memory app settings. Initial device runs used a
temporary local project matching the user's Apptinel provisioning profiles.
After the user's entitlements commit `418c226`, the checked-in XcodeGen spec and
public defaults were aligned with the same company app/widget identifiers and
App Group. Two configuration regressions reproduce the old mismatch before the
fix and guard runtime sharing plus regeneration. The regenerated original
project is also built with company signing. The app is reopened without test
arguments/clock after verification.

Android work remains deferred. This change adds no Android UI or preference.

## Final local checks

Combined applicable runs cover **270 Swift core tests**, **30 native app/rendering
tests**, **33 unique Simulator UI tests** (the 27 existing regressions plus six
Glass Look cases), and **six unique physical-iPhone UI cases**. The full Flutter
suite has **746 passing tests** and the analyzer reports **no issues**.

The physical geometry attachment records identical rectangles for all five tabs
with Glass Look Off and On: each retains its original vertical midpoint and
54-point item height on iPhone 16 Plus. The native bar itself stays at its
original 83-point frame. The pre-feature versus final Off Home pixel comparison
has zero changed pixels outside the live status bar/home indicator.

The Glass Look test driver expands and settles the native minimized bar before
tapping and measuring it; the existing regression suite's helper is unchanged.
No app override disables native minimization. No CI or merge was performed.

Signing configuration: **two tests passed** via `python3 tool/ios/test_signing_configuration.py`. The app and widget use `com.apptinel.ekadashi-calendar` / `.widgets`; both entitlements and runtime suite use `group.com.apptinel.ekadashi-calendar`. The stable background-refresh task identifier is retained and matches its Info.plist declaration.

After installing the corrected company-signed build on the physical iPhone and launching it normally, the shared-group plist contained a fresh, decodable `widget_snapshot_v2` (22 October 2026, 20:41 IST), including the current/next occurrence and 29 future occurrences. This verifies publication to the company group; Home/Lock Screen host refresh is being confirmed separately with the user.
