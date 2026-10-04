# Paid branch setup and release gates

The glass UI was merged in PR8 to dev `78f1ee3332b4c3d002b5b01ef47b096f4fa7b24c`.
Paid/rewards changes stay on `feature/subscriptions-rewards`. Do not merge them
to dev or main until Arun reviews/finalizes, tests and gives fresh permission.

## Product configuration

In Play Console, create subscription `ekadashi_premium` with auto-renewing base
plans `monthly` (India INR99/month) and `yearly` (India INR399/year), plus active
non-consumable product `ekadashi_premium_lifetime` (India INR999). Set country
availability and localized descriptions. The app displays prices returned by
Play, not hard-coded charge amounts. No introductory offers are selected until
complete intro/renewal disclosures are implemented. Existing renewing customers
manage/change plans in Play; new checkout is blocked while verified premium is
active, including canceled subscriptions and earned access credit. Lifetime is
not consumed and never auto-renews.

## What Arun needs to provide for real checkout

An Android developer account allows app publishing. It does not automatically
create products, activate a merchant payments profile, host a verification API,
or give that API access to purchase records. The production app package remains
`com.applausestudios.ekadashi_calendar`; the separate `.glasspreview` APK cannot
validate purchases for the production app's products.

1. In this app's Play Console **Monetize with Play** area, finish the payments
   profile and activate the product IDs/base plans listed above. Confirm INR
   pricing, tax display and enabled countries; send the non-secret IDs/statuses
   or screenshots. Do not create three subscription IDs: monthly/yearly are
   two base plans of `ekadashi_premium`; lifetime is a separate one-time product.
2. Identify the existing Google Cloud/Firebase project, or create one. This
   backend needs HTTPS compute, persistent PostgreSQL, Secret Manager, Pub/Sub,
   and a scheduled worker. Firebase alone does not replace the PostgreSQL ledger.
   Hosting/database charges are separate from Play transaction fees; choose
   the budget and region before deploying production resources.
3. Enable Android Publisher API and grant a backend service account the
   necessary app-scoped order/subscription permissions in Play Console. Use
   workload identity/managed credentials. Never paste service-account private
   keys, passwords or Play tokens into chat or commit them to the app.
4. Provide the public OAuth **web client ID** for ID-token sign-in. Confirm the
   Android OAuth client uses the production package and the **Play app-signing**
   certificate fingerprints, not only the upload/debug certificate. The existing
   Calendar OAuth project can be reused if its configuration matches.
5. Provide HTTPS privacy, premium/reward terms and account-deletion page URLs,
   support contact, and accurate Play Data safety declarations. Connect the
   external deletion request page to a working authenticated/support flow.
6. Add tester Google accounts under **license testing** and to an **internal
   testing** track, upload a release-signed production-package AAB with a new
   version code, and share its opt-in link. Install from Play with the tester
   account and select Google's test payment instruments; do not use real cards
   for this QA. Track access alone does not make purchases free.

After configuration, build with the public defines below and deploy the server
with managed secrets. Test real monthly/yearly/lifetime checkout, pending/cancel,
acknowledgement, restore/reinstall/account switch, renewal/grace/hold, refund/revoke,
RTDN and retries on the internal track. Use Play Billing Lab/license-test tools
for subscription lifecycle cases where supported. Validate the six-calendar-month
reward deferral against the Publisher API separately; accelerated test renewals
do not prove production calendar timing. Run the same release-signed flows on
Samsung M52 and Z Flip5, including retaining local Vrat history across an upgrade.
Only then finalize this draft branch and request integration/release approval.

Build with HTTPS `PREMIUM_API_URL`, OAuth `GOOGLE_WEB_CLIENT_ID`, and hosted
`PREMIUM_PRIVACY_URL`, `PREMIUM_TERMS_URL`, `PREMIUM_DELETION_URL` dart-defines.
Purchasing fails closed without these settings; free features still work. The
web OAuth client audience must match the server; configure Android package,
Play signing certificate SHA fingerprints and the web client for ID tokens.
Calendar requests its read-only scope additionally; Google sign-in is shared.

