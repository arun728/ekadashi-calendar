package com.applausestudios.ekadashi_calendar

import android.appwidget.AppWidgetManager
import android.content.Context
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import com.applausestudios.ekadashi_calendar.widget.model.*
import com.applausestudios.ekadashi_calendar.widget.provider.EkadashiTodayWidgetReceiver
import com.applausestudios.ekadashi_calendar.widget.storage.WidgetStorage
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import java.time.Instant

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class AfterOnlyParanaWidgetTest {
    @Test fun actualWidgetDisplaysPreciseAfterOnlyTextWithoutEndCountdown() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val now = Instant.now()
        val start = now.minusSeconds(86400).toString()
        val event = EkadashiItem(1,"Review","Review","2026-12-19","19 Dec", "Krishna","Margashirsha",
            start,start,now.minusSeconds(60).toString(),"",
            contextExpiresAtUTC=now.plusSeconds(3600).toString(),paranaWindowText="after 07:00:08 AM")
        val payload = WidgetPayload(WidgetMetadata(generatedAtUTC=now.toString(),lastUpdatedAtUTC=now.toString()),
            WidgetState.PARANA_AVAILABLE,event,upcomingEkadashis=emptyList(),localizedStrings=emptyMap())
        assertTrue(WidgetStorage.getInstance(context).savePayload(payload))
        val manager = AppWidgetManager.getInstance(context)
        val host = Shadows.shadowOf(manager)
        val id = host.createWidget(EkadashiTodayWidgetReceiver::class.java,R.layout.widget_medium)
        EkadashiTodayWidgetReceiver().onUpdate(context,manager,intArrayOf(id))
        val view = host.getViewFor(id)
        assertEquals("after 07:00:08 AM",view.findViewById<TextView>(R.id.widget_medium_parana_time).text.toString())
        assertEquals("Break Fasting (Parana)",view.findViewById<TextView>(R.id.widget_medium_countdown_label).text.toString())
        assertEquals("",view.findViewById<TextView>(R.id.widget_medium_countdown_value).text.toString())
    }
}
