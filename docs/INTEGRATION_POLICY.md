# Required integration flow

User instruction, 3 October 2026:

- Work on isolated branches for review, fixes, and automated testing.
- Both v2 feature changes (tracker and widgets/search) need complete testing,
  with all required tests passing before proposing integration.
- Integrate into `dev` first, only after Arun explicitly approves that push or
  merge. Do not infer approval from a request to review, fix, or add tests.
- Never push or merge to `dev` or `main` without explicit permission.
- `main` is protected. Do not assume direct push access. Release integration
  requires separate explicit approval after complete testing.

These instructions apply to the test foundation branch too: do not push it or
create remote integration changes without explicit authorization.
