# Amavasya/Purnima event dates and observance filters

Baseline: dev `2d8f01b6a271aed214acb58219594b241f4a9065`.
Scope: iOS and Android, 2026 and 2027, arbitrary supported locations/timezones.

## Behaviour

- Generic Amavasya and Purnima events appear once per occurrence, on the selected location's local civil date containing the tithi start. For example, Chennai's November 2026 Amavasya event moves from 9 November to 8 November.
- This is an event-date policy. It does not redefine ritual Vrat dates or change the daily tithi at sunrise, its start/end instants, or any astronomical calculations.
- Local midnight-to-midnight intervals use the location's IANA timezone, including DST. These two event types no longer require sunrise/sunset, so they remain available during polar day/night.
- All explicit category filters and type-only searches classify festival-tagged items under Festivals. Other lunar/monthly tags still support full-name searches such as "Guru Purnima" on All. Search and Panchang Key days share the classification rule.
- The shared catalogue displays "Monthly Vinayaka Chaturthi" in all six app languages. The annual Ganesh Chaturthi keeps its existing title and date. Existing aliases remain searchable.
- Other observance rules, both Ekadashi traditions, festival dates and year availability remain unchanged. Chennai retains Naraka Chaturdashi on 28 October 2027 and Deepavali/Lakshmi Puja on 29 October 2027.
- Reminder calculations automatically consume the corrected monthly event dates. Their production scheduling logic is unchanged; regression expectations cover the new date, notification text and destination link.

## TDD and regression evidence

Tests were committed before implementation in `f6d3ba9` (`Failing tests: lunar start dates, monthly naming and exclusive filters [skip ci]`). Before the fix, the new Flutter tests recorded 29 failed / 1 passed; Swift recorded 72 failed assertions across the 5 selected tests, including the intended date, polar, filtering and naming discrepancies.

The shared regression fixture records all 50 tithi intervals for these two years from the unchanged dev engine, plus every other Chennai observance ID on all 730 days. Expected event dates are the recorded start instants converted independently through the selected location timezone.

Full-year coverage runs for Chennai, Dubai, Singapore, Manchester, New York, Toronto, Durban, Melbourne, Tromso, Kiritimati, Honolulu, Kathmandu and Chatham. This exercises positive/negative and fractional offsets, DST, local midnight, calendar-year membership, date-line locations and polar conditions. It is representative global validation of one shared algorithm, not an external astronomical certification of every city.

The final full suites pass: **988 Flutter tests and 340 Swift tests**. The focused new suites pass (30 Flutter tests and 5 Swift tests). Native iOS Search UI regression passes (1 test); the Android emulator Search regressions pass (3 tests). Flutter analyzer is clean. Android debug APK, iOS simulator app and signed iOS device app build successfully. The signed device build was installed and launched successfully on the requested iPhone. An existing city-search latency test failed during concurrent VM/build load, then passed in isolation and in the final clean full Flutter run after those VMs stopped; no timing threshold or city-search implementation was changed.

Additional checks enforce the astronomy constraint:

- The repository accuracy exporter was rerun for all 730 days in Chennai, New Delhi and Bengaluru: all 2,190 daily astronomical records and both Ekadashi schedules are exactly identical to dev. Only generic Amavasya/Purnima event sets differ.
- Regenerated cross-platform parity covers 112 dates: every astronomical field, every other observance and both-tradition fasting outputs remain identical. Only generic lunar entries change on 8 sampled city-days.
- The unchanged-astronomy regression also checks all 50 tithi start/end boundaries within 0.01 seconds of the pre-implementation snapshot.
- The astronomical calculators, solar/lunar series and Ekadashi calculation sources have no changes against dev.

No CI was triggered. Commits use `[skip ci]`. The PR remains draft and no merge is performed.
