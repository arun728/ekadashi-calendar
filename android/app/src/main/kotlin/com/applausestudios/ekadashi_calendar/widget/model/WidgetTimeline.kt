package com.applausestudios.ekadashi_calendar.widget.model

import java.time.Instant
import java.time.LocalDate

/** Keep the archive in the snapshot so a closed app can roll forward at midnight. */
object WidgetTimeline {
    fun all(payload: WidgetPayload): List<EkadashiItem> =
        (payload.schedule + listOfNotNull(payload.nextEkadashi) + payload.upcomingEkadashis)
            .filter { runCatching { LocalDate.parse(it.date) }.isSuccess }
            .distinctBy { it.occurrenceUid }.sortedBy { it.date }

    fun remaining(payload: WidgetPayload, now: Instant = Instant.now()): List<EkadashiItem> {
        val today = now.atZone(payload.zoneId()).toLocalDate().toString()
        return all(payload).filter { it.paranaEndInstant?.let { end -> now < end } ?: (it.date >= today) }
    }

    fun upcoming(payload: WidgetPayload, now: Instant = Instant.now()): List<EkadashiItem> {
        return all(payload).filter { it.fastingStartInstant?.let { start -> now < start } == true }.take(5)
    }

    /** The system may deliver work later; selection is always evaluated at render time. */
    fun nextRefresh(payload: WidgetPayload, now: Instant = Instant.now()): Instant? {
        if (remaining(payload, now).isEmpty()) return null
        val midnight = now.atZone(payload.zoneId()).toLocalDate().plusDays(1).atStartOfDay(payload.zoneId()).toInstant()
        val boundaries = all(payload).flatMap { listOfNotNull(it.fastingStartInstant, it.paranaStartInstant, it.paranaEndInstant) }
        val progressTick = if (WidgetHeadline.of(payload, now) is WidgetHeadline.Today) now.plusSeconds(900) else midnight
        return (boundaries + midnight + progressTick).filter { it.isAfter(now) }.minOrNull()
    }
}
