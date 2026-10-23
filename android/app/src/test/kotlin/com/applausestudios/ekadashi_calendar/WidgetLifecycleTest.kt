package com.applausestudios.ekadashi_calendar
import com.applausestudios.ekadashi_calendar.widget.model.*
import org.junit.Assert.*
import org.junit.Test
import java.time.Instant
class WidgetLifecycleTest {
 private val start=Instant.parse("2026-10-22T00:30:00Z")
 private val item=EkadashiItem(20,"Ekadashi","Ekadashi","2026-10-22","22 Oct","","",start.toString(),start.plusSeconds(86400).toString(),start.plusSeconds(86400).toString(),start.plusSeconds(94860).toString())
 private val next=item.copy(id=21,date="2026-11-05",occurrenceUid="ekadashi:2026:21",fastingStartUTC=start.plusSeconds(14*86400).toString(),paranaEndUTC=start.plusSeconds(15*86400+3600).toString())
 private val payload=WidgetPayload(WidgetMetadata(generatedAtUTC=start.toString(),lastUpdatedAtUTC=start.toString(),timezone="Asia/Kolkata"),WidgetState.BEFORE_EKADASHI,item,upcomingEkadashis=listOf(next),localizedStrings=emptyMap())
 @Test fun beforeStartIsCountdownRatherThanActive() {
  val h=WidgetHeadline.of(payload,start.minusSeconds(1))
  assertTrue(h is WidgetHeadline.Next); assertEquals(0L,(h as WidgetHeadline.Next).days)
  assertEquals(item,WidgetTimeline.upcoming(payload,start.minusSeconds(1)).first())
 }
 @Test fun lastFractionalSecondStillShowsOneSecond() {
  val h=WidgetHeadline.of(payload,start.minusMillis(500)) as WidgetHeadline.Next
  assertEquals("00:00:01",h.startCountdown())
 }
 @Test fun fillsAndRetainsCurrentThroughParanaEnd() {
  val halfway=WidgetHeadline.of(payload,start.plusSeconds(43200)) as WidgetHeadline.Today
  assertEquals(.5,halfway.progress,0.00001)
  assertTrue(WidgetHeadline.of(payload,start.plusSeconds(87000)) is WidgetHeadline.Today)
  assertEquals(item,WidgetHeadline.of(payload,start.plusSeconds(94859))?.item)
  assertEquals(next,WidgetHeadline.of(payload,start.plusSeconds(94860))?.item)
 }
}