Deploy the verification backend as described in `backend/README.md`; configure
Publisher permission, authenticated Pub/Sub push, persistent PostgreSQL, scheduled
acknowledgement/redemption recovery, encryption/HMAC keys, HTTPS/rate limiting,
monitoring/backups and bounded deletion retention. Nothing has been deployed or
activated by this branch. No production secret is in the app or repository.

## Behavior implemented

All private Vrat records/history/streaks/statistics remain free and available,
including users with the old disabled flag. Three earned badges are free;
additional badges require verified premium. Existing earned badges and records
survive downgrade and upgrade. Google sync alone is gated; disconnect, cached
imports, custom entries, years/search/reminders and existing widgets remain free.

Reward activation separately consents to UID/status/calendar-region and sync-metadata upload, with no private notes,
method or tradition. A durable per-account outbox uses stable mutation keys and
last-owned server versions. Missing records on another device cannot erase cloud
history, and stale corrections do not overwrite newer edits. Conflicting/future
legacy claims stop with a visible retry/support message; no coins are guessed.

Each completed past Ekadashi earns 10 coins: normally 24→240. A full-year bonus
adds 60 for a 24-event catalog or 40 for 26, bringing full-year earnings to 300.
300 coins redeem six calendar months of non-cash premium credit. No purchase is
required to earn. No coin packs, cash refund/transfer, chance or paid-entry game.
Active renewals are deferred through Play V2 etag/duration; provider ambiguity
reserves coins for reconciliation/support, never a blind second extension.

Account deletion removes cloud reward/history data while preserving local Vrat.
It does not cancel Play billing. Pseudonymous receipt hashes/deleted-account
markers have documented 180-day anti-replay retention; the worker then purges them.
Provide public account deletion, privacy/reward rules and accurate Play Data
safety before release. Official policy research is in `PREMIUM_REWARDS_PLAN.md`.

## Test interpretation

Dart tests exercise verified short leases, pending/error/cancel/restore, safe
acknowledgement, no local paid flag, receipt retries, reward queues/corrections,
free migration and first-three earned unlocks. PostgreSQL tests exercise real
account locking/concurrency and durable ledgers with injected Publisher receipts.
Android CI preserves API24/33/35, permission/GPS modes, native widget/WorkManager
regressions and adds actual premium UI captures. `premium_fixture_*` captures use
explicit test-only Play prices: they prove native layout/navigation, not checkout.
Offscreen PNGs similarly use fixture prices and desktop native-channel mocks.

Real payments require Play internal testing/license testers and the deployed
server. Validate every plan, pending/cancel, restore/reinstall/new device, grace,
hold, renewal, refund/revoke, account mismatch, RTDN and recovery/credit deferral.
Samsung M52/Z Flip5 OEM background reliability, real OAuth, native-speaker review
and release-signed upgrade preservation remain release checks. No code/test suite
can guarantee no bugs or Play approval; these gates must precede monetized release.

## Suggested later premium value

Keep the current three widgets free. Consider premium themes/custom layouts,
family fasting profiles, encrypted opt-in multi-device backup, devotional/offline
audio with licensed content, chanting routines/history/insights and advanced
Panchang planning once its source/calculation accuracy is validated. Essential
Ekadashi dates, reminders, fasting records and a basic chanting counter stay free.
Build one useful premium bundle, not a paywall for every basic interaction.
Recurring calendar service supplies ongoing value; achievements complement it.

A verified Play purchase can be restored after deleting the cloud rewards account;
it never recreates old reward/history data or removes the anti-replay block.
Cloud rewards re-enrollment waits for the bounded 180-day deletion marker purge.
Newly restored, necessary billing receipts remain valid after that purge.
