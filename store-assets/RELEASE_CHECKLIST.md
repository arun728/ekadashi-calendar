# v2.0.0 release checklist (iOS + Android)

Written 24 Nov 2026. **Android releases first** (update to the live v1), **then iOS**
(first v2 launch) once Android is live and stable. Keep it current.
Store-asset details live in `STORE_CHECKLIST.md`. PRs #26 and #34 are **not** in this release.

## Shared: merge order into `dev` (each with Arun's OK, final tests and CI)

1. [ ] **#42 → #44: billing and payments** (Codex, in progress). Then device testing on the
       M52 and iPhone: buy, switch plans, restore, cancel and resubscribe, the free Google sync
       and the Vrat limit, on both platforms.
2. [ ] **#48**: Firebase email declaration and prices (the website part is already live).
3. [ ] **#49**: Android launch speed (review after #44; both touch `main.dart`).
4. [ ] **#47**: store assets (assets only, can merge any time).
5. [ ] Full CI on `dev`, then `dev` → `main` with Arun's approval.
6. [ ] Performance pass once every feature is tested: launch, each tab and the heaviest
       screens, on both platforms.

## 1. Android first (Google Play, update to the live v1)

- [ ] Final build from `main`: version 2.0.0, version code above 6, signed AAB.
- [ ] Internal testing: M52 and Arun's wife's phone. Real purchases with the license
      tester, plan switches, restore, free sync, widgets, launch speed, and an upgrade from
      v1 that keeps the data.
- [ ] **Data safety**: Email address + User IDs (optional, not shared, deletion on request):
      `android/listing/data-safety.md`.
- [ ] Subscriptions `ekadashi_premium` (Monthly, Yearly) + Lifetime active. India
      ₹100 / ₹600 / ₹2,000 as on Play now, plus diaspora prices.
- [ ] Listing: short and full description and release notes, English + Hindi
      (`android/listing/play-listing.md`). Name stays *Ekadashi Calendar*.
- [ ] Graphics: pick 8 of the 10 screenshots; feature graphic (ready); video uploaded to
      YouTube and linked (ask Arun before uploading).
- [ ] Privacy policy URL: apptinel.com or GitHub Pages (both live).
- [ ] Production: staged rollout (for example 20% → 100%); watch Android vitals.

## 2. Then iOS (App Store, first v2 launch)

- [ ] Start after the Android release is live and its staged rollout looks healthy.
- [ ] Final build from `main`: version 2.0.0, new build number, uploaded (Xcode or Transporter).
- [ ] TestFlight on Arun's iPhone: sandbox purchases, Restore, free Google sync, widgets, 6 languages.
- [ ] **App Privacy**: Email Address + User ID (linked, app functionality, not tracking).
      `PrivacyInfo.xcprivacy` is done in #48.
- [ ] In-app purchases Monthly / Yearly / Lifetime "Ready to Submit" with review screenshots
      (uploaded). Prices ₹99 / ₹599 / ₹1,999; diaspora prices set.
- [ ] Listing: name *Ekadashi Calendar & Panchang* (set), subtitle, keywords, promotional
      text, description, What's New: `ios/listing/` (English + Hindi).
- [ ] Screenshots 6.9" × 10, iPad 13" × 6 and the preview video: ready in `ios/`.
- [ ] Support, marketing, privacy and terms URLs on apptinel.com (live), age rating,
      category, copyright, review notes.
- [ ] After the listing has an ID: replace `AppLinks.appStorePlaceholder` (app change).
- [ ] Optional: Hindi custom product page; In-App Events with this year's dates.
- [ ] Submit for review, then release (manual or automatic).

## Housekeeping

- [ ] Delete the untracked `.deploy-tmp/` and the review copies in `store-assets/` from the main folder.
- [ ] Once the iOS listing exists, add its store link where the share texts need it.
