# Google Play assets (v2) — in progress

Captured on the **Pixel 9 Pro XL** emulator (6.8", 1344 × 2992, Android 16,
AVD `Pixel_9_Pro_XL_Store`), dark mode, New Delhi, Vaishnava, Yearly premium
owned, no prices, Wi-Fi-only status bar (SystemUI demo mode).

## Status (24 Nov 2026)

- [x] Capture tooling: `tools/` (see below)
- [x] Raw captures (`raw/`): home, language-menu, tradition-menu, journey-overview
      (2026, 1,650 points), journey-share, journey-statistics, panchang-daily,
      panchang-muhurta, panchang-rashi (clock 1 Jan 2027 10:00 IST);
      calendar-diwali, panchang-festivals-oct (clock 29 Oct 2027 10:00 IST)
- [x] `share-card` re-captured (Saphala, 3 Jan) via session `share`
- [x] Widgets from Settings > Widget Preview, like iOS (session `widgets`): raw/widgets/
      (upcoming-large missing: Upcoming has no Large size; check). NEXT: compose slide 10 as a mock Android home screen with these.
- [ ] NEXT AFTER WIDGETS: compose all 10 slides (spec: tools/spec-main.json; crops for 01/07 tuned) like iOS (`../ios/tools/compose2.py`, FW=1320 FH=2347,
      then scale to 1080 × 1920); Arun picks 8 for Play (limit 8)
- [ ] Video: same flows recorded, ~1× speed, music = `../ios/preview/music-original-bhupali.m4a`
      (Arun chose it on 24 Nov 2026; re-render with ../ios/tools/synth.py if longer than 32 s)
- [ ] Listing text (short 80 / full 4000, no year), Data safety notes

App note: Panchang Key days shows "1 days ago" (should be "1 day ago").

## Tools

- `shots-only-app-changes.diff` + `shots_only.dart` (put in `lib/`): Premium from
  `--dart-define=SHOTS_PREMIUM=yearly|monthly`, prices blank. Never shipped.
- `store_shots_android_test.dart` (put in `integration_test/`): seeds Google
  holidays and family events, records 20 Ekadashis of 2026, prints `SHOT:<name>`.
- `rec-android.sh <jan|oct> <IST time> <out>`: only `emulator-5554`; sets the
  clock, New Delhi GPS, demo status bar, fresh install, keeps granting
  location/notification permissions, screencaps on each `SHOT:`.
  Run from a `dev` checkout with the diff applied.
