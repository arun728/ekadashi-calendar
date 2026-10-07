# Calendar year data

Ekadashi dates ship as one JSON pack per year in `assets/calendar/`
(`2026.json`, `2027.json`, ...), listed in `assets/calendar/manifest.json`.
`CalendarRepository` loads every listed pack at startup and the app merges
them; nothing is filtered by the current year.

The Calendar tab spans 1 January of the first pack to 31 December of the last
pack. Paging from December into January moves the year selector with it, and
choosing a year in the selector opens its January (the current year opens on
today).

To add 2028:

1. Add `assets/calendar/2028.json` in the same format.
2. Add `{ "year": 2028, "asset": "assets/calendar/2028.json" }` to
   `manifest.json`.

No code change is needed. Keep the older packs: past years stay browsable,
and Vrat history, streaks and achievements refer to their dates (they are
stored separately and are never removed by adding or rolling over a year).
