# Personal birth profile — iOS Phase 2

Branch: `feature/premium-birth-profile`, based on latest `dev` at
`c48ac07f9a27713d01b0698851d11b37f1672b69`. This branch does not include the
unmerged Journey implementation. Arun authorized this phase on 18 October 2026.

## Product scope

Panchang has a new Birth profile subtab with one personal profile. The form
collects a Gregorian birth date, optional local birth time, and birthplace.
Search uses the bundled city catalogue and its existing background search
index. Manual coordinates and an explicit IANA timezone are also available.
Choosing a birthplace never changes Home or Panchang's current location.
There is no geocoder, remote astrology request or login in this flow.

New calculations and updates require the current verified StoreKit Premium
entitlement. Monthly, annual and lifetime purchases use the same existing
entitlement check. The introduction and editor can be explored before buying.
Closing a paywall preserves the draft. Existing saved input/results remain
readable and deletable after expiry; recalculation requires Premium again.

## Calculation convention and limits

- Supported birth dates: 1 January 1900 through today in the birthplace.
  The underlying astronomy has a 1900–2100 Delta-T table; this feature does
  not offer future birth dates or dates before 1900.
- The birth instant is resolved from local clock components and the bundled
  IANA timezone database. Current UTC offsets and device timezone are never
  substituted for historical offsets. Historical offsets can include seconds.
- Enumerate and round-trip all historical offsets: an ordinary local time has
  one instant, a spring gap has none, and a repeated time has two. A gap must
  be corrected, or the user can choose unknown time. A repeated time requires
  explicit selection of the first/second occurrence, with UTC and offsets
  displayed. Editing requires reconfirming that choice.
- Calculate apparent geocentric Moon/Sun positions at the resolved instant
  using the existing offline engine. Subtract the apparent Lahiri ayanamsa
  for sidereal lunar longitude. No sunrise/day-summary value is reused.
- Rashi divides the sidereal circle into 12 signs; Nakshatra into 27 equal
  mansions; Pada into 108 quarters. Tithi divides the normalized apparent
  Moon–Sun elongation into 30 parts, with Shukla/Krishna labels.
- Birth time is entered to the minute. An exact result within two minutes of
  a category boundary displays a birth-time-check notice. This is a useful
  caution, not a guarantee outside that window; uncertain recorded birth
  times may dominate astronomical error.
- Unknown time scans the full local date, including 23/25-hour DST days and
  half-hour changes. Skipped civil dates are rejected. Scan every five
  minutes, detect category changes and bisect to within 0.25 seconds. Results
  show which fields stay the same, alternatives for changing fields, and a
  timeline with approximate local transition times. There is no noon guess.
- Results describe calculated birth-time positions, not predictions. Full
  Kundali, dashas, daily Rasi Palan and family birthday reminders are deferred.

## Independent validation

