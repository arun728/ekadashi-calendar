package com.applausestudios.ekadashi_calendar

import android.appwidget.AppWidgetManager
import android.content.Context
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import com.applausestudios.ekadashi_calendar.widget.model.*
import com.applausestudios.ekadashi_calendar.widget.provider.NextEkadashiWidgetReceiver
import com.applausestudios.ekadashi_calendar.widget.storage.WidgetStorage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import java.time.Instant
import java.time.ZoneOffset

/** Public provider -> cached data -> actual Android RemoteViews, without Flutter. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class WidgetRolloverRegressionTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val now = Instant.now()

    private fun event(id: Int, dayOffset: Long): EkadashiItem {
        val start = now.plusSeconds(dayOffset * 86400)
        val date = start.atOffset(ZoneOffset.UTC).toLocalDate().toString()
        return EkadashiItem(id, "Event $id", "Event $id", date, date,
            "Krishna", "Test month", start.toString(), start.plusSeconds(3600).toString(),
            start.plusSeconds(7200).toString(), start.plusSeconds(10800).toString())
    }

    private fun render(next: EkadashiItem, upcoming: List<EkadashiItem>): String {
        val snapshot = WidgetPayload(
            WidgetMetadata(generatedAtUTC = now.toString(), lastUpdatedAtUTC = now.toString()),
            WidgetState.BEFORE_EKADASHI, next, upcomingEkadashis = upcoming,
            localizedStrings = emptyMap())
        assertTrue(WidgetStorage.getInstance(context).savePayload(snapshot))
        val manager = AppWidgetManager.getInstance(context)
        val host = Shadows.shadowOf(manager)
        val widgetId = host.createWidget(NextEkadashiWidgetReceiver::class.java, R.layout.widget_small)
        // Trigger through the public provider contract, as the launcher does.
        NextEkadashiWidgetReceiver().onUpdate(context, manager, intArrayOf(widgetId))
        return host.getViewFor(widgetId).findViewById<TextView>(R.id.widget_small_name).text.toString()
    }

    @Test fun futureEventRemainsSelected() {
        assertEquals("Event 1", render(event(1, 5), listOf(event(2, 20))))
    }

    @Test fun oneExpiredEventAdvancesToNext() {
        assertEquals("Event 2", render(event(1, -15), listOf(event(2, 5), event(3, 20))))
    }

    @Test fun closedAppSkipsAllExpiredEventsAcrossMultipleUpdates() {
        val a = event(1, -30)
        val b = event(2, -15)
        val c = event(3, 5)
        // With the app closed the stored payload is unchanged between updates.
        repeat(2) { assertEquals("Event 3", render(a, listOf(b, c))) }
    }
}
