# Daily Devotion implementation and release boundaries

Approved 4 October 2026. Base: dev 23a81ce (PR9 merged by Arun).
Work lives on feature/daily-devotion. Do not merge to dev or main.
AGENTS.md was updated and committed before implementation.

## Navigation

Today / Calendar / Practice / Library / Settings retain five destinations.
Today has a daily-practice shortcut; its Ekadashi/parana hero is retained.
Practice holds daily routines/Japa and a direct Vrat journey entry.
Library holds Listen/Learn and global search. Search also has an app-bar entry.
Existing dashboard/today/parana/calendar/vrat/search/settings deep links remain
supported. Search query and calendar selection survive reopening/navigation.
Premium/reward settings remain in Settings. Audio continues between screens
with a mini-player on the main tabs and a full player for queue/repeat/sleep.

## Batch 1

Free: one unscheduled routine, basic 108-count Japa/timer and practice streak.
Premium: additional routines, weekday schedules/reminders, saved named mantra
and mala goals, haptic cues, saved session history and weekly chant insights.
Previously saved goals/history survive expiry; existing personal history remains
readable. Finishing an already-started session preserves its progress.

Practice stores under daily_practice_v1, independently of Vrat and fasting coins.
Writes serialize, duplicate mutation keys do not double count, and unsuccessful
storage writes do not publish success. Corrupt practice data is retained for
recovery rather than silently reset. Changing steps clears obsolete checkmarks.
Reminder planning respects selected weekdays, device timezone/DST, notification
permission/master opt-out and quiet hours (default 22:00–07:00). Its own IDs are
canceled/rebuilt on edits, entitlement changes, locale changes and app resume;
turning the app's notification master off also reconciles practice reminders.
The scheduler refreshes a bounded rolling 14-day horizon while the app runs.
No fasting coins are awarded for chanting, opening the app or routine completion.

## Batch 2

Implemented infrastructure: lazy native audio driver/audio-session focus handling,
free/premium playback gating, a main-tab mini-player, full playback/seek controls,
1/3/9/27/108 cycles, playlist queue, premium sleep timing, verified offline
caching/removal, line-level playback/highlighting hooks, bookmarks and spaced
revision (1/3/7/14/30-day intervals). Learning progress is local and survives
premium expiry. Playlists are current listening queues, not named cloud playlists.

The starter Learn catalog has two traditional invocations with original short
explanations. Sanskrit text/basic meaning is free; transliteration, bookmarks
and spaced revision are premium. Existing bookmarked lines remain readable.

**Production songs, original recitations and pronunciation review are pending.**
The production audio catalog deliberately contains no recordings. Listen says
recordings are being prepared; Learn does not show nonexistent recitation buttons.
This branch is not a complete production devotional audio collection.
Choose commissioned recordings, recordings Arun owns/has cleared, or separately
reviewed original instrumental assets. Never substitute ripped recordings or
unreviewed voice generation. Native CI uses a generated WAV test tone only.

Each audio catalog item must specify rightsCleared, reviewed, provenance,
license, attribution, commercial/offline permission, localized title key,
premium status, secure source and SHA256. Commercial rights/content review are
mandatory; offline rights separately control downloads. Downloads reject
redirects, wrong hashes and oversized bodies and publish only after verification.
The rights manifest gate cannot replace actual rights documents and human review.
Translations and Sanskrit pronunciation need native-speaker/content review.

## Next phase

After these batches are validated, specify the full Panchang engine separately:
astronomical calculations plus regional/tradition-sensitive observance rules,
source/library license, locations, calendar systems and reference fixtures.
Amavasya, Purnima/Pournami, Ekadashi, Dwadashi, Shivaratri, Pradosham and regional
festivals belong in Today and Calendar. Clarify "shiva nami" with Arun.
Do not claim that calculating tithi alone covers all Hindu festivals.

## Validation

See docs/review/daily-devotion-validation.md and the draft PR's exact commit/CI
links. Tests use injected premium server fixtures; real Play checkout is still
a separate internal-track release gate. Native Android CI uses the actual audio
plugin with a test signal. API24/33/35, denied-notification and GPS-off scenarios
remain required before Samsung M52/Z Flip5 checks. No device result is inferred
from a simulator. Production recordings, backend/billing/legal setup, notification
reliability and real interruption/background behavior remain release work.
