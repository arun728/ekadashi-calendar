# Icons: one table for both apps

Every icon in the iOS and Android apps comes from one table,
`test/fixtures/app_icons.json`:

- `roles` names each place an icon appears (`tab_journey`, `home_tradition`,
  `sunrise`, `category_purnima`, ...) and the SF Symbol iOS shows there.
- `symbols` maps each SF Symbol to its twin in Flutter's `CupertinoIcons`
  (the Cupertino font draws Apple's symbols), which Android shows.

iOS reads the roles as `AppSymbol.<role>` (EkadashiCore,
`Support/AppSymbol.swift`); Android reads them as `AppIcons.<role>`
(`lib/widgets/app_icons.dart`). Both files are generated from the table, so a
place can only change on both platforms at once.

Tests keep it that way:

- `AppSymbolTests` (swift test): `AppSymbol` equals the table, search
  categories and achievements use it, and no iOS screen names an SF Symbol
  itself.
- `test/unit/app_icons_parity_test.dart`: `AppIcons` shows each role's
  Cupertino twin, and no Dart file uses `Icons.` or `CupertinoIcons.` outside
  `app_icons.dart`.
- `test/widget/app_icons_ui_test.dart`: the tab bar and Home's menus show the
  table's icons.

## Choices

- Journey shows progress and achievements, so its tab is an award rosette.
- Where an SF Symbol has no Cupertino twin, both apps use one that does:
  moonrise `moon.fill`, moonset `moon`, five limbs `circle.grid.hex`, Hora
  `hourglass`, Lagna `globe`, major observance `star.fill`, more details
  `list.bullet.below.rectangle`, partial fast `circle.lefthalf.fill`, best
  streak `checkmark.seal.fill`, Premium `star.circle.fill`, Chaturthi
  `hexagon`, Google reminders `calendar.circle`, no Ekadashi
  `calendar.badge.minus`, start fasting `sunrise.fill`, test notification
  `bell`.
- The leaf (Ekadashi, first fast, share card brand) has no Cupertino glyph;
  Android uses Material's eco leaf there.
- Home-screen widgets are drawn natively (WidgetKit, Android XML) and are not
  part of the table.

## Adding an icon

Add the role (and, for a new symbol, its Cupertino twin from the
`CupertinoIcons` list) to the table, regenerate both files, then use
`AppSymbol.<role>` and `AppIcons.<role>` at the same place on both platforms.
