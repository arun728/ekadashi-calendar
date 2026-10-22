# Android follow-up requested 22 October 2026

Implemented on Android on 22 October 2026 after approval, on PR #24:

1. **Home progress:** only the viewed Ekadashi whose civil date is today in
   the Home city's time zone gets a remaining-fast percentage ring. Place the
   ring on the left and keep Today on the right, above the full-width date and
   name. Match widgets' fasting-start-to-Parana-start calculation, including
   100% before sunrise and removal on the next civil date. Past/future cards
   have no ring. Cover both traditions, all six languages and text sizes.
2. **Blocked Home observance action:** retain the grey appearance next to
   Share, but accept an informational tap before recording opens. Show the
   existing translated “You can record this fast once Parana begins” message.
   Cover today's and future occurrences in both traditions; keep normal record
   and edit actions after Parana and for existing records.
3. **Calendar time localization:** localize both AM/PM markers in the complete
   break-fast window, just like Start Fasting and Home. Cover every supported
   language, AM and PM, both traditions and both time endpoints.
4. **Home tradition choice:** put Vaishnava first, Smarta second, and use
   Vaishnava as the default when no valid explicit preference is saved. Keep
   users able to select and save either tradition. Verify schedule, Calendar,
   reminders and widgets follow the selection.

Use TDD when implementing these. The iOS-only Today Medium widget footer-spacing
adjustment is not an Android Home Screen widget redesign request.

TDD evidence: `9cc2eed` records the missing ring, blocked-button callback and old default. First implementation gates: Flutter **769 passed**, analyzer **no issues**, Swift core **270 passed**. Calendar already used the complete-window localization helper; six-language/both-tradition rendered-card tests now guard it. Fixed-clock tests also cover minute refresh, Home-city midnight, timing boundaries and 0/72/100 percent at large text sizes. Android widget designs are unchanged.
