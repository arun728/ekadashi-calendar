# Ekadashi premium and fasting rewards — implementation contract

Research date: 4 October 2026. Implementation must start on a separate branch
from the validated glass UI dev merge. No paid/reward work may merge to dev
before Arun finalizes and tests it and explicitly authorizes integration.

## Confirmed product scope

- Free: Ekadashi archive, dates/details/translations, reminders, calendar year
  selection, custom entries, search, all Vrat recording/history/streaks/statistics,
  and the first three earned achievement unlocks (not necessarily catalog order). Vrat is always available; remove enable/disable
  and the opt-in page. Preserve records, tracking start dates and earned badges.
- Paid: Google Calendar sync and additional achievements after the first three.
  Expiry must not delete imported events or personal history.
- Prices intended for India: monthly INR99, annual INR399, lifetime INR999.
  Monthly/annual are auto-renewing subscription base plans; lifetime is a
  non-consumable one-time product. Display authoritative localized Play prices,
  billing period/renewal terms and cancellation/restore actions.
- Keep all three current widgets free. Paid widget customization/extra layouts
  is an optional later idea, not a silent removal of existing functionality.

## Google APIs and platform choice

Google's current Billing Library is 9 (19 May 2026). Billing 8 remains valid for
new apps/updates through 31 August 2027; 9 through 31 August 2028. The current
Flutter 3.38.5/Dart3.10 project can use official in_app_purchase 3.3.1 plus
in_app_purchase_android 0.5.0 (Billing 8.0.0). Later Android plugin versions
require Flutter3.44/Dart3.12. Avoid an unrelated framework upgrade; pin the
compatible version, verify resolved native dependencies and record its deadline.
A later isolated SDK/Billing9 upgrade should precede that deadline.

Use Google's native checkout. Support pending/canceled/error/restored states;
never unlock pending or unverified purchases. Backend verification must check
package/product/base plan, account binding, purchase state, acknowledgement,
expiry and revocations. Tokens are unique, idempotent and never logged.
Acknowledge promptly after verified entitlement (three-day maximum, including
server retries). RTDN/webhook notifications trigger fresh Publisher API reads;
notification payloads alone never grant premium. Grace retains access; hold,
pause/expired/revoked states remove paid access. Canceling auto-renew retains
access until the verified expiry. Lifetime restores and is never consumed.

Use Google sign-in identity for durable account-bound rewards and restoration,
with audience/issuer/expiry verified on the backend and an obfuscated app-account
ID in Play checkout. Calendar OAuth is a separate additional permission.
No service-account secret belongs in the APK. Production purchase/coin state is
server authority, not a SharedPreferences toggle. Configuration absence fails
closed for purchasing, while free functionality remains available.

## Non-cash coins and premium credit

This is a self-reported fasting reward, not verification of religious practice.
No cash refunds, withdrawals, transferable currency or paid coin packs.

Proposed simple rule: one fully observed, past Ekadashi earns 10 coins; partial,
missed and future entries earn none. A complete year earns a completion bonus
bringing that year's total to 300 coins. Thus today's 24-occurrence packs yield
240+60; a 26-occurrence year yields 260+40. Determine eligible occurrences from
the trusted year's catalog, not a hard-coded count or device-supplied amount.

300 coins can redeem six bonus months of premium. For an active monthly or annual Play
subscription, use purchases.subscriptionsv2.defer with the latest receipt etag
and a server-calculated duration; Google moves the renewal date and emits
SUBSCRIPTION_DEFERRED. Do not change local expiry without that confirmed change.
For users without a renewable subscription, a server-issued promotional
entitlement can grant earned access. Lifetime purchasers do not need duplicate
premium time. Show exact eligibility/value before redemption.

Each account/occurrence has a unique reward record across locales, timezones,
devices and years. Status edits, deletion, migration and retry must not mint
extra coins. Maintain an append-only ledger and reconcile corrected observances;
spent credit cannot be spent again. Credit availability can remain zero until
corrected/reversed awards are balanced; it is never money owed by the user.
Coins and progress persist across years. Entitlement expiry leaves these intact.

Redemption uses an idempotency key, transactional reservation and exactly-once
settlement. Network ambiguity after Google deferral remains pending and is
reconciled against authoritative expiry/etag; retries must not defer twice or
spend twice. Refunded/revoked purchases never keep paid purchase entitlements.
Use durable PostgreSQL transactions/constraints in production; SQLite is only
for local deterministic tests. Use server time/catalog for reward eligibility.

Six months of annual access has an indicative value INR199.50, not a cash refund.
INR399 minus INR199.50 leaves INR199.50 before platform fees, taxes and costs.
An annual subscriber extended to 18 months has gross annualized revenue INR266;
it does not guarantee INR200 profit. India auto-renewing subscriptions currently
have a 15% Play fee. Lifetime fee depends on program/revenue eligibility.
Google's new regional fee rollouts differ by geography/install date; don't
assume India's terms apply worldwide or enable external billing by default.

## Test plan (TDD)

- Free/premium feature matrix, first-three limits, grandfathered earned badges,
  permanently available Vrat, loss of premium without loss of history/data.
- Product/base-plan selection, real-price formatting, availability, pending,
  cancellation/errors, restore, acknowledgement retry and verification failure.
