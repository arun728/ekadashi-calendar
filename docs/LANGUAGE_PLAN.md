# Language support proposal

Google can draft multiple languages in batches; it does not automatically make
an app's code, content and native widgets fully localized. Reviewed the official
Flutter, Android, Cloud Translation and ML Kit documentation on 3 October 2026.

## Recommended approach

Move the hand-written LanguageService dictionaries into Flutter ARB resources
and generated typed localization (`flutter gen-l10n`). Keep English source keys
stable, give translators context, and use ICU plurals/placeholders. Dates,
numbers, time formats and calendars use locale-aware formatting; astronomical
UTC values, IDs, timezone identifiers and stored observance status are data and
must not be translated.

Use Google Cloud Translation Advanced in a development/content publishing
pipeline to draft Bengali, Gujarati and other locales together. Translate only
new/changed strings, preserving keys and placeholders; cache translation outputs
for review. Use a glossary for Ekadashi names and religious terminology. The API
is billed; confirm current pricing and language/model availability when setting
up the project. Do not call it on every app launch or put a service-account key
in the mobile app. Ship approved resources with the app for offline use.

Stories, benefits, rules and significance are a separate localized content
catalog from UI labels. Content can share a stable content ID across years;
2026 Telugu is currently absent while 2027 has Telugu in all five content
fields. Define an explicit fallback while translating older content. Keep
religious guidance reviewed by a fluent person familiar with the subject.
Machine translation is a draft, not validation of doctrinal or timing accuracy.

Native Android/iOS widget labels, reminder bodies, calendar editors, Google
sync errors, achievement dialogs and permission explanations all belong in the
same localization inventory. The new 2027 editor/filter/import/widget strings
are currently largely hardcoded English despite Telugu support.

## Google options

| Option | Useful for | Limit |
|---|---|---|
| Flutter localization / Android resources | Locale selection, formatting, resource fallback, plurals, per-app language support | Infrastructure; does not author translations |
| Google Cloud Translation | Batch/server-side translation and terminology glossary workflow | Billing and quality review; ship offline output |
| ML Kit on-device translation | Optional live translation after downloading models | Non-English pairs use English as an intermediary; quality can vary; not a replacement for approved religious content |
| Google Play translated store listings | Store description/discovery | Does not translate app screens |

The current official language lists include Bengali (`bn`), Gujarati (`gu`),
Hindi (`hi`), Tamil (`ta`) and Telugu (`te`) for Cloud Translation and ML Kit.

## Automated tests

Check resource key coverage, intentional fallbacks, ICU placeholders/plurals,
localized date/time/number formatting, source-data integrity and non-ASCII
serialization. Capture screenshots for every screen in each supported locale
with real fonts, large text and small viewports. Exercise live UI language
switching, restart persistence, native reminder/widget payloads and offline
startup. Language completeness and layout can be automated; idiomatic/religious
correctness needs review.

Official references:
- https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization
- https://developer.android.com/guide/topics/resources/localization
- https://cloud.google.com/translate/docs/overview
- https://cloud.google.com/translate/docs/languages
- https://cloud.google.com/translate/docs/advanced/glossary
- https://developers.google.com/ml-kit/language/translation
- https://developers.google.com/ml-kit/language/translation/translation-language-support

This is a discussion plan only. No Cloud project was created, no text was sent
for translation, and no application localization redesign was implemented.
