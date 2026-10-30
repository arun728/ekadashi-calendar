# Consistency streaks and reversible badges

Approved 30 October 2026 for PR32, superseding permanent badge retention and the
previous latest-eligible-date current-streak policy.

## Rules

- Current consistency streak ends at the latest recorded, eligible occurrence.
  Fully observed and partial each extend it by one. Missed entries and unrecorded
  gaps between recorded occurrences break it. Later unrecorded dates and future
  occurrences do not hide recorded progress. The longest consistency streak uses
  the same rule and can cross calendar years.
- Full-observance streak badges retain their fully-observed-only requirements;
  milestones, quarters and annual badges retain their original strict conditions.
  Partial remains 50 points; fully observed remains 100. Annual completion counts
  only full observances and is explicitly labelled as such in all six languages.
- Badge state is derived from current history. Edits and deletions recalculate
  the original eligibility predicate and relock badges that no longer qualify.
  Their earned date clears. Unaffected badges remain earned. Corrected state is
  persisted and survives relaunch; no deletion of unrelated records or purchases.
- Existing premium entitlement and three-free-entry/three-free-badge rules remain.
  Expiring premium does not revoke a still-qualified earned badge. A zero new-
  unlock allowance must never be bypassed when other badges are revoked.
- Celebration markers clear when a badge relocks. Earning it again celebrates
  again; repeated saves while it remains earned do not. The migrated badge
  envelope is authoritative over stale legacy presentation markers.

## Reproduction

The user's iOS screenshot records the first three 2026 occurrences and leaves
later eligible dates empty. The old shared rewards calculation reset current
streak at each later gap, giving current zero and longest three. The new rule
shows current three and longest three. An internal missing second record still
breaks the run: first and third recorded gives current one. Three mixed observed/
partial entries give consistency three while strict full-streak badges remain
locked. Both platforms must use identical history, Home schedule and clock in
parity tests; the wife's installed Android version/history is not assumed.

## Test evidence

Swift red runs: `/tmp/journey-consistency-red.log` demonstrates current 0 vs3,
longest1 vs3 for mixed history and badges staying unlocked after removal.
The iOS three-record UI red run reaches the Overview but fails the explicit
consistency label. Green runs and final cross-platform/device evidence follow.


## iOS-first validation

- Both new core behaviors failed before implementation (`e3e929c`).
- Native three-record UI label failed before updating the shared translations
  (`a7eac2c`). Narrow card title wrapping and zero-allowance safeguards also
  demonstrated failures before their fixes (`fc8e8fe`).
- All 330 Swift core tests pass, including mixed-status consistency, internal
  gaps/misses, strict full-streak badge eligibility, selective badge reversal,
  deleting/reloading durable history and explicit zero new-unlock allowance.
- All six native Journey flows passed on iPhone 17 Pro/iOS 26.5. Broader native
  app/widget suite: 56 passed, one pre-existing StoreKit catalog runner skip.
- A supplementary simulator deletion/relocked-badge UI flow and Android parity
  validation are recorded below when complete. The signed iPhone build succeeded;
  it is staged for installation after cross-platform validation.


## Final cross-platform validation

- iOS simulator UI: three observed entries show current consistency three;
  deleting the middle entry shows one, and the full-observance three-fast badge
  is Locked. Screenshots exported from `/tmp/journey-consistency-delete-ui.xcresult`.
- Android red run reproduced old streak, sticky-badge and title-truncation issues
  (`8fea6d4`). All 43 focused parity tests passed after porting.
- Full Flutter suite: **941 passed**; analyzer clean; generated-file check and
  formatting clean. Swift core: **330 passed**; focused final Journey rerun:
  **26 passed**. Unique native checks: **62 passed**, one known StoreKit catalog
  command-line runner skip. Kotlin/widget tests: **89 passed**, 11 suites.
- Full Android emulator flow passed in both Glass settings and six languages,
  including mixed/full consistency three, deletion to one, badge relocking and
  persisted reload state. Five new flow screenshots join the previous screen set.
- Regular Android release build succeeds after refreshing generated Flutter
  plugin metadata left by the integration runner; no build-script workaround or
  application/signing configuration change was needed. Its release certificate
  matches the installed Samsung M52. iPhone company-signed device build succeeds.
- Screenshot evidence: `/Users/kumarm/Documents/Codex/journey-consistency-evidence`.
  Physical-device updates are performed in place, never by uninstalling/resetting.
- No dev/main changes, merges or CI runs. All work remains on PR32.


## Re-earned celebration correction

A badge relocked on deletion, but its presented/queued IDs survived. Re-earning
therefore produced no celebration. Both trackers now intersect those marker sets
with the currently earned badge IDs after evaluation. An earned badge retains
its markers; a relocked badge loses them. Re-earning celebrates once again.
A valid migrated envelope replaces legacy presentation IDs instead of unioning
stale IDs back into it. Presentation markers remain durable across relaunches.

Test-first evidence: native core and actual simulator flow failed before the fix
(`95ff53d`); Android storage test also failed before the port (`1fbfd0a`). The
existing lifetime-only test was updated to the new once-per-earned-period rule.
Tests cover presented and queued awards, deletion, reload, legacy migration,
pending awards surviving restart and duplicate suppression on repeated saves.


Re-earned-celebration validation: **331 Swift core tests passed**, **942 Flutter
tests passed**, analyzer and formatting clean. Native presentation tests plus the
actual iOS delete/re-add UI flow passed. Android full emulator flow passed with
`badge_reearned_after_delete_all`, including both Glass settings and six languages.
The first Android UI attempt needed a test-only scroll-to-top after deleting the
last entries; the corrected flow passed. No scoring or entitlement changes.
