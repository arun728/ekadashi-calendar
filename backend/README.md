# Premium verification and reward ledger

Prototype on `feature/subscriptions-rewards`, not deployed or activated. Run
PostgreSQL 17, Python 3.12 and install `requirements.txt`. Keep this API behind
HTTPS, request limits and per-account/IP rate limiting; restrict database access,
use secret-manager credentials, monitor retry failures and back up the ledger.

Set the variables in `.env.example` through server secrets. `ACCOUNT_HMAC_KEY`
is at least 32 random bytes; `RECEIPT_ENCRYPTION_KEY` is a Fernet key. Do not
rotate either without a migration: purchase account binding depends on the HMAC,
and encrypted receipts require the old key. Use workload identity / ADC for a
service account with the minimum required Android Publisher app permissions.
No Play credential belongs in the app or repository.

From `backend`, run `python -m ekadashi_billing.migrate` once to create the initial
schema, then `uvicorn ekadashi_billing.api:production_app --factory`. Subsequent
schema changes require a reviewed migration; table creation is not an upgrade
migration mechanism. Build the Docker image from the repository root with
`docker build -f backend/Dockerfile .`; run migration separately before serving.
Run `python -m ekadashi_billing.worker` every few minutes for durable purchase
acknowledgement and ambiguous-network deferral recovery. Alert well before the
three-day Play acknowledgement limit. `needs_review` redemptions reserve coins
for support; never manually extend them without checking Play expiry/etag.

Configure Pub/Sub authenticated push at `/v1/play/rtdn`, the exact audience and
service account email, retry/dead-letter handling and Android Publisher RTDN for
the production package. Notifications only trigger fresh Play API verification.
The API does not accept a client-selected account, entitlement flag or price.
All user routes require a Google ID token for the configured web client audience.

Rewards are private/off by default. Only occurrence UID, observed status, selected calendar region and sync metadata
leave the device after consent. Coins are transactional, account-bound and
non-cash: 10 per completed past occurrence, full-year bonus to 300 (24→240+60;
26→260+40), 300→six calendar months. Corrections reverse earnings. Previously
spent credits do not create a monetary debt. Stable mutation keys and expected
versions prevent retries/new/stale devices multiplying or overwriting rewards.

For active renewing subscriptions, credit defers billing via subscription V2
etag + duration. A lost response reserves credit until provider confirmation;
there is no blind second extension. Users without a renewing subscription get a
server promotional entitlement. Paused/on-hold purchases need management first.
Lifetime already grants permanent access, so redemption is unavailable.

Account deletion immediately removes cloud observances, ledger, bonus records
and promotions and erases encrypted receipt tokens. A pseudonymous deleted-account
marker and receipt hash binding are retained for **180 days** for anti-replay and
fraud prevention, then purged by the worker. Local private Vrat is retained. Account
deletion does not cancel Google Play billing; show management before confirmation.
Publish this purpose/retention and a working external account-deletion request
page before release. Hosted privacy/reward terms and accurate Data safety forms
are required; placeholder URLs are not release-ready.

Tests from repo root: `python -m pytest backend/tests -q`. CI supplies PostgreSQL.
SQLite is only a fast local fallback; its concurrency test intentionally skips.
Test mode uses injected identities/publisher fixtures. There is no production
"test paid" API and no secret or local paid flag bypass.

Before release, exercise a Play internal track with license testers: each base
plan/lifetime, cancel/pending/restore, renewal/grace/hold/refund/revoke, account
switching, RTDN, acknowledgement retry and full bonus redemption. Fake emulator
screens prove layout and app gates, not actual purchases or Google approval.

A verified Play purchase can be restored after deleting the cloud rewards account;
it never recreates old reward/history data or removes the anti-replay block.
Cloud rewards re-enrollment waits for the bounded 180-day deletion marker purge.
Newly restored, necessary billing receipts remain valid after that purge.
