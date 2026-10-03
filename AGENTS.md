# Repository collaboration rules

These rules record Arun's explicit instructions from 3 October 2026.

- Never push or merge to `dev` or `main` without Arun's explicit permission.
  `main` is protected; do not assume direct push access.
- Work on isolated branches for reviews, fixes and automated tests. Review
  concrete candidate commits and test evidence before requesting integration.
- Restore and integrate Search and all three Android widgets from PR #5 alongside
  the Vrat tracker, the 2026/2027 archive, Telugu and calendar changes. PR #6
  reverted the feature and was not the desired final product state.
- Arun explicitly authorized merging all requested changes to `dev` after all
  unit, native, regression, integration and UI tests pass. Keep `main` untouched.
- Follow TDD for functionality and UI fixes: demonstrate the failing behavior
  before fixing it, then run the relevant regression and full-suite gates.
- Google Calendar import covers the selected entire year and reconciles remote
  deletions atomically. Failed/partial imports preserve previously cached events.
- Audit every UI localization key, placeholders and unintended English fallback
  in Tamil, Hindi and Telugu. Do not enable paid translation billing implicitly.
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
