# App Store Connect answers

## App Information

| Field | Value |
|---|---|
| Primary category | Lifestyle |
| Secondary category | Reference |
| Content rights | Does not contain, show or access third-party content |
| Copyright | 2026 Apptinel Software Private Limited |
| Support URL | https://apptinel.com/ekadashi-calendar/ (has the support contact) |
| Marketing URL | https://apptinel.com/ekadashi-calendar/ |
| Privacy Policy URL | https://apptinel.com/ekadashi-calendar/privacy-policy/ |
| Terms of Use (EULA) | https://apptinel.com/ekadashi-calendar/terms-of-service/ (add to the description and App Information > License Agreement, required for auto-renewing subscriptions) |

All three pages return 200 (checked 19 Nov 2026).

**Version number:** App Store Connect has version **1.0**; the builds are **2.0.0**. Rename the App Store version to 2.0.0 before attaching the build, or the build won't match.

## Age rating

Answer **None / No** to every content question (violence, sexual content, profanity, horror, drugs, gambling, contests, medical, user-generated content, messaging, unrestricted web access, advertising). Expected rating: **4+**. The app has no web browser, chat or user-generated sharing beyond the system share sheet.

## App Privacy (data types)

Tracking: **No** (no ads, no analytics, no data brokers).

| Data type | Collected | Linked to user | Tracking | Purpose |
|---|---|---|---|---|
| Identifiers → User ID | Yes (Firebase account ID for the free-import record) | Yes | No | App Functionality |
| Contact Info → Email Address | **Yes, confirm** — Firebase Authentication stores the Google account email by default when signing in with Google (`signInWithIdp`) | Yes | No | App Functionality |

Not collected: location (stays on device; only Apple's geocoder sees it), purchases (Apple processes them), calendar event content (stays on device), usage data, diagnostics, contacts, photos.

**Action:** if Firebase keeps the email (check Firebase console > Authentication > Users), also add `NSPrivacyCollectedDataTypeEmailAddress` to `ios-native/EkadashiCalendar/Resources/PrivacyInfo.xcprivacy` so the manifest matches the labels.

## App Review information

- Sign-in required: **No**
- Contact: use the same name, phone and email as the TestFlight beta review contact (kept out of this public repo)
- Notes (1276/4000):

```
Ekadashi Calendar works without an account or sign-in. Everything below can be reviewed on a fresh install.

FREE: Home shows the next Ekadashi with fasting and Parana times for the selected city (default Chennai; tap the city menu to pick any city worldwide or use location). Smarta / Vaishnava and the language are in the menus on Home. Calendar, share cards, widgets and reminders are free.

PREMIUM (Monthly, Yearly or Lifetime, in the Ekadashi Premium group): open Settings > See plans, or tap any lock. Premium unlocks the full Panchang tab (Daily, Muhurta, Rashi and every festival in Key days), festival reminders, unlimited Vrat records in Journey (the first three are free) and Google Calendar import for the subscription year. Premium is granted only from verified StoreKit transactions; Restore purchases is on the plans screen.

GOOGLE CALENDAR (optional): Calendar > Google menu > Import. It uses Google Sign-In with read-only calendar access. Reviewers do not need to sign in to test the rest of the app. Free users get one month's import; this is recorded per Google account in Firebase so it cannot be repeated by reinstalling.

LOCATION (optional): used only to suggest the nearest city. The app works fully with a picked city.

Contact: contact@apptinel.com
```

## In-app purchases

Subscription group reference name: Ekadashi Premium (group level: Yearly 1, Monthly 2).

| Locale | Group display name | Monthly (name — description) | Yearly | Lifetime |
|---|---|---|---|---|
| en-US | Ekadashi Premium | Premium Monthly — All Premium features, billed every month | Premium Yearly — All Premium features, billed every year | Premium Lifetime — All Premium features, one-time purchase |
| hi | एकादशी प्रीमियम | प्रीमियम मासिक — सभी प्रीमियम सुविधाएँ, हर महीने भुगतान | प्रीमियम वार्षिक — सभी प्रीमियम सुविधाएँ, हर साल भुगतान | प्रीमियम आजीवन — सभी प्रीमियम सुविधाएँ, एक बार भुगतान |
| ta | ஏகாதசி பிரீமியம் | பிரீமியம் மாதாந்திரம் — எல்லா பிரீமியம் அம்சங்களும், மாதக் கட்டணம் | பிரீமியம் வருடாந்திரம் — எல்லா பிரீமியம் அம்சங்களும், ஆண்டுக் கட்டணம் | பிரீமியம் வாழ்நாள் — எல்லா பிரீமியம் அம்சங்களும், ஒருமுறை கட்டணம் |
| te | ఏకాదశి ప్రీమియం | ప్రీమియం నెలవారీ — అన్ని ప్రీమియం ఫీచర్లు, నెలవారీ చెల్లింపు | ప్రీమియం వార్షిక — అన్ని ప్రీమియం ఫీచర్లు, వార్షిక చెల్లింపు | ప్రీమియం జీవితకాలం — అన్ని ప్రీమియం ఫీచర్లు, ఒకేసారి చెల్లింపు |
| gu | એકાદશી પ્રીમિયમ | પ્રીમિયમ માસિક — બધી પ્રીમિયમ સુવિધાઓ, દર મહિને ચુકવણી | પ્રીમિયમ વાર્ષિક — બધી પ્રીમિયમ સુવિધાઓ, દર વર્ષે ચુકવણી | પ્રીમિયમ આજીવન — બધી પ્રીમિયમ સુવિધાઓ, એક વખત ચુકવણી |
| bn | একাদশী প্রিমিয়াম | প্রিমিয়াম মাসিক — সব প্রিমিয়াম সুবিধা, প্রতি মাসে পেমেন্ট | প্রিমিয়াম বার্ষিক — সব প্রিমিয়াম সুবিধা, প্রতি বছর পেমেন্ট | প্রিমিয়াম আজীবন — সব প্রিমিয়াম সুবিধা, এককালীন পেমেন্ট |

Limits: display name 30, description 45 (all checked). Add each locale only if App Store Connect offers it. Current en-US names in App Store Connect are close; the descriptions above are clearer.

Review screenshots: already uploaded for all three products (real device, ₹99 / ₹599 / ₹1,999). Copies in `../iap-review/`. Keep them.