`tool/panchang_accuracy/birth_reference.py` creates synthetic fixtures using
Swiss Ephemeris 2.10.03 with the JPL DE431-derived `sepl_18` and `semo_18`
files, apparent geocentric positions and Lahiri ayanamsa. The independent
library/data are development tools only; they are not app dependencies.
See the [Swiss Ephemeris documentation](https://www.astro.com/swisseph/swisseph.htm)
for its coordinate and sidereal conventions.

The checked-in `test/fixtures/panchang/birth_reference.json` has 196 instants
from 1900 to 2026, leap dates, seeded random samples, and points two minutes
before/after independently found Rashi/Nakshatra/Pada/Tithi boundaries.
It covers all 12 signs, 27 stars, four padas and 30 tithis. Tests require all
classifications to agree and sidereal Moon longitude differences below
0.003 degrees. This sample-based validation does not assert universal
accuracy or replace verification of a user's birth record.

Timezone tests independently assert historical Indian wartime time,
Kathmandu's earlier offset, New York's spring/autumn transitions, Lord Howe's
half-hour fold, and Apia's skipped date. Full-day interval coverage is checked
against 23- and 25-hour dates. All code uses the existing bundled timezone
rules. The bundled IANA build merges some pre-1970 regional histories
(for example, Accra's older local offsets), so birthplace-specific historical
records are not universally complete. This candidate must not be advertised
as universally exact for every location back to 1900. Historical legal-time
records and uncertain birth records can themselves be imperfect.

To regenerate references (development only):

```sh
python tool/panchang_accuracy/birth_reference.py EPHE_DIR test/fixtures/panchang/birth_reference.json
```

## Local storage and privacy

One versioned JSON envelope is stored under `personal_birth_profile_v1` in
the app's standard local preferences, separately from the widget app group.
It contains the input, calculated snapshot, calculation version and timezone
release. Results are stored with their resolved UTC instant/timeline so expiry
does not erase the personal record or force a fresh paid calculation.

Writes are checked before replacing visible state. Failed saves/deletions
preserve the previous profile. Unreadable, unsupported or malformed snapshots
are rejected without automatic overwrite; retry and explicit deletion remain
available. Deletion writes a verifiable empty envelope. Birth data is not
logged, shared, exported, sent to analytics, or sent to a service by this flow.
Device erasure/uninstall may lose it; OS-level device backup is outside this
feature. A separate export/import workflow is deferred.

## Test evidence

Separate test-first commits include `734f535` (missing domain API), `826ed02`
(missing UI and 45 six-language keys), `9fc1e85` (malformed saved snapshot
accepted/overwritten), `6d4e179` (an empty-window screenshot), and `22bf742`
(two distinct transitions inside one five-minute step), and `64186fc`
(filled coordinate fields losing their visible labels). Corresponding red
runs preceded implementation. A sub-minute signed-offset formatting test
uses explicit seconds rather than assuming the bundled Accra history retains
that old regional offset.

- `flutter analyze`: no issues.
- Full `flutter test`: **726 passed**.
- Full release Swift package suite: **265 passed**. Independent reference
  classifications agree at all 196 fixture instants; angular errors satisfy
  the 0.003-degree threshold.
- Final iOS 26.5 native suite: **10 passed** (`ios-window-results.log`).
  Birth UI checks: **3 passed, 1 explicit StoreKit runtime skip**
  (`ios-final-candidate.log`); the later persistent-label regression failed
  first, then passed (`manual-labels-red.log`, `manual-labels-verified.log`).
  Native tests cover existing AppModel behaviour, historical offset text,
  all four exact-time result cards, all six languages at large type, and both
  repeated-time choices. UI tests cover free calculation opening Premium,
  cancellation retaining the draft, offline city selection without changing
  Home, and manual timezone validation.
- The previous full UI regression run passed 13 of 14 existing ScreenshotTests.
  The remaining notification test was corrected to scroll its lazy row into
  view; its unchanged off/disabled assertions then passed on iOS 26.5 and 18.6.
- Test screenshots use synthetic birth inputs. Exact/unknown results and the
  repeated-time editor are rendered directly by native tests; these are visual
  evidence, not evidence of a successful paid purchase.

### Purchase validation remains open

The complete paid save/edit/unknown-time/delete XCUITest is present but has
**not passed** in this environment. On iOS 26.5, StoreKitTest configuration
mutations return error 3 / `notEntitled`, consistent with this
[Apple Developer Forums report](https://developer.apple.com/forums/thread/826971).
That test explicitly skips only the affected 26.5 runtime.

On iOS 18.6, test transactions can be created, but the running app did not
reach a verified Premium state. Both purchase-before-launch and purchase-in-app
attempts failed the entitlement assertion; manual simulator ad-hoc signing did
not fix this. An app-hosted diagnostic transaction read also stalled and was
cancelled. The final test requires visible verified membership before advancing
and retains a failure on runtimes where that assertion fails. Earlier result
attachments from failed runs were actually paywalls and are excluded from the
review gallery.

No purchase bypass, local paid flag, signing change or StoreKit service change
is included. Keep this PR draft until the paid end-to-end test passes using a
working StoreKit environment / sandbox device. Physical-device purchase/restore,
native-speaker wording review and real-device accessibility are release checks.
Android implementation follows Arun's iOS review; no later phase is included.
Logs, red evidence and screenshots remain under ignored
`outputs/premium-birth/`. CI was not run and no merge is authorized.
