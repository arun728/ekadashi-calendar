---
layout: android
permalink: /privacy-policy.html
title: Privacy Policy
description: How Ekadashi Calendar for Android handles location, Google Calendar data, purchases, and deletion.
page_class: policy
---

# Privacy Policy

**Updated November 16, 2026** · **Ekadashi Calendar for Android**

Arun Kumar MP publishes Ekadashi Calendar on Google Play. Contact [arunmp.728@gmail.com](mailto:arunmp.728@gmail.com) for privacy questions. This policy covers the Android app and this website. Availability of optional features depends on the installed version.

## Calendar, Journey and settings

Your custom calendar entries, recent searches, vrat records and notes, progress, achievements, language, appearance, selected places and reminder preferences are stored in app storage on your device. Android backup or device transfer may retain or restore eligible app data depending on your device and Google settings. The app does not require a separate Ekadashi Calendar account for its core features. The Android app has no ad network or in-app analytics service.

## Location and Android permissions

- **Location.** If you allow approximate or precise location, the app uses Android location services to suggest the city and calculate fasting and Panchang times. It uses your selected or last available place for calculations, with Chennai as the default when no place is available. A detected place can be saved on the device. For a readable city name, the app can use Android’s geocoder, which may use a network service provided by your device. The app does not keep a movement history or send your location to a developer server. You can pick a place without granting permission.
- **Notifications and alarms.** Android uses your reminder choices and locally scheduled times to show fasting, Parana and event reminders. Exact-alarm access, where available, helps Android deliver time-sensitive reminders. You can turn notifications or alarm access off in Android settings.
- **Saving or sharing.** If you save a card, Android writes the image to your photo library. Older Android versions may require storage permission. If you share a card or recap, Android sends the content you select to the app or recipient you choose.

## Optional Google Calendar import

If you choose **Import from Google Calendar**, the app uses Google Sign-In and the read-only Google Calendar permission (`calendar.readonly`). It can receive an account identifier and email to identify the selected account, list calendar names and identifiers, and read event information in the calendars and date range you select, such as titles, descriptions, locations and scheduled times. The app uses this information to display events, support search and reminders, and remember which calendars you selected. Imported events and selections are stored on your device. The app does not create, edit or delete events in Google Calendar or send imported event content to a developer server.

In versions configured to verify a free import across devices, the app sends your Google ID token over HTTPS to **Firebase Authentication**. Google authenticates the account and returns an account identifier and session credentials. The app uses the identifier to check or create a **Firestore** record with the imported month and a timestamp. The record contains no event content or email address. Firebase Authentication processes the Google account information needed for sign-in. The registry exists to remember whether an account already used its free import.

Ekadashi Calendar’s use and transfer of information received from Google APIs follows the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements. We use Google Calendar data to provide the import and related features you request. We do not sell it or use it for advertising.

## Google Play purchases

Google Play processes payments and provides the app with purchase and entitlement information, such as which product your Play account owns and its subscription status when available. The app uses it to grant or restore Premium. We do not receive your card or bank details through the app. Google’s handling of account, payment and service data is described in the [Google Privacy Policy](https://policies.google.com/privacy).

## Retention and deletion

- **Local app data.** You can delete your own entries in the app and clear app storage in Android settings. Clearing storage or uninstalling removes the local app copy. Eligible Android backup data or saved images may remain outside the app and can be managed in your backup settings or photo library.
- **Google Calendar.** In Calendar, **Disconnect Google** signs out and removes the imported copy and saved calendar selections for the connected account. You can also remove the app’s permission in your [Google Account connections](https://myaccount.google.com/connections). Revoking permission at Google blocks future access. To remove a copy already stored on the phone, use **Disconnect Google** or clear the app’s storage.
- **Free-import record.** The Firestore record is retained to enforce the one-time import across devices. Signing out or uninstalling does not remove it. To request deletion of the free-import record and the associated Firebase authentication record, email [arunmp.728@gmail.com](mailto:arunmp.728@gmail.com). We may ask for information to verify the request. Never send a password or Google security code.
- **Support correspondence.** If you email us, we receive your email address and the information you choose to provide. We keep the correspondence as needed to respond, follow up, or comply with legal obligations. You can contact us about access, correction or deletion requests.

## This website

[GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/about-github-pages) hosts this site. GitHub logs visitors’ IP addresses for security. The city lookup runs in your browser against public catalog data. It does not ask for your current location or submit your search terms. The site does not add advertising trackers or analytics. External services apply their own privacy policies. [GitHub Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)

We post updates to this policy here and revise the date above. For questions or privacy requests, email [arunmp.728@gmail.com](mailto:arunmp.728@gmail.com).
