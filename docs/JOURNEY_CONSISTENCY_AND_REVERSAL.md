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
- Once-presented celebration markers remain once-only; requalifying a previously
  presented badge does not repeatedly celebrate farming the same records.

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
