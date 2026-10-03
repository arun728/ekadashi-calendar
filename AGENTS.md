# Repository collaboration rules

These rules record Arun's explicit instructions from 3 October 2026.

- Never push or merge to `dev` or `main` without Arun's explicit permission.
  `main` is protected; do not assume direct push access.
- Work on isolated branches for reviews, fixes and automated tests. Review
  concrete candidate commits and test evidence before requesting integration.
- The tested integration pair is PR #4 (tracker/achievements) plus PR #6 (the
  revert that removes the accidentally merged PR #5 widgets/search changes).
  Do not restore PR #5 as part of this candidate. Dev integration needs
  explicit approval. Main release integration needs a separate explicit
  approval after complete release testing.
- Run deterministic domain, regression, integration and UI tests automatically
  on Android emulators wherever practical; capture screenshots and logs. Reserve
  physical-device checks for OEM/hardware and real background reliability.
- Treat `feature/2027-telugu` as the confirmed source of the described 2027
  upgrade. Review and discuss its multi-year implementation/test plan before
  implementing the redesign. Preserve older Ekadashi data, observance history,
  streaks, achievements and one-time notification markers across upgrades.
- Calculation-engine work is deferred; focus on the current PRs and upgrade
  planning first.

See docs/INTEGRATION_POLICY.md, docs/TESTING.md and
 docs/UPGRADE_INTEGRATION_PLAN.md for the current review and proposed flow.
