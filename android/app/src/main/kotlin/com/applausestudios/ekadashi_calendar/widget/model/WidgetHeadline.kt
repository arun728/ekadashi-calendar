package com.applausestudios.ekadashi_calendar.widget.model

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/** What the Ekadashi widget leads with (docs/ROADMAP.md Phase 6), as on iOS. */
sealed class WidgetHeadline {
    abstract val item: EkadashiItem

    /** Active fasting or Parana: completed fraction, 0..1 (including overnight). */
    data class Today(override val item: EkadashiItem, val progress: Double, val state: WidgetState = WidgetState.FASTING_ACTIVE) : WidgetHeadline()

    /** The next Ekadashi and the calendar days until it. */
    data class Next(override val item: EkadashiItem, val days: Long, val secondsUntilStart: Long? = null) : WidgetHeadline()

    companion object {
        fun of(payload: WidgetPayload, now: Instant = Instant.now()): WidgetHeadline? {
            val item = WidgetTimeline.remaining(payload, now).firstOrNull() ?: return null
            val today = now.atZone(payload.zoneId()).toLocalDate()
            val days = ChronoUnit.DAYS.between(today, LocalDate.parse(item.date))
            val start = item.fastingStartInstant
            return if (start != null && now >= start) Today(item, item.fastProgress(now), item.stateAt(now))
                else Next(item, days, if (days <= 0 && start != null) ((java.time.Duration.between(now, start).toMillis() + 999) / 1000).coerceAtLeast(0) else null)
        }
    }
}

/** How much of the fast (fasting start to Parana start) has passed. */
fun EkadashiItem.fastProgress(now: Instant): Double {
    val start = fastingStartInstant ?: return 0.0
    val parana = paranaStartInstant ?: return 0.0
    val total = ChronoUnit.SECONDS.between(start, parana).toDouble()
    if (total <= 0) return if (now >= parana) 1.0 else 0.0
    return (ChronoUnit.SECONDS.between(start, now) / total).coerceIn(0.0, 1.0)
}

/** "Today", "Tomorrow" or "14 days to go". */
fun WidgetPayload.daysToGo(days: Long): String = when {
    days <= 0 -> localized("widget.today", "Today")
    days == 1L -> localized("widget.tomorrow", "Tomorrow")
    else -> localized("widget.days_to_go", "{value0} days to go").replace("{value0}", days.toString())
}

private val legacyZones = mapOf(
    "IST" to "Asia/Kolkata", "EST" to "America/New_York", "CST" to "America/Chicago",
    "MST" to "America/Denver", "PST" to "America/Los_Angeles")

/** The schedule's zone; older payloads stored an abbreviation. */
fun WidgetPayload.zoneId(): ZoneId =
    runCatching { ZoneId.of(legacyZones[metadata.timezone] ?: metadata.timezone) }.getOrDefault(ZoneId.of("Asia/Kolkata"))

fun WidgetHeadline.Next.startCountdown(): String? = secondsUntilStart?.let { seconds ->
    "%02d:%02d:%02d".format(java.util.Locale.ROOT, seconds / 3600, seconds / 60 % 60, seconds % 60)
}
