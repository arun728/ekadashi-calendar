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
