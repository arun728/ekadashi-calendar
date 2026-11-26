# Cloudflare: apptinel.com and agent setup

apptinel.com is the studio website and the home of Ekadashi Calendar's product,
privacy and terms pages (the App Store and Play listings link to them). It is
served by the existing Cloudflare Worker **`apptinel`** as static assets from
`website/apptinel/public/`. There is no build step.

## Rule: always deploy and verify

Arun's standing rule (24 November 2026): whenever any agent changes the
Apptinel website, it deploys the change to production itself and checks it is
live. A change that is only committed is not done.

1. Change the pages in `website/apptinel/public/` and test first (TDD):
   `node --test website/apptinel/tests/site.test.mjs`.
2. Commit (with `[skip ci]`) and push to the PR branch.
3. Deploy with Wrangler (below).
4. Verify live, bypassing caches, for example
   `curl -s "https://apptinel.com/ekadashi-calendar/privacy-policy/?v=$RANDOM" | grep "..."`
   on every page you changed.

## Deploy with Wrangler (what we use)

```bash
cd website/apptinel && npx wrangler@4 deploy --name apptinel --assets ./public --compatibility-date 2026-11-01
```

The output ends with `Current Version ID: …`. Report that ID in the PR.

### Why Wrangler

- **Folders stay intact.** The pages use directory indexes
  (`/ekadashi-calendar/privacy-policy/index.html` served at
  `/ekadashi-calendar/privacy-policy/`). Uploading the folder in the
  Cloudflare dashboard (Deployments → New deployment) flattened the folders
  and would have broken those URLs. Wrangler uploads the tree as it is.
- **The routes are kept.** Deploying to the existing Worker name keeps the
  apptinel.com routes; nothing in DNS or routing changes.
- **No config file in the repo.** Everything is on the command line, so there
  is no `wrangler.jsonc` to keep in sync (and no account ID in the repo).
- **Only changed files upload.** Wrangler hashes the assets and sends only the
  changed ones, so a deploy takes seconds.
- **Agents can do it.** It runs from the terminal, so any session can deploy
  and verify without anyone clicking through the dashboard.

### Sign-in

Wrangler is signed in on Arun's Mac through OAuth (`npx wrangler login`, done
on 24 November 2026; Arun approved the consent page himself). The token lives
in Wrangler's own config, not in the repo. If a deploy says you are not
signed in, ask Arun to run `npx wrangler login` and approve it. Never ask for
or paste API tokens.

Wrangler writes a local `website/apptinel/.wrangler/` cache folder; it is
ignored by git and never committed.

## Cloudflare tools for Claude Code (agent setup)

Set up on 24 November 2026 from Cloudflare's agent setup instructions:
<https://developers.cloudflare.com/agent-setup/prompt.md>

What was installed (user scope, so every Claude Code session on this Mac has it):

```bash
claude plugin marketplace add cloudflare/skills
claude plugin install cloudflare@cloudflare
```

- The plugin adds Cloudflare skills (for example `cloudflare:wrangler`,
  `cloudflare:workers-best-practices`, `cloudflare:web-perf`, `cloudflare:cf-cli`)
  and the remote Cloudflare MCP server (`https://mcp.cloudflare.com/mcp`).
- After installing, run `/reload-plugins` in a session to load it.
- The MCP server needs a one-time OAuth sign-in to Cloudflare. Agents cannot
  start it: Arun authorizes it himself through `/mcp`. Until he does, its
  tools are unavailable; Wrangler deploys still work without it.
- Use the `cloudflare:wrangler` skill for this site, because the project
  deploys with Wrangler.

Not installed: Cloudflare's beta `cf` CLI (`npm install -g cf`), which the
setup page offers as optional. Wrangler already covers the website. Install it
only if Arun asks.
