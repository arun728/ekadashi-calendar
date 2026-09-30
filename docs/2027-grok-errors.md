# You should already be on the branch
git checkout feature/2027-telugu

# Point this at where you extracted the zip
SRC=~/Downloads/ekadashi-combined-2027   # change if needed

# Copy everything from the zip over the repo (keeps project structure)
cp -R "$SRC"/* .
cd: no such file or directory: /Users/kumarm/Documents/pe/applause-studios/ekadashi-calendar
Already on 'feature/2027-telugu'
❯ # You should already be on the branch
git checkout feature/2027-telugu

# Point this at where you extracted the zip
SRC=~/Downloads/ekadashi-combined-2027   # change if needed

# Copy everything from the zip over the repo (keeps project structure)
cp -R "$SRC"/* .
M	README.md
M	android/app/src/main/AndroidManifest.xml
M	assets/ekadashi_data.json
M	lib/main.dart
M	lib/screens/calendar_screen.dart
M	lib/services/language_service.dart
M	pubspec.yaml
Already on 'feature/2027-telugu'
❯ g s
On branch feature/2027-telugu
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   README.md
	modified:   android/app/src/main/AndroidManifest.xml
	modified:   assets/ekadashi_data.json
	modified:   lib/main.dart
	modified:   lib/screens/calendar_screen.dart
	modified:   lib/services/language_service.dart
	modified:   pubspec.yaml

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	2027_RELEASE_CHECKLIST.md
	android/GOOGLE_SETUP.md
	android/app/src/main/kotlin/com/applausestudios/ekadashi_calendar/EkadashiHomeWidgetProvider.kt
	android/app/src/main/res/drawable/ekadashi_widget_background.xml
	android/app/src/main/res/layout/
	android/app/src/main/res/values/strings.xml
	android/app/src/main/res/xml/
	lib/data/
	lib/models/
	lib/screens/widgets/
	lib/services/ekadashi_widget_service.dart
	lib/services/fake_google_auth_gateway.dart
	lib/services/google_auth_gateway_android.dart
	lib/services/google_calendar_service.dart
	lib/services/google_event_mapper.dart
	test/regression/
	test/unit/calendar_entry_repository_test.dart
	test/unit/calendar_entry_test.dart
	test/unit/ekadashi_widget_service_test.dart
	test/unit/google_calendar_service_test.dart
	test/unit/google_event_mapper_test.dart
	test/unit/next_ekadashi_widget_data_test.dart
	test/widget/calendar_filter_bar_test.dart
	test/widget/day_entries_list_test.dart

no changes added to commit (use "git add" and/or "git commit -a")
❯ 
❯ 
❯ flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter run

┌─────────────────────────────────────────────────────────┐
│ A new version of Flutter is available!                  │
│                                                         │
│ To update to the latest version, run "flutter upgrade". │
└─────────────────────────────────────────────────────────┘
Resolving dependencies... (2.5s)
Downloading packages... (15.2s)
+ _discoveryapis_commons 1.0.7
  archive 4.0.7 (4.0.9 available)
  async 2.13.0 (2.13.1 available)
  characters 1.4.0 (1.4.1 available)
  cli_util 0.4.2 (0.5.2 available)
+ code_assets 1.2.1
  cross_file 0.3.5+1 (0.3.5+4 available)
  dbus 0.7.11 (0.7.14 available)
+ extension_google_sign_in_as_googleapis_auth 2.0.13 (3.0.0 available)
  ffi 2.1.4 (2.2.0 available)
  flutter_launcher_icons 0.13.1 (0.14.4 available)
  flutter_lints 3.0.2 (6.0.0 available)
  flutter_local_notifications 18.0.1 (22.3.0 available)
  flutter_local_notifications_linux 5.0.0 (8.0.1 available)
  flutter_local_notifications_platform_interface 8.0.0 (12.2.0 available)
  flutter_timezone 3.0.1 (5.1.0 available)
+ glob 2.1.3
+ google_cloud 0.5.0
+ google_identity_services_web 0.3.3+1
+ google_sign_in 6.3.0 (7.2.0 available)
+ google_sign_in_android 6.2.1 (7.2.16 available)
+ google_sign_in_ios 5.9.0 (6.3.0 available)
+ google_sign_in_platform_interface 2.5.0 (3.1.0 available)
+ google_sign_in_web 0.12.4+4 (1.1.3 available)
+ googleapis 13.2.0 (16.0.0 available)
+ googleapis_auth 2.3.3
+ home_widget 0.9.3
+ hooks 2.0.2 (2.1.0 available)
+ http 1.6.0
+ http_parser 4.1.2
  image 4.7.2 (4.9.1 available)
  intl 0.20.2 (0.20.3 available)
  json_annotation 4.9.0 (4.12.0 available)
  lints 3.0.0 (6.1.0 available)
+ logging 1.3.0
  matcher 0.12.17 (0.12.20 available)
  material_color_utilities 0.11.1 (0.13.1 available)
  meta 1.17.0 (1.19.0 available)
  mime 1.0.6 (2.0.0 available)
+ native_toolchain_c 0.19.2 (0.19.3 available)
  path_provider 2.1.5 (2.1.6 available)
  path_provider_android 2.2.22 (2.3.1 available)
  path_provider_foundation 2.5.1 (2.6.0 available)
  path_provider_linux 2.2.1 (2.2.2 available)
  path_provider_platform_interface 2.1.2 (2.1.3 available)
  petitparser 7.0.1 (7.0.2 available)
  posix 6.0.3 (6.5.2 available)
+ pub_semver 2.2.0
+ record_use 0.6.0 (1.1.0 available)
  share_plus 7.2.2 (13.3.0 available)
  share_plus_platform_interface 3.4.0 (7.2.0 available)
  shared_preferences 2.5.4 (2.5.5 available)
  shared_preferences_android 2.4.18 (2.4.27 available)
  shared_preferences_platform_interface 2.4.1 (2.4.2 available)
  source_span 1.10.1 (1.10.2 available)
+ sqflite 2.4.2+1 (2.4.3 available)
+ sqflite_android 2.4.2+3 (2.4.3 available)
+ sqflite_common 2.5.8 (2.5.11 available)
+ sqflite_common_ffi 2.4.0+3 (2.4.2 available)
+ sqflite_darwin 2.4.2 (2.4.3+1 available)
+ sqflite_platform_interface 2.4.0 (2.4.1 available)
+ sqlite3 3.5.1
+ synchronized 3.4.0 (3.4.1+1 available)
  table_calendar 3.2.0 (3.2.1 available)
  test_api 0.7.7 (0.7.13 available)
  timezone 0.9.4 (0.11.1 available)
  url_launcher_web 2.4.1 (2.4.3 available)
  uuid 4.5.2 (4.6.0 available)
  vector_math 2.2.0 (2.4.2 available)
  vm_service 15.0.2 (15.2.0 available)
  win32 5.15.0 (6.4.0 available)
  xml 6.6.1 (7.0.1 available)
Changed 29 dependencies!
60 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing ekadashi-calendar...                                          

   info • The imported package 'path' isn't a dependency of the importing
          package • lib/data/sqflite_calendar_entry_repository.dart:3:8 •
          depend_on_referenced_packages
warning • Unused import: 'dart:io' • lib/main.dart:2:8 • unused_import
   info • The import of 'package:flutter/foundation.dart' is unnecessary because
          all of the used elements are also provided by the import of
          'package:flutter/material.dart' • lib/main.dart:4:8 •
          unnecessary_import
warning • Unused import: 'package:timezone/data/latest.dart' •
       lib/main.dart:26:8 • unused_import
warning • The value of the field '_calendarServicesReady' isn't used •
       lib/main.dart:110:8 • unused_field
warning • The value of the local variable 'found' isn't used •
       lib/main.dart:624:10 • unused_local_variable
   info • Don't use 'BuildContext's across async gaps • lib/main.dart:727:47 •
          use_build_context_synchronously
   info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues()
          to avoid precision loss • lib/main.dart:1135:33 •
          deprecated_member_use
   info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues()
          to avoid precision loss • lib/main.dart:1279:31 •
          deprecated_member_use
   info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues()
          to avoid precision loss • lib/screens/details_screen.dart:59:42 •
          deprecated_member_use
   info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues()
          to avoid precision loss • lib/screens/details_screen.dart:66:44 •
          deprecated_member_use
   info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues()
          to avoid precision loss • lib/screens/details_screen.dart:131:55 •
          deprecated_member_use
   info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues()
          to avoid precision loss • lib/screens/details_screen.dart:134:43 •
          deprecated_member_use
   info • The private field _isCheckingPermissions could be 'final' •
          lib/screens/settings_screen.dart:35:8 • prefer_final_fields
warning • The value of the field '_isCheckingPermissions' isn't used •
       lib/screens/settings_screen.dart:35:8 • unused_field
   info • Don't use 'BuildContext's across async gaps •
          lib/screens/settings_screen.dart:134:58 •
          use_build_context_synchronously
   info • 'activeColor' is deprecated and shouldn't be used. Use
          activeThumbColor instead. This feature was deprecated after
          v3.31.0-2.0.pre • lib/screens/settings_screen.dart:249:11 •
          deprecated_member_use
   info • 'activeColor' is deprecated and shouldn't be used. Use
          activeThumbColor instead. This feature was deprecated after
          v3.31.0-2.0.pre • lib/screens/settings_screen.dart:276:11 •
          deprecated_member_use
   info • 'activeColor' is deprecated and shouldn't be used. Use
          activeThumbColor instead. This feature was deprecated after
          v3.31.0-2.0.pre • lib/screens/settings_screen.dart:294:11 •
          deprecated_member_use
   info • 'activeColor' is deprecated and shouldn't be used. Use
          activeThumbColor instead. This feature was deprecated after
          v3.31.0-2.0.pre • lib/screens/settings_screen.dart:312:11 •
          deprecated_member_use
   info • 'activeColor' is deprecated and shouldn't be used. Use
          activeThumbColor instead. This feature was deprecated after
          v3.31.0-2.0.pre • lib/screens/settings_screen.dart:330:11 •
          deprecated_member_use
   info • 'activeColor' is deprecated and shouldn't be used. Use
          activeThumbColor instead. This feature was deprecated after
          v3.31.0-2.0.pre • lib/screens/settings_screen.dart:348:11 •
          deprecated_member_use
   info • Use 'const' with the constructor to improve performance •
          lib/screens/splash_screen.dart:53:12 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance •
          lib/screens/splash_screen.dart:55:13 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance •
          lib/screens/splash_screen.dart:56:16 • prefer_const_constructors
   info • Use 'const' literals as arguments to constructors of '@immutable'
          classes • lib/screens/splash_screen.dart:58:21 •
          prefer_const_literals_to_create_immutables
   info • Use 'const' with the constructor to improve performance •
          lib/screens/splash_screen.dart:59:13 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance •
          lib/screens/splash_screen.dart:62:22 • prefer_const_constructors
   info • 'activeColor' is deprecated and shouldn't be used. Use
          activeThumbColor instead. This feature was deprecated after
          v3.31.0-2.0.pre • lib/screens/widgets/add_edit_entry_sheet.dart:141:15
          • deprecated_member_use
   info • The import of 'dart:ui' is unnecessary because all of the used
          elements are also provided by the import of
          'package:flutter/services.dart' •
          lib/services/notification_service.dart:2:8 • unnecessary_import
   info • Don't invoke 'print' in production code •
          scripts/verify_days_to_go.dart:7:5 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_days_to_go.dart:19:3 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_days_to_go.dart:29:9 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_days_to_go.dart:50:10 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_days_to_go.dart:51:10 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_days_to_go.dart:52:10 • avoid_print
   info • The variable name 'simulatedToday_SameDay' isn't a lowerCamelCase
          identifier • scripts/verify_days_to_go.dart:57:13 •
          non_constant_identifier_names
   info • Don't invoke 'print' in production code •
          scripts/verify_days_to_go.dart:65:9 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_days_to_go.dart:78:9 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_days_to_go.dart:83:3 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_days_to_go.dart:84:3 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_days_to_go.dart:85:3 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_days_to_go.dart:86:3 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_days_to_go.dart:87:3 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_days_to_go.dart:88:3 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_days_to_go.dart:91:5 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_days_to_go.dart:93:5 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:7:5 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:15:3 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:16:3 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:17:3 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:18:3 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:19:3 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:20:3 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:21:3 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:37:9 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:44:10 • avoid_print
   info • Use 'const' with the constructor to improve performance •
          scripts/verify_notifications.dart:58:49 • prefer_const_constructors
   info • Use 'const' with the constructor to improve performance •
          scripts/verify_notifications.dart:59:48 • prefer_const_constructors
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:83:5 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:85:5 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:88:3 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:90:5 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:91:5 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:92:5 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:93:5 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:94:5 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:95:5 • avoid_print
   info • Don't invoke 'print' in production code •
          scripts/verify_notifications.dart:96:5 • avoid_print
   info • Unnecessary braces in a string interpolation •
          scripts/verify_notifications.dart:127:30 •
          unnecessary_brace_in_string_interps
   info • Unnecessary braces in a string interpolation •
          scripts/verify_notifications.dart:127:35 •
          unnecessary_brace_in_string_interps
  error • The returned type 'String' isn't returnable from a 'Future<bool?>'
         function, as required by the closure's context •
         test/unit/ekadashi_widget_service_test.dart:14:29 •
         return_of_invalid_type_from_closure
warning • This function has a nullable return type of 'FutureOr<bool?>', but
       ends without returning a value •
       test/unit/ekadashi_widget_service_test.dart:15:30 •
       body_might_complete_normally_nullable
   info • The import of 'dart:typed_data' is unnecessary because all of the used
          elements are also provided by the import of
          'package:flutter/services.dart' • test/widget/app_flow_test.dart:2:8 •
          unnecessary_import
warning • Unused import:
       'package:ekadashi_calendar/services/native_location_service.dart' •
       test/widget/app_flow_test.dart:8:8 • unused_import
   info • Use 'const' for final variables initialized to a constant value •
          test/widget/app_flow_test.dart:82:10 • prefer_const_declarations
   info • Don't invoke 'print' in production code •
          tool/generate_asset.dart:16:3 • avoid_print

77 issues found. (ran in 4.7s)
00:05 +15: /Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/unit/services_test.dart: EkadashiService Logic Tests Device timezone fallback logic
📍 Device system timezone: America/New_York
📍 Matched timezone: America/New_York → EST
00:05 +16: /Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/unit/services_test.dart: EkadashiService Logic Tests Device timezone fallback for India
📍 Device system timezone: Asia/Kolkata
📍 Matched timezone: Asia/Kolkata → IST
00:05 +18: /Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/unit/services_test.dart: EkadashiService Logic Tests Device timezone fallback for Unknown/Default
📍 Device system timezone: Antarctica/Troll
📍 No match found, defaulting to IST
00:05 +19: ... delete removes custom entry                                     test/unit/ekadashi_widget_service_test.dart:14:34: Error: A value of type
'String' can't be returned from an async function with return type
'Future<bool?>'.
 - 'Future' is from 'dart:async'.
      save: (k, v) async => saved[k] = v,
                                 ^
00:05 +24 -1: loading /Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/unit/ekadashi_widget_service_test.dart [E]
  Failed to load "/Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/unit/ekadashi_widget_service_test.dart":
  Compilation failed for testPath=/Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/unit/ekadashi_widget_service_test.dart: test/unit/ekadashi_widget_service_test.dart:14:34: Error: A value of type 'String' can't be returned from an async function with return type 'Future<bool?>'.
   - 'Future' is from 'dart:async'.
        save: (k, v) async => saved[k] = v,
                                   ^
  .

To run this test again: /opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart test /Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/unit/ekadashi_widget_service_test.dart -p vm --plain-name 'loading /Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/unit/ekadashi_widget_service_test.dart'
00:09 +42 -1: /Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/widget/app_flow_test.dart: App loads and shows Home screen with Location
══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞═══════════════════════════════════════════════════════════
The following ProviderNotFoundException was thrown building Consumer<ThemeService>(dirty):
Error: Could not find the correct Provider<ThemeService> above this Consumer<ThemeService> Widget

This happens because you used a `BuildContext` that does not include the provider
of your choice. There are a few common scenarios:

- You added a new provider in your `main.dart` and performed a hot-reload.
  To fix, perform a hot-restart.

- The provider you are trying to read is in a different route.

  Providers are "scoped". So if you insert of provider inside a route, then
  other routes will not be able to access that provider.

- You used a `BuildContext` that is an ancestor of the provider you are trying to read.

  Make sure that Consumer<ThemeService> is under your MultiProvider/Provider<ThemeService>.
  This usually happens when you are creating a provider and trying to read it immediately.

  For example, instead of:

  ```
  Widget build(BuildContext context) {
    return Provider<Example>(
      create: (_) => Example(),
      // Will throw a ProviderNotFoundError, because `context` is associated
      // to the widget that is the parent of `Provider<Example>`
      child: Text(context.watch<Example>().toString()),
    );
  }
  ```

  consider using `builder` like so:

  ```
  Widget build(BuildContext context) {
    return Provider<Example>(
      create: (_) => Example(),
      // we use `builder` to obtain a new `BuildContext` that has access to the provider
      builder: (context, child) {
        // No longer throws
        return Text(context.watch<Example>().toString());
      }
    );
  }
  ```

If none of these solutions work, consider asking for help on StackOverflow:
https://stackoverflow.com/questions/tagged/flutter

The relevant error-causing widget was:
  Consumer<ThemeService>
  Consumer:file:///Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/lib/main.dart:55:12

When the exception was thrown, this was the stack:
#0      Provider._inheritedElementOf (package:provider/src/provider.dart:377:7)
#1      Provider.of (package:provider/src/provider.dart:327:30)
#2      Consumer.buildWithChild (package:provider/src/consumer.dart:181:16)
#3      SingleChildStatelessWidget.build (package:nested/nested.dart:259:41)
#4      StatelessElement.build (package:flutter/src/widgets/framework.dart:5892:49)
#5      SingleChildStatelessElement.build (package:nested/nested.dart:279:18)
#6      ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5820:15)
#7      Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#8      ComponentElement._firstBuild (package:flutter/src/widgets/framework.dart:5802:5)
#9      ComponentElement.mount (package:flutter/src/widgets/framework.dart:5796:5)
#10     SingleChildWidgetElementMixin.mount (package:nested/nested.dart:222:11)
...     Normal element mounting (7 frames)
#17     Element.inflateWidget (package:flutter/src/widgets/framework.dart:4590:20)
#18     Element.updateChild (package:flutter/src/widgets/framework.dart:4053:20)
#19     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#20     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#21     ProxyElement.update (package:flutter/src/widgets/framework.dart:6152:5)
#22     _InheritedNotifierElement.update (package:flutter/src/widgets/inherited_notifier.dart:108:11)
#23     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#24     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#25     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#26     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#27     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#28     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#29     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#30     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#31     ProxyElement.update (package:flutter/src/widgets/framework.dart:6152:5)
#32     _InheritedNotifierElement.update (package:flutter/src/widgets/inherited_notifier.dart:108:11)
#33     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#34     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#35     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#36     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#37     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#38     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#39     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#40     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#41     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#42     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#43     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#44     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#45     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#46     ProxyElement.update (package:flutter/src/widgets/framework.dart:6152:5)
#47     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#48     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#49     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#50     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#51     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#52     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#53     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#54     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#55     ProxyElement.update (package:flutter/src/widgets/framework.dart:6152:5)
#56     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#57     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#58     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#59     ProxyElement.update (package:flutter/src/widgets/framework.dart:6152:5)
#60     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#61     _RawViewElement._updateChild (package:flutter/src/widgets/view.dart:481:16)
#62     _RawViewElement.update (package:flutter/src/widgets/view.dart:568:5)
#63     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#64     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#65     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#66     StatelessElement.update (package:flutter/src/widgets/framework.dart:5898:5)
#67     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#68     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#69     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#70     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#71     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#72     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#73     RootElement._rebuild (package:flutter/src/widgets/binding.dart:1782:16)
#74     RootElement.update (package:flutter/src/widgets/binding.dart:1760:5)
#75     RootElement.performRebuild (package:flutter/src/widgets/binding.dart:1774:7)
#76     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#77     BuildScope._tryRebuild (package:flutter/src/widgets/framework.dart:2750:15)
#78     BuildScope._flushDirtyElements (package:flutter/src/widgets/framework.dart:2807:11)
#79     BuildOwner.buildScope (package:flutter/src/widgets/framework.dart:3111:18)
#80     AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:1506:19)
#81     RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:495:5)
#82     SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1434:15)
#83     SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1347:9)
#84     AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:1335:9)
#87     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#88     AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:1324:27)
#89     WidgetTester.pumpWidget.<anonymous closure> (package:flutter_test/src/widget_tester.dart:598:22)
#92     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#93     WidgetTester.pumpWidget (package:flutter_test/src/widget_tester.dart:595:27)
#94     main.<anonymous closure> (file:///Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/widget/app_flow_test.dart:112:18)
#95     testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:29)
<asynchronous suspension>
#96     TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1059:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 5 frames from dart:async and package:stack_trace)

════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Ekadashi Calendar": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/widget/app_flow_test.dart:116:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1059:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/widget/app_flow_test.dart line 116
The test description was:
  App loads and shows Home screen with Location
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following message was thrown:
Multiple exceptions (2) were detected during the running of the current test, and at least one was
unexpected.
════════════════════════════════════════════════════════════════════════════════════════════════════
00:09 +42 -2: /Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/widget/app_flow_test.dart: App loads and shows Home screen with Location [E]
  Test failed. See exception logs above.
  The test description was: App loads and shows Home screen with Location
  

To run this test again: /opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart test /Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/widget/app_flow_test.dart -p vm --plain-name 'App loads and shows Home screen with Location'
00:09 +42 -2: /Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/widget/app_flow_test.dart: App handles Location Denied state
══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞═══════════════════════════════════════════════════════════
The following ProviderNotFoundException was thrown building Consumer<ThemeService>(dirty):
Error: Could not find the correct Provider<ThemeService> above this Consumer<ThemeService> Widget

This happens because you used a `BuildContext` that does not include the provider
of your choice. There are a few common scenarios:

- You added a new provider in your `main.dart` and performed a hot-reload.
  To fix, perform a hot-restart.

- The provider you are trying to read is in a different route.

  Providers are "scoped". So if you insert of provider inside a route, then
  other routes will not be able to access that provider.

- You used a `BuildContext` that is an ancestor of the provider you are trying to read.

  Make sure that Consumer<ThemeService> is under your MultiProvider/Provider<ThemeService>.
  This usually happens when you are creating a provider and trying to read it immediately.

  For example, instead of:

  ```
  Widget build(BuildContext context) {
    return Provider<Example>(
      create: (_) => Example(),
      // Will throw a ProviderNotFoundError, because `context` is associated
      // to the widget that is the parent of `Provider<Example>`
      child: Text(context.watch<Example>().toString()),
    );
  }
  ```

  consider using `builder` like so:

  ```
  Widget build(BuildContext context) {
    return Provider<Example>(
      create: (_) => Example(),
      // we use `builder` to obtain a new `BuildContext` that has access to the provider
      builder: (context, child) {
        // No longer throws
        return Text(context.watch<Example>().toString());
      }
    );
  }
  ```

If none of these solutions work, consider asking for help on StackOverflow:
https://stackoverflow.com/questions/tagged/flutter

The relevant error-causing widget was:
  Consumer<ThemeService>
  Consumer:file:///Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/lib/main.dart:55:12

When the exception was thrown, this was the stack:
#0      Provider._inheritedElementOf (package:provider/src/provider.dart:377:7)
#1      Provider.of (package:provider/src/provider.dart:327:30)
#2      Consumer.buildWithChild (package:provider/src/consumer.dart:181:16)
#3      SingleChildStatelessWidget.build (package:nested/nested.dart:259:41)
#4      StatelessElement.build (package:flutter/src/widgets/framework.dart:5892:49)
#5      SingleChildStatelessElement.build (package:nested/nested.dart:279:18)
#6      ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5820:15)
#7      Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#8      ComponentElement._firstBuild (package:flutter/src/widgets/framework.dart:5802:5)
#9      ComponentElement.mount (package:flutter/src/widgets/framework.dart:5796:5)
#10     SingleChildWidgetElementMixin.mount (package:nested/nested.dart:222:11)
...     Normal element mounting (7 frames)
#17     Element.inflateWidget (package:flutter/src/widgets/framework.dart:4590:20)
#18     Element.updateChild (package:flutter/src/widgets/framework.dart:4053:20)
#19     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#20     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#21     ProxyElement.update (package:flutter/src/widgets/framework.dart:6152:5)
#22     _InheritedNotifierElement.update (package:flutter/src/widgets/inherited_notifier.dart:108:11)
#23     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#24     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#25     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#26     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#27     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#28     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#29     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#30     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#31     ProxyElement.update (package:flutter/src/widgets/framework.dart:6152:5)
#32     _InheritedNotifierElement.update (package:flutter/src/widgets/inherited_notifier.dart:108:11)
#33     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#34     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#35     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#36     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#37     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#38     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#39     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#40     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#41     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#42     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#43     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#44     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#45     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#46     ProxyElement.update (package:flutter/src/widgets/framework.dart:6152:5)
#47     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#48     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#49     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#50     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#51     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#52     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#53     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#54     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#55     ProxyElement.update (package:flutter/src/widgets/framework.dart:6152:5)
#56     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#57     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#58     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#59     ProxyElement.update (package:flutter/src/widgets/framework.dart:6152:5)
#60     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#61     _RawViewElement._updateChild (package:flutter/src/widgets/view.dart:481:16)
#62     _RawViewElement.update (package:flutter/src/widgets/view.dart:568:5)
#63     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#64     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#65     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#66     StatelessElement.update (package:flutter/src/widgets/framework.dart:5898:5)
#67     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#68     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#69     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#70     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#71     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#72     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#73     RootElement._rebuild (package:flutter/src/widgets/binding.dart:1782:16)
#74     RootElement.update (package:flutter/src/widgets/binding.dart:1760:5)
#75     RootElement.performRebuild (package:flutter/src/widgets/binding.dart:1774:7)
#76     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#77     BuildScope._tryRebuild (package:flutter/src/widgets/framework.dart:2750:15)
#78     BuildScope._flushDirtyElements (package:flutter/src/widgets/framework.dart:2807:11)
#79     BuildOwner.buildScope (package:flutter/src/widgets/framework.dart:3111:18)
#80     AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:1506:19)
#81     RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:495:5)
#82     SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1434:15)
#83     SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1347:9)
#84     AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:1335:9)
#87     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#88     AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:1324:27)
#89     WidgetTester.pumpWidget.<anonymous closure> (package:flutter_test/src/widget_tester.dart:598:22)
#92     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#93     WidgetTester.pumpWidget (package:flutter_test/src/widget_tester.dart:595:27)
#94     main.<anonymous closure> (file:///Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/widget/app_flow_test.dart:126:18)
#95     testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:29)
<asynchronous suspension>
#96     TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1059:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 5 frames from dart:async and package:stack_trace)

════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Location Denied": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/widget/app_flow_test.dart:130:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1059:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/widget/app_flow_test.dart line 130
The test description was:
  App handles Location Denied state
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following message was thrown:
Multiple exceptions (2) were detected during the running of the current test, and at least one was
unexpected.
════════════════════════════════════════════════════════════════════════════════════════════════════
00:09 +42 -3: /Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/widget/app_flow_test.dart: App handles Location Denied state [E]
  Test failed. See exception logs above.
  The test description was: App handles Location Denied state
  

To run this test again: /opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart test /Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/widget/app_flow_test.dart -p vm --plain-name 'App handles Location Denied state'
00:09 +42 -3: /Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/widget/app_flow_test.dart: Navigation to Calendar and Settings
══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞═══════════════════════════════════════════════════════════
The following ProviderNotFoundException was thrown building Consumer<ThemeService>(dirty):
Error: Could not find the correct Provider<ThemeService> above this Consumer<ThemeService> Widget

This happens because you used a `BuildContext` that does not include the provider
of your choice. There are a few common scenarios:

- You added a new provider in your `main.dart` and performed a hot-reload.
  To fix, perform a hot-restart.

- The provider you are trying to read is in a different route.

  Providers are "scoped". So if you insert of provider inside a route, then
  other routes will not be able to access that provider.

- You used a `BuildContext` that is an ancestor of the provider you are trying to read.

  Make sure that Consumer<ThemeService> is under your MultiProvider/Provider<ThemeService>.
  This usually happens when you are creating a provider and trying to read it immediately.

  For example, instead of:

  ```
  Widget build(BuildContext context) {
    return Provider<Example>(
      create: (_) => Example(),
      // Will throw a ProviderNotFoundError, because `context` is associated
      // to the widget that is the parent of `Provider<Example>`
      child: Text(context.watch<Example>().toString()),
    );
  }
  ```

  consider using `builder` like so:

  ```
  Widget build(BuildContext context) {
    return Provider<Example>(
      create: (_) => Example(),
      // we use `builder` to obtain a new `BuildContext` that has access to the provider
      builder: (context, child) {
        // No longer throws
        return Text(context.watch<Example>().toString());
      }
    );
  }
  ```

If none of these solutions work, consider asking for help on StackOverflow:
https://stackoverflow.com/questions/tagged/flutter

The relevant error-causing widget was:
  Consumer<ThemeService>
  Consumer:file:///Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/lib/main.dart:55:12

When the exception was thrown, this was the stack:
#0      Provider._inheritedElementOf (package:provider/src/provider.dart:377:7)
#1      Provider.of (package:provider/src/provider.dart:327:30)
#2      Consumer.buildWithChild (package:provider/src/consumer.dart:181:16)
#3      SingleChildStatelessWidget.build (package:nested/nested.dart:259:41)
#4      StatelessElement.build (package:flutter/src/widgets/framework.dart:5892:49)
#5      SingleChildStatelessElement.build (package:nested/nested.dart:279:18)
#6      ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5820:15)
#7      Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#8      ComponentElement._firstBuild (package:flutter/src/widgets/framework.dart:5802:5)
#9      ComponentElement.mount (package:flutter/src/widgets/framework.dart:5796:5)
#10     SingleChildWidgetElementMixin.mount (package:nested/nested.dart:222:11)
...     Normal element mounting (7 frames)
#17     Element.inflateWidget (package:flutter/src/widgets/framework.dart:4590:20)
#18     Element.updateChild (package:flutter/src/widgets/framework.dart:4053:20)
#19     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#20     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#21     ProxyElement.update (package:flutter/src/widgets/framework.dart:6152:5)
#22     _InheritedNotifierElement.update (package:flutter/src/widgets/inherited_notifier.dart:108:11)
#23     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#24     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#25     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#26     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#27     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#28     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#29     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#30     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#31     ProxyElement.update (package:flutter/src/widgets/framework.dart:6152:5)
#32     _InheritedNotifierElement.update (package:flutter/src/widgets/inherited_notifier.dart:108:11)
#33     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#34     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#35     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#36     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#37     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#38     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#39     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#40     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#41     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#42     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#43     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#44     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#45     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#46     ProxyElement.update (package:flutter/src/widgets/framework.dart:6152:5)
#47     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#48     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#49     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#50     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#51     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#52     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#53     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#54     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#55     ProxyElement.update (package:flutter/src/widgets/framework.dart:6152:5)
#56     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#57     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#58     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#59     ProxyElement.update (package:flutter/src/widgets/framework.dart:6152:5)
#60     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#61     _RawViewElement._updateChild (package:flutter/src/widgets/view.dart:481:16)
#62     _RawViewElement.update (package:flutter/src/widgets/view.dart:568:5)
#63     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#64     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#65     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#66     StatelessElement.update (package:flutter/src/widgets/framework.dart:5898:5)
#67     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#68     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#69     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#70     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#71     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#72     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#73     RootElement._rebuild (package:flutter/src/widgets/binding.dart:1782:16)
#74     RootElement.update (package:flutter/src/widgets/binding.dart:1760:5)
#75     RootElement.performRebuild (package:flutter/src/widgets/binding.dart:1774:7)
#76     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#77     BuildScope._tryRebuild (package:flutter/src/widgets/framework.dart:2750:15)
#78     BuildScope._flushDirtyElements (package:flutter/src/widgets/framework.dart:2807:11)
#79     BuildOwner.buildScope (package:flutter/src/widgets/framework.dart:3111:18)
#80     AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:1506:19)
#81     RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:495:5)
#82     SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1434:15)
#83     SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1347:9)
#84     AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:1335:9)
#87     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#88     AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:1324:27)
#89     WidgetTester.pumpWidget.<anonymous closure> (package:flutter_test/src/widget_tester.dart:598:22)
#92     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#93     WidgetTester.pumpWidget (package:flutter_test/src/widget_tester.dart:595:27)
#94     main.<anonymous closure> (file:///Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/widget/app_flow_test.dart:136:18)
#95     testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:29)
<asynchronous suspension>
#96     TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1059:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 5 frames from dart:async and package:stack_trace)

════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with icon "IconData(U+F06BB)": []" (used in a call to "tap()") could not
find any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2013:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1865:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1045:7)
#3      main.<anonymous closure> (file:///Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/widget/app_flow_test.dart:140:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1059:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  Navigation to Calendar and Settings
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following message was thrown:
Multiple exceptions (2) were detected during the running of the current test, and at least one was
unexpected.
════════════════════════════════════════════════════════════════════════════════════════════════════
00:09 +42 -4: /Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/widget/app_flow_test.dart: Navigation to Calendar and Settings [E]
  Test failed. See exception logs above.
  The test description was: Navigation to Calendar and Settings
  

To run this test again: /opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart test /Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/test/widget/app_flow_test.dart -p vm --plain-name 'Navigation to Calendar and Settings'
00:09 +51 -4: Some tests failed.                                               
Connected devices:
Chrome (web) • chrome • web-javascript • Google Chrome 151.0.7922.109

Wirelessly connected devices:
SM F731B (wireless) (mobile) • adb-RZCW70N7F3M-5j4lzp._adb-tls-connect._tcp •
android-arm64 • Android 13 (API 33)

[1]: Chrome (chrome)
[2]: SM F731B (wireless) (adb-RZCW70N7F3M-5j4lzp._adb-tls-connect._tcp)
Please choose one (or "q" to quit): 2
Launching lib/main.dart on SM F731B (wireless) in debug mode...
Running Gradle task 'assembleDebug'...                                 ⣷
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Installing build/app/outputs/flutter-apk/app-debug.apk...           7.7s
Error: ADB exited with exit code 1
Performing Streamed Install

adb: failed to install
/Users/kumarm/Documents/personal/applause-studios/ekadashi-calendar/build/app/ou
tputs/flutter-apk/app-debug.apk: Failure [INSTALL_FAILED_UPDATE_INCOMPATIBLE:
Existing package com.applausestudios.ekadashi_calendar signatures do not match
newer version; ignoring!]
Error launching application on SM F731B (wireless).

