# Play-only premium: validation log

Branch `feature/play-premium-paywall`, based on `feature/panchang-engine`
(`467af26`). Tabs are unchanged: Today, Calendar, Vrat, Panchang, Settings.

## Problems found in PR #11 (and the dev base from PR #9)

1. Calendar "Import from Google" opened the paywall for every free user; the
   paywall's "Sign in securely with Google" called a premium server that is
   not deployed (`PREMIUM_API_URL` unset), so it failed before Google's
   account picker opened. Panchang "Unlock" reached the same dead end.
2. "Activate rewards" failed silently (the server connection failed and the
   handler returned without any message).
3. A sign-in tap during the startup background check was ignored (busy guard).
4. After unlocking premium, Calendar did not resume the import.
5. Google sign-in configuration/network failures were reported as "cancelled".
6. Disconnecting Google Calendar reset premium, tying a Play purchase to a
   Google sign-in.
7. The `.glasspreview` APK uses a different package id, so Google sign-in
   needs its own OAuth Android client (configuration, documented).

## Failing-first evidence

Commit `test: specify Play-only premium...` added/updated tests before any app
change. Running them against the unchanged app failed to compile because the
specified Play-only API did not exist, for example:

```
test/unit/premium_service_test.dart:6:32: Error: Type 'PlayEntitlementSource' not found.
test/support/premium_fixture.dart:16:35: Error: Member not found: 'subscriptionId'.
test/unit/play_billing_test.dart:110:9: Error: No named parameter with the name 'entitlements'.
```

The new widget tests also encode behavior the old app lacked: free current
month import, paywall resume, sign-in failure message, premium surviving
Google disconnect, the three-entry Vrat limit and the paywall without
sign-in/rewards.

## Results after the change (local)

- `flutter analyze --no-fatal-infos --no-fatal-warnings`: no issues.
- `flutter test`: 325 tests passed.
- Android emulator integration (CI): Panchang paywall without sign-in or
  rewards, free current-month Google import and full-year paywall/resume
  (fake Google account), and the fourth-Vrat-entry paywall. See the PR's CI run.

Not covered by automation: real Play checkout (needs Play Console products and
an internal-testing install) and real Google OAuth consent.
