# Ekadashi Calendar — 2027 Release Checklist

**Single source of truth** for shipping 2027 data, Telugu, custom calendar entries, and Google Calendar **import**.

| | |
|--|--|
| **Branch** | `feature/2027-telugu` |
| **Keep `main`** | On 2026 until you intentionally ship 2027 |
| **Package** | `ekadashi-2027-ready.zip` (code + wiring) / earlier zips if needed |
| **Android applicationId** | `com.applausestudios.ekadashi_calendar` |

---

## 0. What this release includes

| Feature | Status |
|---------|--------|
| 2027 Ekadashi data (24 entries, IST + 4 US zones, en/hi/ta/**te**) | Ready in zip |
| Telugu UI + language picker (తెలుగు) | Ready in zip |
| Calendar range 2027 | Ready in zip |
| Custom calendar entries (add/edit/delete, with time) | Ready in zip |
| Filters: All · Ekadashi · Google · Custom (default Ekadashi) | Ready in zip |
| Colors: Ekadashi teal · Google blue · Custom purple | Ready in zip |
| Google Calendar **import only** (no export, no edit of Google/Ekadashi) | Code ready; OAuth setup required for live import |
| Host wiring (`main.dart` → repo + Google service once at startup) | Ready in zip |
| Tests (unit / regression / filter / day list / Google service mock) | In zip |

**Explicitly out of scope for this release:** export Ekadashi → Google, edit Google events in-app, iOS / Apple Calendar.

---

## 1. Apply code on the branch

```bash
cd path/to/ekadashi-calendar
git fetch origin
git checkout feature/2027-telugu
```

1. Unzip **`ekadashi-2027-ready.zip`** into the project root (overwrite matching paths).
2. Confirm these exist:
   - `assets/ekadashi_data.json` (2027)
   - `lib/main.dart` (calendar repo + `GoogleCalendarService` wiring)
   - `lib/screens/calendar_screen.dart` + `lib/screens/widgets/*`
   - `lib/models/*`, `lib/data/*`, `lib/services/google_*`
   - `pubspec.yaml` (new deps)
3. Commit & push:

```bash
git add -A
git status   # review
git commit -m "2027 data, Telugu, custom calendar entries, Google import wiring"
git push origin feature/2027-telugu
```

---

## 2. pubspec dependencies (must be present)

```yaml
dependencies:
  sqflite: ^2.4.2
  path: ^1.9.1
  google_sign_in: ^6.2.2
  googleapis: ^13.2.0
  extension_google_sign_in_as_googleapis_auth: ^2.0.2
  http: ^1.2.2
  # ...existing deps (table_calendar, provider, etc.)

dev_dependencies:
  sqflite_common_ffi: ^2.3.5
  flutter_test:
    sdk: flutter
```

```bash
flutter pub get
```

---

## 3. Google Cloud OAuth (only needed for **live** Google import)

App code is done. Google requires a one-time Cloud project so Sign-In + Calendar read is allowed.

### 3.1 Console steps

1. Open [Google Cloud Console](https://console.cloud.google.com/)
2. Create or select a project
3. **APIs & Services → Enable APIs** → enable **Google Calendar API**
4. **OAuth consent screen**
   - User type: **External** (for Play users) unless you only test inside an org
   - App name, support email, developer contact
   - Scopes: add Calendar **read-only** if prompted (`.../auth/calendar.readonly`)
   - Test users: add your Gmail while app is in Testing
5. **Credentials → Create credentials → OAuth client ID → Android**
   - Package name: `com.applausestudios.ekadashi_calendar`
   - SHA-1: debug keystore (below)

### 3.2 Debug SHA-1

```bash
keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey \
  -storepass android \
  -keypass android
```

Copy the **SHA-1** into the Android OAuth client.

### 3.3 After OAuth is configured

- Rebuild/run the app
- Calendar tab → **cloud sync** → pick Google account → events for the focused month appear (blue)

**Without OAuth:** Ekadashi + custom entries still work; sync may show an error snackbar.

**API limits (import-only, on-demand):** ~10,000 req/min/project, 600/min/user; daily free threshold 1,000,000 req/project. At ~1,500 users with occasional sync, cost should be **$0** under current rules. See Google Calendar API quota docs if scaling massively.

Full notes also in `android/GOOGLE_SETUP.md` inside the zip.

---

## 4. Test today (logical order)

### 4.1 Automated

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test test/unit
flutter test test/regression
flutter test test/widget/calendar_filter_bar_test.dart
flutter test test/widget/day_entries_list_test.dart
# optional full suite
flutter test
```

### 4.2 Manual — without Google OAuth

- [ ] App launches; no crash on Calendar tab
- [ ] Calendar year is **2027** (Jan–Dec)
- [ ] Filters: **All · Ekadashi · Google · Custom**; default **Ekadashi**
- [ ] Ekadashi markers **teal**; open details; **not** editable
- [ ] FAB **+** → add custom (title, all-day or start/end time, notes) → **purple** marker + list row
- [ ] Edit custom; swipe delete custom
- [ ] Same day can show Ekadashi + custom together when filter is **All**
- [ ] Language: **తెలుగు** in picker; UI + Ekadashi text in Telugu
- [ ] en / hi / ta still OK
- [ ] Timezones IST/EST/CST/MST/PST still OK
- [ ] Notifications (real device)
- [ ] Dark mode OK

### 4.3 Manual — with Google OAuth

- [ ] Tap **cloud sync**
- [ ] Account picker → grant calendar read
- [ ] Blue markers / list rows for imported events that month
- [ ] Filter **Google** shows only Google; **All** shows all three types
- [ ] Custom + Ekadashi unchanged after sync

### 4.4 Regression focus

- [ ] Official Ekadashi data still from JSON only
- [ ] Google import does not delete custom entries
- [ ] Clearing/re-sync does not wipe custom (by design)

---

## 5. Version bump

In `pubspec.yaml`:

```yaml
version: 1.2.0+5   # adjust to your scheme
```

Also update any hard-coded About/version strings in Settings if present.

```bash
git add pubspec.yaml
git commit -m "Bump version for 2027 release"
git push origin feature/2027-telugu
```

---

## 6. Build release artifacts

```bash
# Play Store
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab

# Sideload / QA
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

**Production SHA-1:** create a separate OAuth Android client (or add SHA-1) for your **upload/release** keystore before production users rely on Google sync.

---

## 7. Play Console

1. [Play Console](https://play.google.com/console) → Ekadashi Calendar  
2. Prefer **Internal testing** → **Closed testing** → **Production** staged rollout  
3. Upload `app-release.aab`  
4. Release notes (example):
   - 2027 Ekadashi calendar  
   - Telugu language support  
   - Custom calendar entries  
   - Optional Google Calendar import  
5. Listing (optional): Telugu short/full description; new screenshots with Telugu UI  

---

## 8. Merge to `main` (only when ready to leave 2026 behind)

```bash
git checkout main
git pull origin main
git merge feature/2027-telugu
git push origin main
```

Or open a PR: `feature/2027-telugu` → `main`.

Until merge, production/`main` can stay on 2026.

---

## 9. Post-release

- [ ] Install from test track / production on a real device  
- [ ] Confirm 2027 + Telugu + custom entry + (if configured) Google sync  
- [ ] Watch Play Vitals / crashes / reviews for a few days  
- [ ] Optional: announce Telugu + 2027  

---

## 10. One-page ship checklist

- [ ] Zip applied on `feature/2027-telugu` and pushed  
- [ ] `flutter pub get` + analyze + unit/regression/widget tests  
- [ ] Manual QA §4.2 (and §4.3 if OAuth done)  
- [ ] Version bumped  
- [ ] `flutter build appbundle --release`  
- [ ] Upload AAB (internal/closed first)  
- [ ] Release OAuth SHA-1 for production keystore if shipping Google sync  
- [ ] Merge → `main` when going live with 2027  
- [ ] Production rollout + smoke test  

---

## 11. Important paths

```
assets/ekadashi_data.json
lib/main.dart                          # repo + GoogleCalendarService wiring
lib/screens/calendar_screen.dart
lib/screens/widgets/calendar_filter_bar.dart
lib/screens/widgets/day_entries_list.dart
lib/screens/widgets/add_edit_entry_sheet.dart
lib/models/calendar_entry.dart
lib/models/calendar_day_merge.dart
lib/data/sqflite_calendar_entry_repository.dart
lib/services/google_calendar_service.dart
lib/services/google_auth_gateway_android.dart
lib/services/language_service.dart
android/GOOGLE_SETUP.md
pubspec.yaml
test/unit/
test/regression/
test/widget/
```

---

## 12. Optional / later (not blockers)

| Item | Notes |
|------|--------|
| CI (`.github/workflows/flutter_ci.yml`) | From earlier zip; enable if you want Actions |
| Deeper US sunrise scrape | Optional polish |
| iOS + Apple Calendar | Separate pass |
| Background Google sync | Not recommended for quotas; keep on-demand |
| Play verification for OAuth (if Google requires) | When moving consent screen to Production |

---

*Updated for 2027 + Telugu + custom entries + Google import (host wiring + OAuth). Use this file as the single checklist going forward.*
