package com.applausestudios.ekadashi_calendar

import com.applausestudios.ekadashi_calendar.widget.model.*
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.Instant

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class AfterOnlyParanaTest {
    private fun item() = EkadashiItem.fromJsonObject(JSONObject("""{
      "id":1,"fastingStartUTC":"2026-12-19T12:00:00Z",
      "paranaStartUTC":"2026-12-20T12:00:07.444Z","paranaEndUTC":"",
      "contextExpiresAtUTC":"2026-12-21T05:00:00Z",
      "paranaWindowText":"after 07:00:08 AM"
    }"""))

    @Test fun availableAfterOpeningWithoutInventingAnEnd() {
        val event = item()
        assertEquals(WidgetState.FASTING_ACTIVE, event.stateAt(Instant.parse("2026-12-20T12:00:07.443Z")))
        assertEquals(WidgetState.PARANA_AVAILABLE, event.stateAt(Instant.parse("2026-12-20T12:00:07.444Z")))
        assertNull(event.paranaEndInstant)
        assertEquals(WidgetState.FALLBACK, event.stateAt(Instant.parse("2026-12-21T05:00:00Z")))
    }

    @Test fun timelineAndJsonPreserveAfterOnlyContextAndPreciseDisplay() {
        val event = item()
        val payload = WidgetPayload(WidgetMetadata(generatedAtUTC="2026-12-19T00:00:00Z",lastUpdatedAtUTC="2026-12-19T00:00:00Z"),
            WidgetState.FASTING_ACTIVE,event,upcomingEkadashis=emptyList(),localizedStrings=emptyMap())
        assertEquals(listOf(event), WidgetTimeline.remaining(payload,Instant.parse("2026-12-20T13:00:00Z")))
        assertTrue(WidgetTimeline.remaining(payload,Instant.parse("2026-12-21T05:00:00Z")).isEmpty())
        val json = EkadashiItem.fromJsonObject(event.toJsonObject()).toJsonObject()
        assertEquals("",json.getString("paranaEndUTC"))
        assertEquals("2026-12-21T05:00:00Z",json.getString("contextExpiresAtUTC"))
        assertEquals("after 07:00:08 AM",json.getString("paranaWindowText"))
    }
}
