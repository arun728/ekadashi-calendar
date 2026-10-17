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
        assertTrue("Civil-date today before sunrise", result is WidgetHeadline.Today)
        assertEquals(1.0, (result as WidgetHeadline.Today).progress, 0.001)
    }
    @Test fun progressIsRemainingRatherThanCompleted() {
        val result = WidgetHeadline.of(payload(listOf(event(1, LocalDate.parse("2026-10-22")))), Instant.parse("2026-10-22T12:00:00Z"))
        assertEquals(0.75, (result as WidgetHeadline.Today).progress, 0.001)
    }
    @Test fun yesterdayParanaDoesNotReplaceTheNextEkadashi() {
        val result = WidgetHeadline.of(payload(listOf(event(1, LocalDate.parse("2026-10-22")), event(2, LocalDate.parse("2026-11-05")))), Instant.parse("2026-10-23T01:00:00Z"))
        assertTrue(result is WidgetHeadline.Next)
        assertEquals(2, result!!.item.id)
    }
    @Test fun upcomingIsExactlyFiveFutureDatesWithNearestFirst() {
        val today = LocalDate.now(ZoneOffset.UTC)
        val items = (0..7).map { event(it + 1, today.plusDays(it * 15L)) }
        WidgetStorage.getInstance(context).savePayload(payload(items))
        val factory = EkadashiListRemoteViewsFactory(context, Intent())
        factory.onCreate()
        assertEquals(5, factory.count)
        assertEquals(items[1].id.toLong(), factory.getItemId(0))
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
    @Test fun occurrenceIdentitySurvivesNativeCacheRoundTrip() {
        val original = event(1, LocalDate.parse("2027-01-07")).toJsonObject().put("occurrenceUid", "ekadashi:2027:25")
        assertEquals("ekadashi:2027:25", EkadashiItem.fromJsonObject(original).toJsonObject().optString("occurrenceUid"))
    }
}
