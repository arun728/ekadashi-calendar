# Wide screens: iPhone Duo and Android foldables

Apple's iPhone Duo (on sale 23 October 2026) is a book-style foldable: a
small outer screen and a large inner screen. Android foldables (Galaxy Z
Fold) and tablets are the same case. On these screens both apps show two
panes side by side; phones keep the one-column layout they have today.

## The rule

One width rule, shared by both apps through
`test/fixtures/adaptive_layout.json`:

| Constant | Value | Meaning |
| --- | --- | --- |
| `twoPaneMinWidth` | 560 | Content this wide or wider shows two panes |
| `readableMaxWidth` | 720 | Single-column content (Settings, details) stops growing here |
| `paneSpacing` | 16 | Gap between the panes |

The width is the space a tab's content is given, after the side safe areas
(points on iOS, logical pixels on Android). It is never the device model,
the idiom, the orientation or the main screen's size. Every iPhone in
portrait (440 pt or less), the Duo's outer screen (about 466 pt) and a Duo
app in a narrow Split View get one pane. The Duo's inner screen (about
626 to 669 pt wide in portrait, minus the status bar on the side, and 951 pt
in landscape) gets two.

- iOS: `AdaptiveLayout` in EkadashiCore (`AdaptiveLayoutTests`).
  `RootView` measures each tab (`.measuresPaneLayout()`), and screens read
  `@Environment(\.paneLayout)`, use `AdaptivePanes`, `.readableWidth()` and
  `.readableListMargins()` (DesignSystem/Adaptive.swift).
- Android: `AdaptiveLayout` in `lib/widgets/adaptive_layout.dart`
  (`adaptive_layout_test.dart`), measured with a `LayoutBuilder` per tab.

## What each screen does on a wide screen

| Screen | Left pane | Right pane |
| --- | --- | --- |
| Home | The Ekadashi card with its arrows | The year's Ekadashis; the card's one is highlighted, a tap opens another |
| Calendar | Month title and grid | The selected day (Ekadashi card and entries) |
| Journey, Overview | Streak and completion metrics, next milestone | Record an observance (recent Ekadashis) |
| Journey, History | Rows in two columns | |
| Journey, Statistics | Completion ring | Counts and streaks |
| Panchang, Key days | Days in two columns | |
| Panchang, Daily | Tithi, sun and moon, the five limbs | Timings, observances, details (or the Premium card) |
| Panchang, Muhurta | Choghadiya | Hora and Lagna |
| Panchang, Rashi | Sun and Moon rashi | Nakshatra |
| Settings, Ekadashi details, Premium | Readable width (720), centred | |

The Panchang Ekadashi sub-tab stays as it is (AGENTS.md, 13 October 2026).
Stacked, every screen is exactly the phone layout, in the same order.

## Folding and unfolding

Opening or closing the Duo resizes the app. The panes switch in place
(`AnyLayout` on iOS, the same widget tree on Android), so the selected
tab, date, month, Home card, Journey section and Panchang sub-tab stay.
`AdaptiveLayoutUITests.testResizingKeepsTheSelectedDay` rotates the device
as a stand-in for a resize.

## SDK and orientation

| Built with | iPhone Duo inner screen |
| --- | --- |
| iOS 26 SDK (Xcode 26) | The app at iPhone size, centred, with empty space around it |
| iOS 27 SDK | Most of the inner screen, beside the status bar |
| iOS 27.1 SDK (Xcode 27.1) | Edge to edge on both screens; tab bars and toolbars can move to the side |

Release builds should use Xcode 27.1. CI prefers Xcode 27.1 when the runner
has it, falls back to Xcode 26, and runs `AdaptiveLayoutUITests` on the
iPhone Duo simulator when one is installed
(`tool/ios/pick_simulator.py --prefer "iPhone Duo"`).

iPhones stay portrait (`UISupportedInterfaceOrientations`). Reports say the
Duo's inner screen does not honour that, so the layouts never depend on
orientation. `AdaptiveSourceTests` keeps `UIScreen.main`,
`userInterfaceIdiom`, `UIDevice.current.orientation`,
`interfaceOrientation` and `UIRequiresFullScreen` out of the app.

## Not done yet

- The iOS 27.1 APIs (vertical toolbar priorities, hinge/reserved regions,
  `ArrangementView`) need the 27.1 SDK and a Mac to compile and test.
- Multiple windows (`UIApplicationSupportsMultipleScenes`) stay off.
- App Store Connect: add iPhone Duo screenshots when the iOS app is listed
  (v2, end of 2026).

## References

- Apple, "Three steps to make your app shine on iPhone Duo":
  https://developer.apple.com/iphone-duo/prepare/
- 9to5Mac, "Here's how iPhone Duo treats apps not optimized for the
  foldable display" (9 September 2026)
