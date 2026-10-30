# Journey regression audit — 30 October 2026

## References and scope

Compared PR25 `feature/premium-journey` at `7b5d146` with PR32
`feature/journey-dev-refresh` at `c63fddd` before the fixes in this audit.
Inspected both platforms, all four Journey subtabs, recording, share,
badge evaluation, storage and model integration. No changes to dev or PR25.

## Findings

| Area | Comparison and result |
| --- | --- |
| Overview | Native VratView and Flutter tracker/overview were identical to PR25. Points, mandala, selected years and strict current streak retained. |
| History | Same timeline, filters, stable identities, recording and status rules. Android deliberately retains dev's existing-record editing exception; it does not change scoring. |
| Statistics | Same selected-year counts and annual full-observation completion; current and longest streaks use the same summary as Overview. |
| Achievements | Same catalog, progress, earned-state persistence, year/category filters and premium limits. Detail and celebration sheets use dev's Glass background/toolbar wrappers. |
| Core and storage | Swift Vrat sources, VratStore and Dart rewards/tracker/model sources are byte-identical between reference commits. No newly introduced streak/scoring/storage regression found in these audited paths. |
| Share | The three-selected-badge default existed on PR25; changed here to select every supplied earned badge. Manual deselection remains available. |
| Copy | The personal/no-monetary-rewards sentence existed on PR25; removed from both visible Overview implementations, so it disappears in every language. Unused translation keys remain for resource compatibility. |

The new branch also intentionally inherits dev's global app behavior, including
Glass settings, launch/location behavior and the Vaishnava default for new users.
Previously saved tradition preferences remain respected. These can affect the
chosen schedule but are not Journey scoring changes.

## Why current streak can be zero

The timeline ends at the latest recordable occurrence in the Home location,
using the existing Parana boundary. Only consecutive fully observed occurrences
contribute. A past unrecorded occurrence, partial or miss resets the run. Future
occurrences do not. Backfilling January does not bridge a later eligible gap.
A screenshot alone cannot establish which latest occurrence broke a user's run.

A deterministic test now reproduces eight observed, four partial and one missed,
followed by eligible unrecorded dates: 1,000 points, eight full completions,
longest streak four, current zero. Before the next date becomes eligible, the
same saved history has current streak two. The tested core is identical to PR25.

Partial currently contributes 50 points, a patterned yellow petal and the
three-partial encouragement badge. It does not satisfy fully-observed milestones,
strict streaks, complete-quarter or annual completion conditions. Eight of 24
means full completion, not 12 participation entries or points-weighted completion.

## Coverage and limits

Earlier coverage included strict partial breaks, future exclusion, corrections,
cross-year streaks, scoring, dynamic annual targets, all four subtab filters,
recording constraints, premium limits, translations and export pixels. It lacked
an explicit backfilled mixed-history example and a share sheet with more than
three earned badges. This update adds those cases. The original three-badge
selection and sentence are verified by failing native UI tests before fixing.

No scoring or streak policy is changed. A proposed participation/consistency
streak counting observed plus partial requires product agreement; full-observation
completion should remain explicit. The audit does not claim exhaustive proof for
every possible stored history, device or UI state.

## Validation

iOS-first baseline: analyzer clean, all 929 existing Flutter tests passed,
and all 325 Swift core tests passed (including the new mixed-history case).
Native red run `/tmp/journey-review-red.xcresult` reproduced both issues:
three of five switches selected, and the sentence still visible. Native green
results and Android red/green totals are recorded below after completion.

### Completed Android and native regression runs

- Android red: seven behavior failures, specifically three of five badges
  selected and one unwanted sentence visible in each of six languages.
- Android green: all 36 focused rewards/feedback tests pass, including all-badge
  preview membership and manual deselection; full Flutter suite: **937 passed**.
- `flutter analyze`: no issues. Formatting and `git diff --check`: clean.
- Swift core: **325 passed**. Native Journey presentation/UI: **14 passed**,
  including all four subtabs, both Glass settings, recording and premium flows.
- Broader native app/widget suite: 55 passed, one existing StoreKit catalog test
  skipped on the iOS 26 command-line runner. Two attempts at the documented iOS
  18.6 fallback stalled before test execution (reused test products, then a
  destination-specific build). Stopped those runner attempts; no passing result
  is claimed for that unrelated catalog check in this audit. Unique native
  coverage: **61 passed, one existing catalog skip**.
- No Kotlin/widget implementation, signing, product IDs, reward rules, shared
  translations, backend, dev or main changes. No CI triggered.

Test-first commits: `63eab53` (iOS), `5a92348` (Android). The iOS implementation
was pushed before starting the Android port. Local xcresults are
`/tmp/journey-review-red.xcresult`, `/tmp/journey-review-green.xcresult` and
`/tmp/journey-review-app-units.xcresult`; Android red/green and final full-suite
logs use the `/tmp/journey-review-` prefix.
