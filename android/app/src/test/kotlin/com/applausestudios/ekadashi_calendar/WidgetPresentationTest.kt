package com.applausestudios.ekadashi_calendar

import android.content.Context
import android.content.res.Configuration
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import android.widget.ProgressBar
import android.widget.ListView
import androidx.test.core.app.ApplicationProvider
import com.applausestudios.ekadashi_calendar.widget.model.*
import com.applausestudios.ekadashi_calendar.widget.data.WidgetLocalization
import com.applausestudios.ekadashi_calendar.widget.ui.WidgetRenderer
import com.applausestudios.ekadashi_calendar.widget.ui.WidgetPreviewHost
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class WidgetPresentationTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val day = LocalDate.parse("2026-10-22")
    private val now = Instant.parse("2026-10-22T12:00:00Z")
    private fun payload(language: String = "en"): WidgetPayload {
        val name = WidgetLocalization.strings(context, language).getValue("widget.upcoming_ekadashis")
        val items = (0..7).map { i ->
            val date = day.plusDays(i * 15L); val start = date.atTime(6, 0).toInstant(ZoneOffset.UTC)
            EkadashiItem(i + 1, name.repeat(2), name.repeat(2), date.toString(), "", "", "", start.toString(),
                start.plusSeconds(86400).toString(), start.plusSeconds(86400).toString(), start.plusSeconds(93600).toString(),
                occurrenceUid = "ekadashi:${date.year}:${i + 1}")
        }
        return WidgetPayload(WidgetMetadata(generatedAtUTC = now.toString(), lastUpdatedAtUTC = now.toString(), locale = language, timezone = "UTC", locationName = name),
            WidgetState.FASTING_ACTIVE, items.first(), upcomingEkadashis = items.drop(1), localizedStrings = WidgetLocalization.strings(context, language), schedule = items)
    }
    @Test @Config(sdk = [35]) fun installedUpcomingRowsAndHeadingShareOneImmutableLanguageSnapshot() {
        val english = payload("en")
        val views = WidgetRenderer.upcoming(context, english, appWidgetId = 42, now = now)
        com.applausestudios.ekadashi_calendar.widget.storage.WidgetStorage.getInstance(context).savePayload(payload("bn"))
        val root = views.apply(context, android.widget.FrameLayout(context))
        val list = root.findViewById<ListView>(R.id.widget_large_list)
        assertNotNull("Embed five snapshot rows with the header instead of asynchronously loading another locale", list.adapter)
        assertEquals(5, list.adapter.count)
        val row = list.adapter.getView(0, null, list)
        assertEquals(WidgetTimeline.upcoming(english, now).first().localizedName,
            row.findViewById<TextView>(R.id.widget_upcoming_item_name).text.toString())
        assertEquals(english.localized("widget.upcoming_ekadashis"), root.findViewById<TextView>(R.id.widget_large_upcoming_header).text.toString())
    }
    @Test fun refreshIncludesMidnightBoundariesAndProgressTicksInTheScheduleZone() {
        val p = payload()
        assertEquals(Instant.parse("2026-10-22T12:15:00Z"), WidgetTimeline.nextRefresh(p, now))
        assertEquals(Instant.parse("2026-10-23T00:00:00Z"), WidgetTimeline.nextRefresh(p, Instant.parse("2026-10-22T23:59:00Z")))
        val west = p.copy(metadata = p.metadata.copy(timezone = "America/Los_Angeles"))
        assertEquals(Instant.parse("2026-10-22T07:00:00Z"), WidgetTimeline.nextRefresh(west, Instant.parse("2026-10-22T06:59:00Z")))
        assertNull(WidgetTimeline.nextRefresh(p, Instant.parse("2028-01-01T00:00:00Z")))
    }
    @Test fun previewUsesTheRealNativeLayoutsAndOccurrenceClicks() {
        val p = payload(); var opened = ""
        val host = WidgetPreviewHost(context) { opened = it }
        host.update(p, false, 140, 160, now)
        assertEquals(75, host.findViewById<ProgressBar>(R.id.widget_small_progress).progress)
        assertTrue(host.findViewById<TextView>(R.id.widget_small_countdown_value).text.contains("75%"))
        host.findViewById<View>(R.id.widget_small_root).performClick()
        assertEquals(p.nextEkadashi!!.occurrenceUid, opened)
        host.update(p, true, 320, 280, now)
        val list = host.findViewById<ListView>(R.id.widget_large_list)
        assertEquals(5, list.adapter.count)
        val row = list.adapter.getView(4, null, list)
        row.performClick()
        assertEquals(p.schedule[5].occurrenceUid, opened)
    }
    @Test fun mediumShowsBothFullTimesWithoutEllipsisInEveryLanguage() {
        for (language in listOf("en", "hi", "ta", "te", "gu", "bn")) {
            val host = WidgetPreviewHost(context) {}
            host.update(payload(language), false, 300, 160, now)
            layout(host, 300, 160)
            val time = host.findViewById<TextView>(R.id.widget_medium_parana_time)
            for (line in 0 until minOf(time.layout.lineCount, time.maxLines)) {
                assertEquals("$language complete Parana window: ${time.text}", 0, time.layout.getEllipsisCount(line))
            }
        }
    }
    @Test fun smallCountdownKeepsItsFullLocalizedDaysAndRemainingText() {
        for (language in listOf("en", "hi", "ta", "te", "gu", "bn")) for (fontScale in listOf(1f, 1.3f)) {
            val config = Configuration(context.resources.configuration).apply { this.fontScale = fontScale }
            val localized = context.createConfigurationContext(config)
            for ((width, height) in listOf(158 to 158, 110 to 110, 110 to 60)) {
                for (daysBefore in listOf(0L, 1L, 4L, 30L)) {
                    val host = WidgetPreviewHost(localized) {}
                    host.update(payload(language), false, width, height, now.minusSeconds(daysBefore * 86400))
                    layout(host, width, height)
                    val countdown = host.findViewById<TextView>(R.id.widget_small_countdown_value)
                    assertTrue("$language countdown has content", countdown.text.isNotBlank())
                    for (line in 0 until minOf(countdown.layout.lineCount, countdown.maxLines)) {
                        assertEquals("$language $width/$height scale=$fontScale complete countdown: ${countdown.text}",
                            0, countdown.layout.getEllipsisCount(line))
                    }
                    assertTextBounds(host, "full countdown $language $width/$height scale=$fontScale")
                }
            }
        }
    }
    @Test fun smallestUpcomingPlacementStillHasRoomForOneWholeScrollableRow() {
        for (language in listOf("en", "hi", "ta", "te", "gu", "bn")) {
            val host = WidgetPreviewHost(context) {}
            host.update(payload(language), true, 180, 80, now)
            layout(host, 180, 80)
            val list = host.findViewById<ListView>(R.id.widget_large_list)
            val row = list.adapter.getView(0, null, list)
            layout(row, 154, 0)
            assertTrue("$language must have a readable upcoming row at minimum size", list.height >= row.measuredHeight)
        }
    }
    @Test fun sixLanguagesFitNativeHomeAndLockHostSizesAndLargerFonts() {
        for (language in listOf("en", "hi", "ta", "te", "gu", "bn")) for (fontScale in listOf(1f, 1.3f)) {
            val configuration = Configuration(context.resources.configuration).apply { this.fontScale = fontScale }
            val localized = context.createConfigurationContext(configuration)
            for ((width, height) in listOf(110 to 110, 140 to 160, 250 to 110, 300 to 160, 320 to 240, 110 to 60)) {
                for (clock in listOf(now, now.minusSeconds(86400))) {
                    val host = WidgetPreviewHost(localized) {}
                    host.update(payload(language), false, width, height, clock)
                    layout(host, width, height)
                    assertTextBounds(host, "$language $width/$height scale=$fontScale")
                }
            }
            for (height in listOf(160, 280)) {
                val host = WidgetPreviewHost(localized) {}
                host.update(payload(language), true, 320, height, now)
                layout(host, 320, height)
                val list = host.findViewById<ListView>(R.id.widget_large_list)
                assertEquals(5, list.adapter.count)
                for (i in 0 until list.adapter.count) {
                    val row = list.adapter.getView(i, null, list); layout(row, 294, 0)
                    assertTextBounds(row, "upcoming $language $i")
                }
            }
        }
    }
    private fun layout(view: View, width: Int, height: Int) {
        val density = view.resources.displayMetrics.density
        view.measure(View.MeasureSpec.makeMeasureSpec((width * density).toInt(), View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec((height * density).toInt(), if (height == 0) View.MeasureSpec.UNSPECIFIED else View.MeasureSpec.EXACTLY))
        view.layout(0, 0, view.measuredWidth, view.measuredHeight)
    }
    private fun assertTextBounds(root: View, label: String) {
        fun check(view: View, x: Int, y: Int) {
            if (view.visibility != View.VISIBLE) return
            if (view is TextView && view.text.isNotEmpty()) {
                assertTrue("$label right: ${view.text}", x + view.width <= root.width + 1)
                assertTrue("$label bottom: ${view.text}", y + view.height <= root.height + 1)
                val lines = view.layout
                if (lines != null && lines.lineCount > 0) assertTrue("$label text clipped: ${view.text} size=${view.textSize} box=${view.width}x${view.height} line=${lines.getLineBottom(minOf(lines.lineCount, view.maxLines) - 1)} pad=${view.compoundPaddingTop + view.compoundPaddingBottom}",
                    lines.getLineBottom(minOf(lines.lineCount, view.maxLines) - 1) <= view.height - view.compoundPaddingTop - view.compoundPaddingBottom + 2)
            }
            if (view is ViewGroup) for (i in 0 until view.childCount) {
                val child = view.getChildAt(i)
                check(child, x + child.left, y + child.top)
            }
        }
        check(root, 0, 0)
    }
}
