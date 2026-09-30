# Android Google Calendar import setup

## 1. Google Cloud Console
1. Create/select a project
2. Enable **Google Calendar API**
3. Configure OAuth consent screen (External or Internal)
4. Create **OAuth client ID** → Android
   - Package name: `com.applausestudios.ekadashi_calendar` (check your `applicationId`)
   - SHA-1: from `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`

## 2. `android/app/build.gradle`
Ensure `applicationId` matches the OAuth client.

## 3. No special permission in Manifest beyond internet (already present).

## 4. Wire in app (e.g. main or calendar host)

```dart
final repo = SqfliteCalendarEntryRepository();
await repo.init();

final google = GoogleCalendarService(
  auth: GoogleAuthGatewayAndroid(),
  repository: repo,
);

// pass into CalendarScreen:
CalendarScreen(
  ekadashiList: list,
  currentTimezone: tz,
  repository: repo,
  googleService: google,
);
```

## 5. First run
User taps cloud-sync icon → Google account picker → events for focused month imported as blue markers.
