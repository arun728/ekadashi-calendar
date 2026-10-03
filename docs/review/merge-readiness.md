# Local dev merge readiness

**Recommendation:** the PR #4 + PR #6-revert candidate is ready for a reviewed
merge to `dev` for continued v2 testing. This is a test result, not a guarantee
that no unknown defect exists. No push or merge has been performed.

## Candidate composition

- Base: `origin/dev` at `51abe88d0637d50d5d68fcfa2538aa3f2f1146c3`
- First: PR #6 revert (`ccb744c`), which removes PR #5's accidentally merged
  widgets/search changes from `dev`
- Then: PR #4 tracker/achievement change (`62215ef`)
- Then: local regression fixes, Android test harness, test automation, and
  workflow/documentation changes

GitHub currently reports PR #4 as `DIRTY` / `CONFLICTING` against `dev`. The
repository shows PR #5 (widgets/search) merged and PR #6 (Ragul's revert of
PR #5) open and `MERGEABLE`. Applying PR #6's revert first restores the
main-derived source state; PR #4 then applies cleanly in this local candidate.
The conflict tracks the still-present PR #5 changes. PR #6 itself is not the
feature change that was accidentally merged.

## Fixes verified

- Closing the tracker record sheet before displaying its achievement avoids
  the modal race that left the sheet visible after saving.
- Disabled tracking blocks new, edited, or deleted records and achievement
  progress changes. Future dates cannot be recorded.
- History/statistics choose a valid year when the current year has no records.
- Achievement messages follow the selected language.
- Reminder opt-out survives language changes and prevents new Android
  schedules in both Flutter and native scheduling paths.
- The Android Gradle wrapper is checked in for clean-checkout reproducibility.

## Verification

- Flutter unit/widget/acceptance/regression: **95 passed, 0 failed**.
- Dart line coverage: **70.65% (1,945 / 2,753 instrumented lines)**.
- Flutter analyzer: **no issues found**.
- Android native Robolectric: **13 passed, 0 failed**.
- Android API 24 integration: tracker flow and Home/Calendar/Settings/locales
  both passed; screenshot evidence is under `build/ui-screenshots/android/`.
- Debug APK build and `git diff --check`: passed.

Full details and rerun commands: [TESTING.md](../TESTING.md).

## Still required outside this local merge gate

The GitHub CI API 33/35 matrix has not run. Samsung M52 and Z Flip 5 testing is
still needed for OEM background behavior, real geocoding/location, and device
layout. These are needed before release sign-off; they are not simulated by the
API 24 integration pass. The `feature/2027-telugu` integration remains
separate and was not modified.

The tested local candidate is ready to serve as the source for resolving PR #4
and integrating the pair in order (#6, then #4). The existing GitHub PR #4 is
not mergeable as-is until that resolution is applied to its branch or replaced
with this reviewed candidate. Arun's branch policy remains in force: explicit
permission is required before updating remote `dev`, and `main` requires
separate later approval.
