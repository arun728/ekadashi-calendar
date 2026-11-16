---
layout: android
permalink: /
title: Ekadashi Calendar for Android
description: Find local Ekadashi and Parana times, track your vrat, and explore the Panchang in six languages.
page_class: home
---

<section class="hero" aria-labelledby="page-title">
  <div>
    <p class="eyebrow">Android v2 guide</p>
    <h1 id="page-title">Ekadashi Calendar</h1>
    <p class="intro">Plan your Ekadashi fast and find the Parana window for your city. Follow Smarta or Vaishnava observances, record your vrat, and explore the local Panchang.</p>
    <div class="actions">
      <a class="button" href="https://play.google.com/store/apps/details?id=com.applausestudios.ekadashi_calendar">View on Google Play</a>
      <a href="#free-and-premium">Compare Free and Premium</a>
    </div>
    <p class="note">This guide describes Android v2. Check Google Play for the version available to your account.</p>
  </div>
  <img src="{{ '/assets/app-icon.png' | relative_url }}" alt="" width="192" height="192">
</section>

## Free and Premium

### Free features

- **Ekadashi Home.** See dates for **2026 and 2027** in your city. Follow Smarta or Vaishnava calculations, see the fasting countdown and progress, and check the start and end of Parana. Open the festival detail for traditional stories, significance, fasting rules and food guidance. Save or share an Ekadashi card.
- **Calendar.** Browse months, jump to a date, and add, edit or remove your own entries. See Ekadashis and imported events alongside your entries. Try one successful read-only Google Calendar import of the **month you’re viewing**. The free import is limited by your Google account and the app’s saved eligibility.
- **Journey.** Record your first **three** new vrat entries and unlock your first three achievements. View and edit your recorded history, review statistics and streaks, and keep earned badges. The Journey overview shows progress by year, quarter and across years, with points and an optional year recap share card. Points track personal progress and have no cash value.
- **Panchang preview.** Check the day’s tithi, lunar month and weekday, major observance names when available, sunrise and sunset, and moonrise and moonset. Browse Ekadashi dates in Key Days and the separate Panchang Ekadashi view.
- **Search.** Find Ekadashis, personal calendar entries, and app screens from the toolbar. Use year and category filters and search with alternate spellings. Premium unlocks the full Panchang observance results.
- **Reminders and home-screen widgets.** Set reminders for two days before, one day before, fasting start, and Parana. Add reminders for your own events. Choose from Next Ekadashi, Ekadashi Today, and Upcoming Ekadashis widgets. Widget previews are in Settings.
- **Appearance and language.** Use light or dark appearance and the optional Glass Look. The app’s language setting also applies to dates, place names, Panchang terms, reminders and widgets.

### Ekadashi Premium

| Feature | What you unlock |
| --- | --- |
| **Full Panchang** | All five limbs with timings: tithi, vara, nakshatra, yoga and karana. See additional daily details, auspicious and inauspicious periods such as Abhijit Muhurta and Rahu Kalam, Muhurta and Rashi views, and the full festival and observance listings, search and related reminders. |
| **Journey** | Record more than three new vrats and unlock further streak, milestone and annual achievements as you meet their requirements. |
| **Google Calendar import** | **Monthly** and **Yearly** subscriptions can import 12 months of events starting from the subscription’s purchase month. **Lifetime** covers every supported Ekadashi calendar year. Import reads your selected Google calendars into the app. |

Monthly and Yearly renew through Google Play. Lifetime is a one-time purchase. Prices and applicable terms appear in your local checkout. Google sign-in is used for Calendar import. Premium purchase and restoration use your Google Play account.

## Cities and time zones

Search **34,152 bundled cities** worldwide. Each city has its own coordinates and IANA time zone, including local daylight-saving rules where applicable. The offline catalog offers **554 IANA time-zone IDs**, including aliases, from release **2026b**. Choose a city manually, use optional location detection, or enter custom coordinates and an available time zone in the app. Chennai is the starting fallback if no place is available. At locations or seasons where a sunrise or other event is unavailable, some timings may be unavailable.

<details id="location-catalog" data-catalog="{{ '/assets/locations.json' | relative_url }}">
  <summary>Browse every supported city and time zone</summary>
  <div class="catalog-controls">
    <label for="city-query">City, country code or time zone</label>
    <input id="city-query" type="search" placeholder="For example, Chennai or Pacific/Chatham" disabled>
    <label for="zone-filter">Time zone</label>
    <select id="zone-filter" disabled><option value="">All time zones</option></select>
  </div>
  <p id="catalog-status" class="note" role="status" aria-live="polite"></p>
  <ul id="city-results" aria-label="Matching cities"></ul>
  <button id="city-more" type="button" hidden>Show more cities</button>
  <p class="note"><a href="{{ '/assets/locations.json' | relative_url }}">Download the full catalog as JSON</a>. City names and coordinates come from <a href="https://www.geonames.org/">GeoNames</a> under <a href="https://creativecommons.org/licenses/by/4.0/">CC BY 4.0</a>.</p>
</details>
<script src="{{ '/assets/locations.js' | relative_url }}" defer></script>

## Six app languages

<ul class="languages">
  <li>English</li>
  <li><span lang="hi">हिन्दी</span> · Hindi</li>
  <li><span lang="ta">தமிழ்</span> · Tamil</li>
  <li><span lang="te">తెలుగు</span> · Telugu</li>
  <li><span lang="gu">ગુજરાતી</span> · Gujarati</li>
  <li><span lang="bn">বাংলা</span> · Bengali</li>
</ul>

## Offline use and support

Calendar calculations, bundled content and your personal records work offline. Google Calendar import and Play billing require their online services. The app is ad-free. Read the [Privacy Policy]({{ '/privacy-policy.html' | relative_url }}) for location, backups and Google data, or the [Terms of Service]({{ '/terms-of-service.html' | relative_url }}) for purchases and cancellations.

Maintained by Arun Kumar MP. For help finding your city, importing a calendar or restoring Premium, [email support](mailto:arunmp.728@gmail.com).
