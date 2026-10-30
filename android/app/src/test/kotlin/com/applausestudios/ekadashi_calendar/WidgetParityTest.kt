package com.applausestudios.ekadashi_calendar

import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import com.applausestudios.ekadashi_calendar.widget.data.WidgetLocalization
import com.applausestudios.ekadashi_calendar.widget.model.*
import com.applausestudios.ekadashi_calendar.widget.service.EkadashiListRemoteViewsFactory
import com.applausestudios.ekadashi_calendar.widget.storage.WidgetStorage
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class WidgetParityTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private fun event(id: Int, date: LocalDate): EkadashiItem {
        val start = date.atTime(6, 0).toInstant(ZoneOffset.UTC)
        return EkadashiItem(id, "Event $id", "Event $id", date.toString(), date.toString(), "", "",
            start.toString(), start.plusSeconds(86400).toString(), start.plusSeconds(86400).toString(), start.plusSeconds(93600).toString())
    }
    private fun payload(items: List<EkadashiItem>) = WidgetPayload(
        WidgetMetadata(generatedAtUTC = Instant.now().toString(), lastUpdatedAtUTC = Instant.now().toString(), timezone = "UTC"),
        WidgetState.BEFORE_EKADASHI, items.firstOrNull(), upcomingEkadashis = items.drop(1), localizedStrings = emptyMap())

    @Test fun todayStartsAtLocalMidnightBeforeFastingStarts() {
        val day = LocalDate.parse("2026-10-22")
        val result = WidgetHeadline.of(payload(listOf(event(1, day))), Instant.parse("2026-10-22T01:00:00Z"))
        assertTrue("Countdown before sunrise", result is WidgetHeadline.Next)
        assertEquals("05:00:00", (result as WidgetHeadline.Next).startCountdown())
    }
    @Test fun progressIsCompletedRatherThanRemaining() {
        val result = WidgetHeadline.of(payload(listOf(event(1, LocalDate.parse("2026-10-22")))), Instant.parse("2026-10-22T12:00:00Z"))
        assertEquals(0.25, (result as WidgetHeadline.Today).progress, 0.001)
    }
    @Test fun ongoingOvernightFastRemainsCurrent() {
        val result = WidgetHeadline.of(payload(listOf(event(1, LocalDate.parse("2026-10-22")), event(2, LocalDate.parse("2026-11-05")))), Instant.parse("2026-10-23T01:00:00Z"))
        assertTrue(result is WidgetHeadline.Today)
        assertEquals(1, result!!.item.id)
    }
    @Test fun upcomingIsExactlyFiveFutureDatesWithNearestFirst() {
        val today = LocalDate.now(ZoneOffset.UTC)
        // The first fast has already started at every UTC test-run hour.
        // Starting it at today's 06:00 made this assertion fail before 06:00,
        // when including that same-day future start is the correct behavior.
        val items = (0..7).map { event(it + 1, today.minusDays(1).plusDays(it * 15L)) }
        WidgetStorage.getInstance(context).savePayload(payload(items))
        val factory = EkadashiListRemoteViewsFactory(context, Intent())
        factory.onCreate()
        assertEquals(5, factory.count)
        assertEquals(items[1].id.toLong(), factory.getItemId(0))
    }
    @Test fun staleFrameworkRowRequestsNeverReturnNullAfterAnEmptyRefreshOrDestroy() {
        val day = LocalDate.now(ZoneOffset.UTC)
        val storage = WidgetStorage.getInstance(context)
        storage.savePayload(payload((1..6).map { event(it, day.plusDays(it * 15L)) }))
        val factory = EkadashiListRemoteViewsFactory(context, Intent())
        factory.onCreate()
        assertEquals(5, factory.count)
        storage.savePayload(payload(emptyList()))
        factory.onDataSetChanged()
        assertEquals(0, factory.count)
        val row = factory.getViewAt(4)
        assertNotNull("Android 16 parcels late collection rows without checking null", row)
        val view = row.apply(context, android.widget.FrameLayout(context))
        assertEquals("", view.findViewById<android.widget.TextView>(R.id.widget_upcoming_item_name).text.toString())
        assertEquals("", view.findViewById<android.widget.TextView>(R.id.widget_upcoming_item_date).text.toString())
        assertFalse(view.performClick())
        factory.onDestroy()
        assertNotNull(factory.getViewAt(0))
    }
    @Test fun nativeFallbacksHaveAllCountdownAndProgressTranslations() {
        for (language in listOf("en", "hi", "ta", "te", "gu", "bn")) {
            val strings = WidgetLocalization.strings(context, language)
            for (key in listOf("widget.today_is_ekadashi", "widget.tomorrow", "widget.days_to_go", "widget.remaining")) {
                val value = strings[key]
                assertFalse("$language $key missing", value.isNullOrBlank())
                if (language != "en" && value != null) assertFalse("$language $key leaks English", Regex("[A-Za-z]").containsMatchIn(value.replace("{value0}", "")))
            }
        }
    }
    @Test fun legacyEngineCacheRecoversTheYearScopedOccurrenceIdentity() {
        val old = event(2027001, LocalDate.parse("2027-01-07")).toJsonObject()
        old.remove("occurrenceUid")
        assertEquals("ekadashi:2027:01", EkadashiItem.fromJsonObject(old).occurrenceUid)
    }
    @Test fun occurrenceIdentitySurvivesNativeCacheRoundTrip() {
        val original = event(1, LocalDate.parse("2027-01-07")).toJsonObject().put("occurrenceUid", "ekadashi:2027:25")
        assertEquals("ekadashi:2027:25", EkadashiItem.fromJsonObject(original).toJsonObject().optString("occurrenceUid"))
    }
}
