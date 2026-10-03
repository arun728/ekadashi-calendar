# Combined v2 implementation

Candidate base: `dev` 2952ac951f62cffa06b98b75411f2d7d0480acfd.
2027 source reviewed: `feature/2027-telugu` 6283e08. Search/widgets restored
from PR #5, 5fadd35. PR #6 reverted that feature; it did not introduce Search.
The previous PR #4/#6 integration removed those features. This candidate restores
them while preserving PR #4's Vrat tracker and its regression fixes.

## User-visible changes

- Home, Calendar, Vrat, Search and Settings are separate persistent tabs.
- Calendar has a Year dropdown, category filters, custom entries and imports.
  Both 2026 and 2027 remain available. Home and widgets find the next upcoming
  event across years independently of the browsed archive year.
- Observance history uses stable occurrence UIDs, so recycled annual numeric IDs
  cannot overwrite records. Migration preserves notes, statuses, timestamps,
  traditions, locations, earned achievements and one-time notification markers.
  Unresolved rows are retained, and the original preferences remain backed up.
  Persistence failures do not publish a successful record or erase prior history.
- Google Calendar import reads the entire selected year, including paginated
  calendars/events and recurrence instances. A successful import reconciles
  deletions within that account/calendar/year; failed or partial requests keep
  the prior cache. Custom appointments are preserved. Sign-out and calendar
  selection changes clear only the appropriate imported records.
  This is a read-only import; it does not export app events to Google or provide
  background real-time two-way synchronization. Deletions appear after a
  successful re-import of the applicable year.
- Search supports Unicode, language/category/year filters and deterministic
  exact/prefix/title relevance. Typo matching uses grapheme-aware restricted
  Damerau–Levenshtein distance: one edit for 4–7 graphemes, two for longer words;
  short/numeric tokens remain strict. Every query token must match. An unrelated
  result cannot appear simply because it is an Ekadashi or marked downloaded.
  The curated PR #5 catalog is English-only and is explicitly language-filtered;
  all official calendar content is available in the four app languages.
- Three Android widgets are restored: Next Ekadashi, Ekadashi Today, and Upcoming
  Ekadashis. Native cache, launcher labels, state headings and timing labels are
  localized. Native refresh skips expired events and advances across year ends,
  clears exhausted data, avoids a duplicated hero/list item, and preserves the
  complete future timeline when Flutter is closed. Displayed times use the
  app's selected calendar location/timezone, matching the app rather than an
  unrelated phone timezone. Countdown durations still represent absolute time.
- UI resources use generated Flutter ARB localizations for English, Tamil,
  Hindi and Telugu. Calendar names, stories, rules, benefits, months and paksha
  are translated for both years. 110 Telugu 2026 content fields reused the 2027
  translation only after exact English source matching; remaining new draft
  translations are recorded for native-speaker review.
- Notification IDs remain stable for 2026 and are namespaced for 2027.
  Disabling reminders remains respected after language/year changes.

## Translation workflow

`tool/translate_resources.py` defaults to a billing-free dry run. It deduplicates
source text, protects placeholders, detects changes by source hash, reuses a
translation memory, and emits review candidates for multiple target languages.
Explicit Google Cloud credentials and `--apply` are needed for a paid API call.
No Cloud Translation call or billing setup was performed for this candidate.
Automated audits cover completeness, placeholders, unintended English fallback,
script coverage and screen literals; linguistic correctness still needs review.

## Validation boundaries

`TESTING.md` records exact final results and commands. Real Google OAuth consent,
account deletion on Google, Samsung M52/Z Flip 5 restrictions and release-signed
Play Store upgrade validation require the configured account/physical devices.
There is no iOS widget/build validation claim. The astronomical calculation
engine and extra Bengali/Gujarati content remain separate future work.
