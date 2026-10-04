# Required integration flow

Arun's instructions, updated 3 October 2026:

- Work on isolated branches and follow TDD for fixes and new functionality.
- Run unit, regression, integration, native and UI gates before integration.
- Arun explicitly authorized integrating **all requested v2 changes** into `dev`
  once the required tests pass: restored Search/widgets, both calendar years,
  Telugu, tracker migration, custom calendar and whole-year Google import.
- This authorization supersedes the earlier Search/widgets-only scope.
- Future merges into `dev` require explicit permission unless already authorized
  in the session. Protect `dev` against accidental direct pushes/merges.
- Never update `main` without separate explicit release approval. This candidate
  does not authorize or perform a release.
- Use the connected GitHub App. Never commit credentials or use tokens pasted
  into chat. Test scripts that clear app/launcher data require a dedicated emulator.

## Glass UI prototype

Arun explicitly authorized merging `feature/android-glass-navigation` into dev
after automated tests and screenshot checks pass, and confirmed those gates are
sufficient. PR #8 merged after all seven CI14 jobs passed. Samsung physical-device
checks remain release validation. Main stays untouched.

## Paid features and rewards

Develop on `feature/subscriptions-rewards`, based on the validated UI dev merge.
Do not merge this paid/reward work into dev until Arun finalizes, tests and gives
new explicit permission. Vrat recording/history/streaks/statistics stay free and
always available. The first three earned achievements are free; additional
unlocks are premium, and existing earned badges are preserved. Google Calendar
sync is paid, custom entries and all current widgets remain free. Use Play billing
and server-verified entitlements; fasting coins provide non-cash premium credit.
