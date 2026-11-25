# PR #44 billing: device test report (24–25 Nov 2026)

Tested on real devices: **Samsung M52** (Google Play license tester, test card)
and **iPhone 16 Plus, iOS 27.2.1** (App Store sandbox). PR head at the end of
testing: `ded1a97`. Every commit carries `[skip ci]`; nothing was merged.

## 1. Results at a glance

| Flow | Android (M52) | iOS (iPhone) |
|---|---|---|
| Plans page loads live store prices | ✅ ₹99.00 / ₹599.00 / ₹1,999.00 | ✅ ₹99 / ₹599 / ₹1,999 |
| Buy Monthly | ✅ | ✅ |
| Monthly → Yearly (charged now) | ✅ unused time added | ✅ Apple refunds unused Monthly |
| Yearly → Monthly at renewal, shown as "Upcoming plan" | ✅ | ✅ |
| Scheduled switch still shown after an app restart | ❌ forgotten | ✅ |
| The switch happens at renewal and Premium stays on | ✅ 00:29 | ✅ 12:03 |
| Cancel in the store's Manage page → app shows "Subscription cancelled" | ❌ never shown | ✅ |
| Reactivate | ❌ no button (see above) | ✅ opens Apple's sheet → Renew |
| Expiry removes Premium | ✅ | ✅ (overnight) |
| Restore purchases | ✅ | ✅ |
| Manage opens the store's page for this subscription | ✅ | ✅ |
| Lifetime while subscribed: warning first | ✅ (backed out, not bought) | ✅ (backed out, not bought) |
| Purchase acknowledged/finished | ✅ still owned after 5 min | ✅ |
| Free limits: 4th Vrat entry asks for Premium; Panchang locked | ✅ | ✅ (Codex's tests) |
| No dates anywhere in billing copy (new) | ✅ | ✅ |

Automated checks at `ded1a97`: Flutter 989/989, `flutter analyze` clean,
`dart format` and `tool/check-generated.sh` clean, `swift test` 359/359.
iOS app tests (simulator): all pass except two of Codex's StoreKit
simulator tests (see issue 4).

## 2. Changes made today (approved by Arun)

**PR #44** (`claude/billing-store-fixes`), iOS first, then Android, tests first:

| Commit | What |
|---|---|
| `15df0ce` | Failing tests: approved copy fixture `test/fixtures/billing_copy.json`, read by both apps |
| `16812c6` | iOS + shared strings: no dates in billing copy; App Store wording on iOS; "cancelled"; three free Vrat entries; regenerated a stale `strings.json` |
| `eb5e178` / `40a3fb1` | Android: Settings card shows the scheduled Monthly switch like iOS |
| `c3450f9` / `30f772c` / `ded1a97` | Achievements tab: "Your first three Vrat entries are free…" removed on both apps and from all six languages |

**PR #48** (`claude/privacy-email-declaration`), deployed to apptinel.com and
checked live: `1df0df4`. The Ekadashi page and Terms no longer mention "three
achievements": "three new Vrat entries" are free, and Premium means "unlimited
Journey recording". Terms "Updated" date: November 25, 2026.

Why no dates: on the iPhone, Apple's sheet said "Starting on 24 November" and
"your service will end on 24 November" (US time) while the app said "Wed, 25
Nov 2026" (IST). Both apps now send users to Google Play / the App Store for
dates.

## 3. Open issues (fixes need Arun's OK; they go into PR #44)

1. **Android never shows "Subscription cancelled", and has no Reactivate button.**
   `play_billing_service.dart:138-142` ignores `isAutoRenewing = false` for the
   new products on purpose. During a scheduled switch, Play reports the old
   Yearly as "not renewing" too.
   - Knock-on: after a cancelled plan ends, Premium-synced Google events stay
     for the 57-day account-hold window instead of being removed straight away.
   - Fix idea: while no switch is pending, treat "not renewing" as cancelled.
2. **Android forgets the scheduled Monthly switch after an app restart.** The
   token is kept in memory only. Play still makes the switch; only the
   "Upcoming plan" label is lost. Fix: store it with the purchase token, as the
   current plan is stored.
3. **The 3-achievement limit for free users is still in the code** on both
   apps (`VratTracker.swift:211`, `vrat_tracker_service.dart:410`), plus the
   "Ekadashi Premium" tag on locked badge cards. Arun to decide: keep it (it
   matches "Unlock Achievements with Premium") or remove it.
4. **iOS simulator store tests:** `testStoreKitSwitchesToMonthlyAtTheYearlyRenewal`
   fails in Xcode's test store, but the real switch passed on the iPhone.
   `testIdleSubscriberDoesNotKeepRefreshing` is flaky and slow (passes alone in
   about 250 s). Suggest fixing or skipping these on the simulator so CI stays
   green.
5. **Android has no "fix your payment" message after a failed renewal.** iOS
   has one. Suggest Play's in-app messaging API.
6. **The old combined `ekadashi_premium` subscription is still active in Play
   Console.** Deactivate it before release; current owners keep access.
7. **Paywall polish:**
   - When a switch is scheduled, the main button and the link below it both
     say "Manage subscription".
   - The Manage link is shown to free users.
   - Big empty gap above the button.
   - Android prices show "₹99.00", iOS shows "₹99".
8. **The 4th Vrat entry hits the paywall only after the whole form is filled in.**
   Lock before the form opens.
9. **Terms and Privacy open in external Chrome on Android.** Use an in-app
   browser tab (Custom Tabs / SFSafariViewController).
10. **Play Console subscription benefits** say "Unlimited Vrat entries and
    achievements". Align them with the app wording in Play Console.

## 4. Platform consistency

- All billing wording now comes from one fixture. Both apps match in all six
  languages; only the store name differs.
- Remaining behaviour gaps: issues 1, 2 and 5 (Android only).
- Store-specific by design:
  - the upgrade note (Apple refunds unused time; Google adds it);
  - "battery" (Android) vs "background refresh" (iOS);
  - Play Store vs App Store links.

## 5. Settings, Premium and legal: recommended layout (same on both apps)

1. **Premium card:** your plan and its status (renewing, cancelled or
   switching, with no date), then **Manage** and **Change plan**.
2. **Notifications** (one row opening its own page):
   - on/off and Test notification;
   - Ekadashi reminders;
   - festival and event reminders;
   - "Reminders not arriving?" with app settings, battery or background
     refresh, and the permissions guide.
3. **Appearance:** dark mode, Glass Look, widget preview, and **Vibration on
   achievements** (moved here from the "Journey" section at the bottom).
   Android does vibrate: `HapticFeedback.mediumImpact` on badge unlock.
4. **Google Calendar:** connected account, Import, Disconnect. Today these are
   only in the Calendar tab's menu.
5. **Purchases:** Restore purchases, Manage subscription.
6. **About and legal:** Rate, Share, **Terms of service**, **Privacy policy**,
   Contact support, Version.

Keep Terms and Privacy on the paywall as well. Apple requires them where
subscriptions are sold, and Google expects the privacy policy to be reachable
in the app.

**Paywall:** status at the top, one main button, Restore + Terms + Privacy on
one small line, no Manage link for free users.

## 6. Not tested, and why

- **Buying Lifetime:** both test accounts would own it for good, which blocks
  later subscription tests. Only the warning was tested.
- **Restore after uninstalling:** this would wipe app data on the personal
  phones. Restore and relaunch were tested instead.
- **A declined payment, grace period and account hold on a real device.** iOS
  was covered in the simulator.
- **Premium Google Calendar import:** it needs Arun's tap on Google's account
  chooser.

## 7. Device state left behind

- **M52:** debug build of `ded1a97`. Its test account currently owns a test
  Yearly; it wasn't bought by me.
- **iPhone:** a debug build of `ded1a97` via UI tests, with an active sandbox
  Monthly.
- **Emulator:** stopped.
- **Scratch test harness:** never committed; kept only in the session
  scratchpad.

## 8. Arun's decisions (25 Nov 2026)

- Issue 3: keep the 3-achievement limit and the "Ekadashi Premium" tag as they are.
- Issue 4: devices are the source of truth for billing; the two simulator store
  tests are skipped on the simulator.
- Fix in PR #44: issues 1 and 2 (Android cancel/Reactivate, as on iOS; scheduled
  switch kept after a restart); Android prices without zero decimals (₹99);
  smaller gap and more room at the bottom of the plans page; "Manage
  subscription" without a store name in every language; "Manage subscription"
  shown to every user including Lifetime; clearer Manage button on the Settings
  card; Google Calendar event reminders become Premium (free users: only events
  from their free sync month; custom entries always free).
- The plans page main button stays as it is (the tile already says "Current
  plan" or "Upcoming plan").
- Settings redesign (section 5, without a Purchases section; Restore and Manage
  stay on the plans page; Contact support at contact@apptinel.com; Google
  Calendar section) goes in a new PR stacked on #44, after a separate GO.
- Play Console (old `ekadashi_premium`, benefits text) is in the release
  checklist; who does it is decided later. Website wording for Premium Google
  reminders is checked later.
- After the fixes: full end-to-end subscription re-test, behaviour and strings,
  on the M52 and the iPhone.
