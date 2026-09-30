# UI + Google calendars + Telugu picker fix

Copy over your `feature/2027-telugu` branch (on top of combined package).

## Changes
1. **Telugu** in home language menu (`తెలుగు`)
2. **Filter chips** full-width horizontal scroll (All / Ekadashi / Google / Custom) — no collision
3. **Sync** = standard `Icons.sync` top-right (not squeezed into chips)
4. **Calendar picker** on sync: checklist of Google calendars (Primary, Holidays in India, …); selection saved

## Test
```bash
flutter pub get
flutter run
```
- Language → తెలుగు
- Calendar: all 4 filters visible; sync icon top-right
- Sync → pick Holidays + Primary → Jan 2027 holidays should import
