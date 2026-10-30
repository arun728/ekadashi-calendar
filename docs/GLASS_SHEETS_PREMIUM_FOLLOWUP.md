# Glass controls, modal dismissal and Premium follow-up — 26 October 2026

PR #24, `feature/ios-widget-redesign`; iOS and Android. This records Arun's
approved follow-up to the 25 October audit. Glass Look remains Off by default;
normal cards and exported/widget content keep their existing renderers.

## Resulting behavior

- Search has one stable toolbar size and trailing position between Glass modes.
  Calendar retains its Search/Add/Google group while its enclosure, and Today
  on Calendar/Panchang, actually follow the Glass preference. Readable text
  toolbar buttons keep their natural capsule width; icons have 44-point targets.
- Home action label padding and outlines use the same geometry between modes.
  The iOS action content shape also keeps accessibility/touch bounds consistent
  instead of reporting only an SF Symbol's ink in one mode.
  Share/Record are independent 48-point circles with explicit outlines; Home no
  longer groups their native glass effects into merging pressed surfaces.
  Blocked-record feedback is anchored above the entire action row, measured
  from its real layout, and fades in place. It does not slide across the buttons.
- Both Home and Panchang city pickers have explicit current/search/recent/popular
  groups in both modes. Android puts long translated timezone text below a city
  on narrow/large-text rows. Its 24-case matrix covers all six languages, both
  themes, normal/2x text, both city-picker variants and both Glass modes.
- Settings uses the shared `glass_look` role: SF `square.on.circle` and its
  Cupertino `square_on_circle` twin. The switch name, translations, preference
  persistence and accessibility fallback are retained.
- Share cards put **Save left, Share right** on both platforms, retaining the
  existing card image, save behavior, permissions, store links and share content.
- Verified Monthly ownership suggests Yearly; verified Yearly suggests Lifetime.
  Owned Lifetime remains selected at full opacity with an enabled plan card;
  the purchase action is hidden so it cannot be bought twice. Manual selection
  otherwise survives refreshes. Pending/cancelled/unverified purchases do not
  grant ownership or advance it.
- The local Xcode StoreKit group and all three product display names are
  **Ekadashi Premium**. Product IDs, prices and periods are unchanged. The live
  Google Play subscription already had that name for both base plans; its
  Lifetime product title was also updated to exactly **Ekadashi Premium** and
  the Console confirmed the change was saved. No App Store Connect production
  metadata change is claimed from a local StoreKit file.

## Close and dismissal parity

| Surface | Matching control / behavior |
| --- | --- |
| Premium (Settings or feature gates) | Leading X in a 44-point glass circle; pull down |
| Search | Leading down-chevron in the same circle; pull down from header or results/start content, including within horizontal category pages |
| Share card | Leading Cancel capsule; presented as a sheet, including when opened from Details; pull down |
| Home / every Panchang city picker | Leading Cancel capsule, organized groups; pull down |
| Entry editor, Google calendar picker, record observance, event reminder editor | Existing translated Cancel/Save/Done roles in matching capsules; shared sheet dismissal |
| Month/day/time picker, achievement sheet | Existing selection/confirmation controls; shared dismissal; wheel/page gestures keep their own behavior |
| Details, widget preview, pushed Panchang and reminder-choice pages | Back-chevron circle; pop their own navigation page |
| Five root tabs | Retain root navigation; no added dismiss action |

Android's common sheet host translates a downward pull at the top of a vertical
scroll view into movement of the actual sheet route (surface included), then
dismisses or snaps back. Short lists still accept the gesture. Normal scrolling,
short cancelled pulls, non-dismissible sheets and wheel/page controls are
protected. A horizontal Search PageView does not block vertical dismissal.
Nested navigation closes the entire presented Search sheet when pulled down;
back buttons still pop only the pushed page. OS-owned purchase/account/share
controllers keep their platform controls.

## TDD and validation

Red commits are separate: `b442058`, `f298109`, `7b5cc10`, `29483e3`, all
`[skip ci]`. Red runs reproduce missing Android enclosures, Share being a pushed
page, missing group/icon roles, content pulls not dismissing, wrong plan
suggestions and reversed Save/Share order. Native screenshot assertions also
caught unreadable text-toolbar ellipses and inconsistent action accessibility
bounds; both have layout fixes rather than relaxed assertions.

The Home shape regression starts with `dba12f8`: iOS rendered the icons at
48×42, and Android Share had no outline. `f71987b` reproduces a second issue:
the feedback capsule overlaps the action row (iOS measured 744 pt against a
705.67 pt clearance limit). The regression matrix checks all six languages,
both themes, normal/large text and both Glass modes on Android; native UI tests
check the actual Home feedback and Calendar translations in all six languages.

- `flutter analyze`: no issues.
- Complete Flutter suite: **860 passed**, including the six-language appearance
  matrix, city layout matrix, purchase ownership and navigation regressions.
- Complete `swift test -c release` in EkadashiCore: **286 passed**.
- Native iOS app/rendering suite: **40 passed on iOS 18.6**; iOS 26.5 has the documented local-catalog skip.
- StoreKit UI purchase chain: **passed on iOS 18.6 Simulator**, real-time test
  subscriptions and actual foreground entitlement refresh, no mock grants.
  The iOS 26.5 command-line runner did not provision its local StoreKit session;
  its off-device purchase failed before product retrieval. It was not counted
  as passing. General app/appearance UI tests use iPhone 17 Pro / iOS 26.5.
- Native and Android emulator final visual runs are recorded with screenshot
  manifests under local `outputs/controls-followup/`. These are test artifacts,
  ignored by Git, not app assets. Native six-language UI checks pin both time
  and Chennai so simulator GPS cannot change the expected percentage.

Final per-change results and measured coverage are recorded in
[the validation report](PR24_FOLLOWUP_VALIDATION_2026-10-26.md).

## Apple-owned subscription screen

The user's newer iPhone photo confirms that Edit Subscription now shows the
correct name. This controller is supplied by StoreKit, not by PremiumView.
Apple's public [manageSubscriptionsSheet](https://developer.apple.com/documentation/swiftui/view/managesubscriptionssheet(ispresented:))
and [showManageSubscriptions](https://developer.apple.com/documentation/storekit/appstore/showmanagesubscriptions(in:))
APIs expose presentation, not a footer-removal or swipe-gesture customization
setting. Its Xcode environment label identifies local simulated purchases;
it is not an app-authored footer or an App Store production label. The app does
not hide it, replace Apple's financial-management controls, or claim to force
that controller's pull-down dismissal. The app's own Premium and other modal
screens have the verified dismissal behavior described above.

No Android native widget redesign, billing identity/signing change, real purchase,
CI run or merge is included. After Arun requested Simulator-only completion,
no further phone installation was performed. The Z Flip 5 remains deferred.
