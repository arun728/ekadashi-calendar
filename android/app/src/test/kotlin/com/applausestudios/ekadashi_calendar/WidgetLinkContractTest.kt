package com.applausestudios.ekadashi_calendar

import android.app.Application
import android.content.Context
import android.widget.FrameLayout
import androidx.test.core.app.ApplicationProvider
import com.applausestudios.ekadashi_calendar.widget.model.*
import com.applausestudios.ekadashi_calendar.widget.ui.WidgetRenderer
import com.applausestudios.ekadashi_calendar.widget.data.WidgetLocalization
import com.applausestudios.ekadashi_calendar.widget.storage.WidgetStorage
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35])
class WidgetLinkContractTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val now = Instant.parse("2026-10-17T12:00:00Z")
    private fun payload(): WidgetPayload {
        val start = Instant.parse("2027-01-07T06:00:00Z")
        val item = EkadashiItem(2501,"Name","Name","2027-01-07","","","",start.toString(), start.plusSeconds(86400).toString(),
            start.plusSeconds(86400).toString(),start.plusSeconds(93600).toString(),occurrenceUid="ekadashi:2027:25")
        return WidgetPayload(WidgetMetadata(generatedAtUTC=now.toString(),lastUpdatedAtUTC=now.toString(),timezone="UTC"),
            WidgetState.BEFORE_EKADASHI,item,upcomingEkadashis=emptyList(),localizedStrings=emptyMap(),schedule=listOf(item))
    }
    @Test fun bothHomeSizesAndUpcomingHeadingLaunchTheDisplayedOccurrence() {
        val p = payload()
        for (width in listOf(140, 320)) {
            val view = WidgetRenderer.single(context,p,width,170,now).apply(context,FrameLayout(context))
            assertTrue(view.performClick())
            val intent = Shadows.shadowOf(context as Application).nextStartedActivity
            assertEquals("ekadashi",intent.data!!.host)
            assertEquals("ekadashi:2027:25",intent.data!!.getQueryParameter("uid"))
        }
        val view = WidgetRenderer.upcoming(context,p,now=now).apply(context,FrameLayout(context))
        view.findViewById<android.view.View>(R.id.widget_large_upcoming_header).performClick()
        assertEquals("ekadashi:2027:25",Shadows.shadowOf(context as Application).nextStartedActivity.data!!.getQueryParameter("uid"))
    }
    @Test fun exhaustedCalendarShowsTheLocalizedNoUpcomingMessage() {
        val p = payload()
        val view = WidgetRenderer.single(context,p,320,170,Instant.parse("2028-01-01T00:00:00Z")).apply(context,FrameLayout(context))
        assertEquals(WidgetLocalization.strings(context,"en")["widget.no_next"], view.findViewById<android.widget.TextView>(R.id.widget_medium_date).text.toString())
    }
    @Test fun tappingUpcomingCardBackgroundOpensItsFirstDisplayedOccurrence() {
        val view = WidgetRenderer.upcoming(context,payload(),now=now).apply(context,FrameLayout(context))
        assertTrue(view.performClick())
        assertEquals("ekadashi:2027:25",Shadows.shadowOf(context as Application).nextStartedActivity.data!!.getQueryParameter("uid"))
    }
    @Test fun missingAndCorruptedCacheUseOnlyLocalizedRefreshFallbacks() {
        for (language in listOf("hi","ta","te","gu","bn")) {
            context.getSharedPreferences("FlutterSharedPreferences",Context.MODE_PRIVATE).edit().putString("flutter.language_code",language).commit()
            val storage = WidgetStorage.getInstance(context)
            storage.clearPayload()
            assertEquals(language, WidgetLocalization.locale(context))
            val result = storage.loadPayload()
            assertEquals(language, result.payload.metadata.locale)
            assertFalse(result.status.canDisplay)
            assertTrue(WidgetTimeline.all(result.payload).isEmpty())
            assertEquals("",result.payload.metadata.locationName)
            assertEquals(WidgetLocalization.strings(context,language)["widget.open_app_to_refresh"],result.payload.localizedStrings["widget.open_app_to_refresh"])
        }
    }
    @Test fun archiveRollsPastTheFiveVisibleDatesAcrossYearsAndSurvivesCacheRoundTrip() {
        val p = payload(); val first=p.nextEkadashi!!
        val later=first.copy(id=2601,date="2028-01-01",occurrenceUid="ekadashi:2028:01")
        val archive=p.copy(schedule=listOf(first,later))
        val restored=WidgetPayload.fromJsonString(archive.toJsonString())
        assertEquals(later.occurrenceUid,WidgetHeadline.of(restored,Instant.parse("2027-12-31T12:00:00Z"))!!.item.occurrenceUid)
    }
}
