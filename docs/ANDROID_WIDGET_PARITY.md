# Android widget functionality parity

Implemented on PR #24, `feature/ios-widget-redesign`, after the iOS changes.
Android keeps its existing native gradients, cards, icons and scrollable list.

## Available widgets and previews

| Widget | Home Screen sizes | Settings previews |
| --- | --- | --- |
| Ekadashi | Small (2×2), Medium (4×2), resizable | Small, Medium, Lock Screen |
| Upcoming Ekadashis | Medium (4×2), Large (4×4), resizable scrollable list | Medium, Large, Lock Screen |

There are two visible provider types. The retired Today provider remains hidden
for compatibility with already installed instances. Android launchers determine
the final cell allocation and widget padding.

The Ekadashi card uses today's occurrence by the Home city's civil date,
including before sunrise; otherwise it uses the nearest future occurrence.
Today's progress is the percentage remaining. Upcoming contains the next five
strictly future occurrences, excludes today, deduplicates by occurrence UID,
and crosses enabled years. At the end of the enabled schedule it shows fewer
entries and then a translated no-upcoming message.

Both native providers and Settings use `WidgetRenderer` and the same XML
layouts. Android 12+ publishes the Upcoming heading and all five native rows
together as one immutable `RemoteCollectionItems` snapshot. Older Android keeps
the existing service-backed list, with an atomic snapshot and safe blank rows
for late framework requests; no intermediate cleared list is exposed. Settings embeds them through a native Android platform view, including
the scrollable Upcoming list. Previews use the real Home schedule, location,
tradition, language and clock. They do not bind a real widget or ask for widget
permissions. All card and row taps carry the occurrence UID and open that exact
Home card and year, clearing previous Details navigation.

English, Hindi, Tamil, Telugu, Gujarati and Bengali cover widget labels,
descriptions, preview controls, fallback messages, dates, AM/PM and units. Long
text is bounded; constrained cards adjust typography, the small card keeps its
complete day count/remaining wording, and the medium card keeps both Parana time
endpoints. Existing native widget appearance is preserved.

## Lock Screen and refresh limits

Both providers declare native `home_screen|keyguard` support and a keyguard
layout. Compatible Android/OEM widget hosts can place these same native cards
on the Lock Screen; they are not iOS circular/rectangular accessories. The app
does not bypass normal unlocking. Settings explains that availability depends
on the device. Declaring support cannot enable a Lock Screen widget picker on
a device whose system UI does not offer one.

The payload caches the complete enabled Home-engine schedule, so providers can
advance without reopening the app. A one-time worker targets the next Home
midnight, timing boundary or 15-minute remaining-percentage update; date/time,
timezone, boot and package-change broadcasts refresh and reschedule. Android
may delay background work. No exact-to-the-minute background-delivery guarantee
is made. Missing or corrupt data asks the user to open the app; it does not
invent fasting times from a different city or tradition.

## TDD and validation

Separate failing-test commits precede implementation, starting with `400864a`.
They reproduce incorrect selection, missing exact Home links, absent native
previews/translations, unregistered keyguard support, legacy UID migration,
duplicate lists, clipped timings, context-sensitive cache fallbacks, manual
Home paging after a widget tap and unusable minimum-height lists.

Local passing gates:

- Flutter analyzer: no issues.
- Full Flutter suite: 746 tests.
- Full Android JVM suite: 86 tests, including native text metrics on API 28
  and 35, six languages, font scales 1.0/1.3, compact sizes and native tap intents.
- Full Swift core suite: 269 tests after shared localization generation.
- iOS app/rendering regression suite: 17 tests, plus two affected Settings UI tests
  after the separately requested white Panchang Lock Screen fix.

`integration_test/android_widget_parity_test.dart` exercises native Settings
previews in all six languages and a real platform-view tap to Home, and writes
fixtures for `LauncherWidgetTest` and `KeyguardWidgetHostTest`. The latter uses
the real Android framework KEYGUARD host category; it does not claim to test a
manufacturer's System UI. Emulator results are recorded below when available.

## Emulator verification and additional regressions

The six-language native Settings integration run passed and captured 30 widget
previews plus an exact-Home destination screenshot. Native fixture audits found
five distinct upcoming UIDs in every language and no Latin letters in the
five non-English display payloads (template placeholders excluded).

Screenshot review caught Tamil's countdown ellipsis despite passing rectangular
bounds checks. The failing regression `55249d8` now checks the complete countdown
for normal/larger text at 158×158, 110×110 and 110×60, including today, tomorrow,
four days and 30 days away. Fitting preserves the existing typography elsewhere.

The real Android 16 keyguard host caught a null-row race during collection refresh;
`8aabff0` reproduces late requests after an empty refresh or destruction. An
immutable snapshot and inert empty row prevent the framework parceling crash.
The stock launcher then caught a Gujarati heading above Bengali rows;
`e3922d3` requires the heading and rows to come from one locale snapshot. Modern
Android embeds the five rows in the same RemoteViews update, avoiding competing
asynchronous service updates.

Both providers passed the native KEYGUARD host check in all six languages on the
final APK. This is Android framework host validation, not a claim of successful
placement in a manufacturer's System UI. The installed emulator's system Lock
Screen picker is unavailable; actual OEM placement remains a device check.

Final stock-launcher rerun: **2 tests passed together**, each updating all six
languages. The Upcoming check taps a real collection row and validates its exact
occurrence URI; the single widget checks the same destination behavior. An
earlier run missed the launcher's drag placement; the unchanged binding test
passed in the clean rerun.

Final shared gates: Flutter **746 passed**, analyzer **no issues**, Swift core
release **269 passed**, and generated resources **up to date**.

The final native Settings integration rerun after all fitting/collection fixes
also passed: six languages × five preview configurations, **31 screenshots**
including the exact Home destination.