- Backend receipt fixtures for active/grace/canceled/hold/paused/expired/refunded,
  mismatched account/package/product, replay and out-of-order RTDN.
- Real DB ledger persistence, concurrent duplicate claims, future dates,
  locale/location variants, 24/26-occurrence years, partial/deleted/edited records,
  full-year bonus reversal, cross-year carryover and redemption atomicity.
- Etag mismatch, provider timeout before/after deferral, idempotent retry,
  missing credentials, failed acknowledgement and refund reconciliation.
- Paywall/rewards/locked-achievement UI in en/ta/hi/te, both themes, 320dp/2x,
  native checkout errors and preserved five-tab/navigation/Google/custom flows.
- Automated Android emulators; separately real Play internal-track license
  testers for monthly/yearly/lifetime, accelerated renewals, cancellation,
  grace/hold, restoration and server notifications. Do not claim emulator fakes
  prove real Play transactions or production deployment.

Required release setup: Play Console products/base plans and license testers;
backend identity audience/HTTPS endpoint, durable DB, Publisher service identity
and Pub/Sub RTDN. No paid backend is deployed or real customer purchase charged
merely by developing this isolated branch.

## Later daily-use monetization ideas (not this implementation)

- Ekadashi: family profiles, cloud backup/export, additional widget themes,
  configurable devotional routines and professionally recorded katha/audio.
- Panchang: daily location-specific sunrise/sunset/tithi/nakshatra, festival
  planning, advanced reminders and printable calendars. Date accuracy/local
  tradition requires a separately validated engine/content source.
- Chanting: keep a basic counter/streak free; premium guided audio, saved mala
  routines, offline audio collections, progress insights and synced profiles.

Prefer one clear premium bundle to many paywalls. Keep essential dates, records,
reminders and basic devotional tools useful for everyone. Expand paid features
only after content/licensing, accuracy and development effort are evaluated.

## Official sources

- https://developer.android.com/google/play/billing/release-notes
- https://developer.android.com/google/play/billing/deprecation-faq
- https://developer.android.com/google/play/billing/integrate
- https://developer.android.com/google/play/billing/security
- https://developer.android.com/google/play/billing/subscriptions
- https://developer.android.com/google/play/billing/one-time-products
- https://developer.android.com/google/play/billing/lifecycle/subscriptions
- https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2/defer
- https://developer.android.com/google/play/billing/test
- https://support.google.com/googleplay/android-developer/answer/112622
- https://pub.dev/packages/in_app_purchase
- https://pub.dev/packages/in_app_purchase_android

## Policy disclosures (official policy pages checked 4 October 2026)

Google subscriptions policy requires sustained/recurring value, transparent
localized billing periods/auto-renewal/full charged price, an obvious dismiss
action, and an in-app cancellation/manage link. Calendar sync supplies ongoing
service; extra achievements are a complementary benefit, not the sole basis
for a renewable charge. Lifetime is a non-consumable one-time purchase.

Earned-access rewards require no purchase to earn, contain no wager/chance,
no coin sales or transferable/cash/physical prizes, and use public fixed rules.
Publish the exact earning/redemption schedule in the app and public terms.
Google's gamified-loyalty policy has additional constraints for rewards tied to
monetary transactions; this proposal deliberately does not make fasting rewards
a paid-entry loyalty promotion or a cash refund. Final Store listing and
program terms still need review before release; code cannot guarantee approval.

First-three achievement gating counts earned unlocks, so a streak achievement
may be one of the free three even if it is later in catalog order. Preserve
already-earned achievements even when more than three were earned before the
upgrade; never claw them back on downgrade. Continue progress calculation free.

- https://support.google.com/googleplay/android-developer/answer/9858738
- https://support.google.com/googleplay/android-developer/answer/9900533
- https://support.google.com/googleplay/android-developer/answer/9877032

## Account privacy and deletion

Vrat remains local/private by default. Wallet activation explicitly signs in and
consents to sending stable occurrence UID, observed status, calendar variant and mutation
identity, not notes/method/tradition/location text. Account deletion must be
available in-app and on a public web resource; deleting cloud rewards must not
silently erase local private Vrat history. Explain that deleting an account does
not itself cancel a Play subscription and expose Play management before deletion.

Remove associated cloud observance data. Minimize any receipt/anti-replay records
retained for legitimate fraud, security or accounting needs; document purpose
and a bounded retention schedule in the actual published privacy policy. Release
requires hosted privacy/reward terms and a working external deletion request
page plus accurate Play Data safety declarations, rather than placeholder links.

- https://support.google.com/googleplay/android-developer/answer/13327111

## Operational preparation

The local Docker engine is available. A PostgreSQL17 image has been downloaded
for real transactional/concurrency tests; no backend server has been deployed
and no cloud service or customer billing has been activated.

Compatible plugin archive inspected directly: in_app_purchase_android0.5.0
Android build uses Kotlin2.3.20, AGP8.13.1 and Billing8.0.0. The app currently
uses Kotlin2.2.20/AGP8.11.1 with Gradle8.14. Align these native build versions
on the isolated paid branch and verify compilation/native regressions; this is
not part of the UI merge. Flutter3.38/Dart3.10 compatibility is confirmed by
the package's published pubspec, rather than a guess from its version number.
