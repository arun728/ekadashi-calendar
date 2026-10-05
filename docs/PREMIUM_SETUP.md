# Ekadashi Premium setup (v2, Google Play only)

v2 has no premium server. The app unlocks premium from what Google Play Billing
reports as owned on the device, and acknowledges completed purchases. The
paywall needs no Google sign-in. Google sign-in is used only for read-only
Google Calendar import. Fasting rewards are hidden; `backend/` is dormant.

## Free vs premium

| Feature | Free | Premium |
|---|---|---|
| Ekadashi dates, reminders, widgets, search, custom entries | Yes | Yes |
| Google Calendar import (import only) | One sync ever, of the month on screen | Whole selected year, any time while the subscription is active |
| Vrat entries | First 3 new entries (editing always free) | Unlimited + all achievements |
| Panchang | Daily preview | Full limbs, timings, observances, browsing |

## 1. Create the products in Play Console (prices live here, not in code)

Play Console → your app → **Monetize with Play**. First finish the
**payments profile** (merchant account) if it is not done.

1. **Products → Subscriptions → Create subscription**
   - Product ID: `ekadashi_premium` (exactly; cannot be changed later).
   - Add base plan `monthly`: auto-renewing, billing period 1 month, price
     INR 99. Activate.
   - Add base plan `yearly`: auto-renewing, billing period 1 year, price
     INR 499. Activate.
   - Do not add introductory offers yet (the app hides offers by design).
2. **Products → One-time products → Create**
   - Product ID: `ekadashi_premium_lifetime`, price INR 999. Activate.
3. Use Play's suggested local prices for other countries or restrict
   availability to India.

The app shows whatever price Google Play returns; changing a price in Play
Console needs no app update.

## 2. Test purchases (no real money)

1. Play Console → **Settings → License testing**: add your Gmail test accounts.
2. Upload a release AAB of the production package
   `com.applausestudios.ekadashi_calendar` (new version code) to the
   **Internal testing** track and add the same testers.
3. Install from the internal-testing opt-in link (not a sideloaded APK; the
   `.glasspreview` APK cannot buy) and buy each plan with the test card.
   Test: buy, cancel, restore after reinstall, and subscription expiry
   (test subscriptions renew every few minutes).

## 3. Google sign-in for Calendar import (Google Cloud project `ekadashi-calendar-505210`)

Google Cloud Console → **Google Auth Platform**.

1. **Clients**: open the Android client. Package must be
   `com.applausestudios.ekadashi_calendar`. Add SHA-1 fingerprints for:
   - the **Play app-signing key** (Play Console → Test and release →
     App integrity → App signing), used by every Play install;
   - your upload key / local debug key (`cd android && ./gradlew signingReport`).
   A preview build with another package (`.glasspreview`) needs its own
   Android client, otherwise sign-in fails with `DEVELOPER_ERROR (10)`.
2. **Branding**: app name, support email, logo, application home page,
   privacy policy URL (`https://arun728.github.io/ekadashi-calendar/privacy-policy`),
   terms URL, and the authorized domain. Verify domain ownership in Google
   Search Console.
3. **Data access**: add only `.../auth/calendar.readonly` (a *sensitive*
   scope; no paid security assessment is needed, that is only for
   *restricted* scopes).
4. **Audience → Publish app** (moves from Testing to In production).
5. **Verification Center**: submit for verification with a scope
   justification and an unlisted YouTube video showing sign-in, the consent
   screen and the import. Verification is free and takes days to weeks.

While in **Testing**, only listed test users can sign in and their access
expires after 7 days. Published but unverified, users see an "unverified app"
warning and sensitive-scope sign-ins are capped at 100 users in total.

The Google Calendar API itself is free (default quota is about one million
requests per day); one import uses only a few requests.

## Code map

- `lib/services/premium_service.dart`: entitlement state from Play.
- `lib/services/play_billing_service.dart`: products, checkout, purchase
  stream, acknowledgement and `PlayStoreEntitlements` (owned purchases).
- `lib/screens/premium_screen.dart`: paywall.
- `lib/screens/calendar_screen.dart`: the one free sync (flag `google_free_sync_used`) and premium whole-year sync.
- `lib/services/vrat_tracker_service.dart` and
  `lib/screens/vrat_tracker/record_vrat_dialog.dart`: three free entries.

## Known trade-offs

The one free sync is remembered on the device, so reinstalling the app or
clearing its data gives another free month sync.

Without a server, premium trusts Google Play on the device. A modified APK on
a rooted phone can fake ownership. That is accepted for v2; adding local
purchase-signature checks or server verification is a later option.
