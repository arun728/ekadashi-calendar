# Apptinel website

The static pages in `public/` are the studio website and the iPhone and iPad
product pages for Ekadashi Calendar. They are separate from the Android
GitHub Pages site. The app copy and the location catalog use the Android site
as their baseline, with App Store, widget, permission and privacy adjustments.

Preview from the repository root with
`python3 -m http.server 8080 --directory website/apptinel/public`.
Run `node --test website/apptinel/tests/site.test.mjs` to check the pages.

Production uses the existing `apptinel` Cloudflare Worker. In its Deployments
view, select New deployment and upload the `website/apptinel/public` folder
as static assets. The files require no build step. The
product page and its legal URLs use directory indexes with trailing slashes.
Confirm the public URLs before updating the iOS paywall and App Store Connect
metadata to use them.
