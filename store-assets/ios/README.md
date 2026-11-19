# iOS App Store assets (v2)

Made from the latest `dev` build (28f79bc) on the iPhone 17 Pro Max simulator
(iOS 26.5), dark mode, Glass Look off. Dates are in 2027 (New Delhi home,
Vaishnava). Journey points use 2026 Ekadashis whose Parana has passed, with a
realistic mix of observed, partial and missed. No prices appear anywhere
(App Review Guideline 2.3.7); plans read Monthly / Yearly.

## Screenshots

`screenshots/main/` — the 10 slides to upload, in this order:

| # | File | Tag | Shows |
|---|------|-----|-------|
| 1 | 01-never-miss-an-ekadashi | Free | Home, Jan 2027, fasting and Parana |
| 2 | 02-your-language-your-tradition | Free | Language menu (6 languages) |
| 3 | 03-festivals-in-your-calendar | — | Calendar with Google holidays (Diwali) |
| 4 | 04-full-panchang-every-day | Premium | Panchang Daily, Tithi card |
| 5 | 05-every-festival | Premium | Key days, Festivals filter (Oct 2027) |
| 6 | 06-muhurta-choghadiya-hora | Premium | Muhurta, Choghadiya, Hora |
| 7 | 07-every-vrat-remembered | Premium | Journey, 1,650 points |
| 8 | 08-share-your-journey | Premium | Annual Journey card with points and badges |
| 9 | 09-share-the-vrat | Free | Ekadashi share card |
| 10 | 10-home-and-lock-screen | Free | Home and Lock Screen widgets |

`screenshots/extras/` — 13 more for custom product pages or swaps: Search free
vs Premium, any city, Smarta / Vaishnava, Panchang free preview, festival
reminders (Premium and free), first three vrats free, Vrat paywall, plans,
Premium member, Journey statistics, Holi in the calendar, Rashi.

Each slide comes in three sizes (PNG, RGB, no alpha):

- `iphone-6.9in-1320x2868` — upload this set (App Store Connect scales it down)
- `iphone-6.5in-1284x2778` — fallback for the 6.5" slot if requested
- `iphone-6.3in-1206x2622` — fallback for the 6.3" slot if requested

App Store limits: up to 10 screenshots per device size per language.

`screenshots/ipad-13in-2064x2752/` — 6 iPad slides (required because the app runs on iPad;
kept short since the app is phone-first). The status-bar date is blanked because
simctl can't override it on iPad.

Also here: `listing/` (product page text, App Store Connect answers),
`iap-review/`, `iap-promo/`, `in-app-events/`, `custom-product-pages/` and
`../brand/` (v2 poster).

## App preview

`preview/ekadashi-app-preview-886x1920.mp4`

- 886 × 1920 portrait, 28.87 s (limit 15–30 s), 30 fps
- H.264 High Profile, level 4.0, ~10.9 Mbps
- AAC LC stereo, 256 kbps, 48 kHz
- Footage is real screen recording of the app; captions match the screenshots
- Poster frame: the default (5 s) lands on Home in हिंदी
- Music: original, synthesized in code (tanpura drone, bansuri-like lead in
  Raga Bhupali, temple bells). No samples, recordings or existing tunes, so
  no copyright issue. No vocals.

Up to 3 previews per device size per language.

## How they were made (`tools/`)

- `StoreShotsUITests.swift` — XCUITest capture script (not in the app's test
  target). It needs the temporary, screenshot-only changes in
  `tools/shots-only-app-changes.diff` (pinned Panchang date, sample Google
  holidays, a subscription treated as owned, prices hidden). Those changes
  are never shipped.
- `compose2.py` — frames (headless Chrome, 1320 × 2868)
- `vcompose.py`, `rec.sh`, `scenes.json` — preview video
- `synth.py` — the music (`preview/music-original-bhupali.m4a` is its output)
- `grid.py` — draws a 100 px grid on captures to measure callout crops
- `sheet.py` — contact sheets for reviewing captures
- `spec-main.json`, `spec-extra.json` — headlines, crops and layout for each slide

Requirements: Xcode 26.x with the iOS 26.5 simulator, `xcodegen`, `ffmpeg`,
Google Chrome, Python 3 with `numpy` and `pillow`.

See `../STORE_CHECKLIST.md` for what is still to do (iPad 13", IAP review
screenshots, In-App Events, IAP promo images, custom product pages, text).
