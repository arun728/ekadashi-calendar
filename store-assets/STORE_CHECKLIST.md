# App Store / Play Store assets checklist (v2)

Kept up to date as we discuss. iOS first; Android after iOS is final.

## ⚠️ MUST DO BEFORE SUBMISSION (iOS and Android)

- [ ] **Declare email collection.** Firebase Authentication stores the Google account email for everyone who uses the free Google Calendar import (confirmed in the Firebase console).
  - [ ] iOS App Privacy: Contact Info → **Email Address** and Identifiers → **User ID**; both App Functionality, linked to the user, not used for tracking.
  - [ ] iOS code: add `NSPrivacyCollectedDataTypeEmailAddress` (linked, not tracking, App Functionality) to `ios-native/EkadashiCalendar/Resources/PrivacyInfo.xcprivacy`, next to the existing User ID entry.
  - [ ] Android Play Console → Data safety: Personal info → **Email address** and Device or other IDs → **User IDs**; collected, not shared, App functionality, optional (only for Google import users), encrypted in transit, deletion on request.
- [ ] **Privacy policy (apptinel.com):** add that Firebase Authentication keeps the Google account email for the sign-in record (the Firestore record itself holds no email), and keep the deletion-request route via contact@apptinel.com.
- [ ] Set each In-App Event's dates for the release year (copy and art are year-free).

Done in App Store Connect (20–24 Nov 2026): iOS name → **Ekadashi Calendar & Panchang** (Android stays *Ekadashi Calendar*), App Store version → **2.0.0**. Repo made **private** (all store links point to apptinel.com).

## iOS — in progress
- [x] iPhone screenshots (draft for review: 10 main + 13 extras, see ios/README.md), dark look only, no prices, 2027 dates (New Delhi home)
  - [x] 6.9" 1320 × 2868 PNG, no alpha (up to 10)
  - [x] 6.5" 1284 × 2778 PNG (fallback)
  - [x] 6.3" 1206 × 2622 PNG (fallback)
  - Coverage: free + paid, paywalls, plans (Monthly / Yearly only, no Lifetime),
    language menu, Smarta / Vaishnava, worldwide city search, share cards,
    Calendar with Google holidays (all-India festivals) + custom entries + filters,
    Google sync, Journey (points, mixed observed / partial / missed, badges,
    share card with points), Panchang free preview + all premium sub-tabs + filters,
    Search free / premium + year menu + filters, festival reminders free / premium,
    Home and Lock Screen widgets
- [x] App preview video, 886 × 1920, 15–30 s, H.264 High ≤ L4.0, 30 fps, ~11 Mbps,
      AAC stereo 256 kbps 48 kHz, .mp4 (up to 3 per size and language)
  - [x] Original synthesized devotional music (tanpura + bansuri, Raga Bhupali, bells), no vocals
- [x] In-app purchase review screenshots — already uploaded in App Store Connect (real device, INR); copies in ios/iap-review/
- [x] iPad 13" screenshots 2064 × 2752 (6 slides): ios/screenshots/ipad-13in-2064x2752/
- [x] In-App Events (5 for 2027, art + en/hi copy): ios/in-app-events/ — card 1920 × 1080 + details 1080 × 1920 per event
      (e.g. Nirjala Ekadashi, Vaikuntha Ekadashi)
- [x] Promotional images for in-app purchases, 1024 × 1024 each: ios/iap-promo/
- [x] Custom product pages: plan in ios/custom-product-pages/README.md; Hindi page (10 slides, 3 sizes) in ios/custom-product-pages/hindi/
- [x] v2 brand poster: original v1 feature graphic with only the text changed, no year (en/hi): brand/
- [x] Product page text (en-US + hi): ios/listing/product-page-text.md
- [x] Support / privacy / marketing / terms URLs (apptinel.com, all live): ios/listing/app-store-connect.md
- [x] App Privacy labels, age rating, category, copyright, review notes: ios/listing/app-store-connect.md (confirm Firebase email)
- [x] IAP display names / descriptions + group name in 6 languages: ios/listing/app-store-connect.md
- [x] App icon 1024 × 1024 (already in the build)

## App features to build later
- [ ] Premium alternate app icons for subscribers — moved to v3

## Later
- [ ] Preview video pacing: research slower cuts (fewer scenes at ~1x) within the 30 s limit

## Android (after iOS is final)
- [ ] Phone screenshots re-captured from the Android app (same headlines, order and design; Android widgets), 1080 × 1920
- [ ] Preview video: same story, captions and music over Android footage, uploaded to YouTube
- [ ] Listing text (short 80 / full 4000) adapted from iOS, no year; name stays Ekadashi Calendar
- [x] Feature graphic 1024 × 500: brand/
- Skip tablet screenshots

Rule: no year anywhere in store text or art (dates inside app screenshots are fine).
