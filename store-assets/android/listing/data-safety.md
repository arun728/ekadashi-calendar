# Play Console → App content → Data safety (v2.0.0)

Based on what the Android app actually sends off the device (checked 24 Nov 2026):
no analytics, ads or crash-reporting SDKs; no developer backend. Off-device traffic
is Google Sign-In, Firebase Authentication + Firestore (the free-import registry),
the Google Calendar API, Google Play Billing, Play in-app updates and the
device geocoder.

## Overview answers
- Does your app collect or share any of the required user data types? **Yes**
- Is all of the user data collected by your app encrypted in transit? **Yes**
- Do you provide a way for users to request that their data be deleted? **Yes**
  (email contact@apptinel.com, as the privacy policy says)

## Data types

| Category → type | Collected | Shared | Optional? | Purpose | Notes |
|---|---|---|---|---|---|
| Personal info → **Email address** | Yes | No | Optional (only if the user signs in for Google Calendar import) | App functionality | Firebase Authentication keeps the Google account email with its sign-in record |
| App info and performance / Device or other IDs → **User IDs** | Yes | No | Optional (same) | App functionality | Firebase user ID; the Firestore record ties the one free import to the account |

Not declared (stays on the device or goes only to Google's own APIs on the user's behalf):
- **Calendar events**: read from Google Calendar straight to the phone and stored only there.
- **Location**: GPS is used on the phone to calculate times; only the city name is looked up
  through the Android geocoder (Google Play services). Nothing reaches us. If Play review
  asks, the safe answer is *Approximate location — collected, not shared, ephemeral,
  app functionality*.
- **Purchase history**: handled by Google Play Billing; the app keeps no record off the device.
- **Photos** (Save to Gallery) and **notifications**: on device only.

## Also in App content
- Privacy policy URL: https://apptinel.com/ekadashi-calendar/privacy-policy/
- Ads: **No ads**
- Target audience: 13+ (not designed for children)
