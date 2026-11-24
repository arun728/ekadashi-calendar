# Apptinel website

The static pages in `public/` are the studio website and the shared Android,
iPhone and iPad product and legal pages for Ekadashi Calendar. They remain
separate from the Android GitHub Pages site. The feature copy is shared;
permissions, billing and widgets describe each platform where they differ.

Android links to the live Google Play listing. At iOS launch, replace the
“iOS · Coming soon” label in `public/ekadashi-calendar/index.html` with the
verified public App Store URL. Do not use the placeholder app URL. The preview
is labelled as iOS footage. Android v2 availability is distinguished from the
existing live Android listing. Minimum Android 7.0 follows Flutter's minSdk 24;
iOS and iPadOS require version 17.

Preview from the repository root with
`python3 -m http.server 8080 --directory website/apptinel/public`.
Run `node --test website/apptinel/tests/site.test.mjs` to check the pages.

Production uses the existing `apptinel` Cloudflare Worker. Deploy with
Wrangler (not the dashboard upload, which flattens the folders), then verify
the live pages. Every change to this site is deployed and verified the same
day. See [docs/CLOUDFLARE.md](../../docs/CLOUDFLARE.md) for the reasons, the
sign-in and the Cloudflare plugin for Claude Code.

```bash
cd website/apptinel && npx wrangler@4 deploy --name apptinel --assets ./public --compatibility-date 2026-11-01
```

The product page and its legal URLs use directory indexes with trailing
slashes. Confirm the public URLs before updating the iOS paywall and App Store
Connect metadata to use them.
