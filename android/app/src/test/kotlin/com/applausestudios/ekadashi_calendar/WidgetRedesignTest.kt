package com.applausestudios.ekadashi_calendar
import android.appwidget.AppWidgetManager
import android.content.Context
import android.view.View
import android.widget.ProgressBar
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import com.applausestudios.ekadashi_calendar.widget.model.*
import com.applausestudios.ekadashi_calendar.widget.provider.*
import com.applausestudios.ekadashi_calendar.widget.storage.WidgetStorage
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** Phase 6 (docs/ROADMAP.md): an Ekadashi widget and an Upcoming list. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk=[28,35])
class WidgetRedesignTest {
 private val context=ApplicationProvider.getApplicationContext<Context>()
 private val now=Instant.now()
 private val zone=ZoneId.of("Asia/Kolkata")
 private val strings=mapOf(
  "widget.next_ekadashi" to "Next Ekadashi","widget.today_is_ekadashi" to "Today is Ekadashi",
  "widget.days_to_go" to "{value0} days to go","widget.tomorrow" to "Tomorrow","widget.today" to "Today",
  "widget.parana_in" to "Parana in","widget.parana_ends" to "Parana ends",
  "widget.upcoming_ekadashis" to "Upcoming Ekadashis","widget.fast_done" to "{value0}% of the fast done")
 /** An Ekadashi whose fast starts [startOffset] seconds from now and lasts a day. */
 private fun event(id:Int,startOffset:Long):EkadashiItem {
  val start=now.plusSeconds(startOffset);val parana=start.plusSeconds(86400)
  return EkadashiItem(id,"Event $id","Event $id",start.atZone(zone).toLocalDate().toString(),"","Shukla","",
   start.toString(),parana.toString(),parana.toString(),parana.plusSeconds(10800).toString())
 }
 private fun payload(vararg events:EkadashiItem)=WidgetPayload(
  WidgetMetadata(generatedAtUTC=now.toString(),lastUpdatedAtUTC=now.toString(),locale="en",timezone="Asia/Kolkata"),
  events.firstOrNull()?.stateAt(now)?:WidgetState.FALLBACK,events.firstOrNull(),upcomingEkadashis=events.drop(1),localizedStrings=strings)
 private fun render(provider:EkadashiWidgetReceiver,p:WidgetPayload):View {
  assertTrue(WidgetStorage.getInstance(context).savePayload(p))
  val manager=AppWidgetManager.getInstance(context);val host=Shadows.shadowOf(manager)
  val id=host.createWidget(provider.javaClass,R.layout.widget_small)
  provider.onUpdate(context,manager,intArrayOf(id));return host.getViewFor(id)
 }
 private fun text(view:View,id:Int)=view.findViewById<TextView>(id).text.toString()

 @Test fun headlineShowsTodayWithFastProgressDuringTheFast() {
  val headline=WidgetHeadline.of(payload(event(1,-21600)),now)
  assertTrue(headline is WidgetHeadline.Today)
  assertEquals(0.25,(headline as WidgetHeadline.Today).progress,0.01)
 }
 @Test fun headlineShowsNextWithCalendarDaysToGo() {
  val e=event(1,14*86400L)
  val headline=WidgetHeadline.of(payload(e),now) as WidgetHeadline.Next
  assertEquals(java.time.temporal.ChronoUnit.DAYS.between(now.atZone(zone).toLocalDate(),LocalDate.parse(e.date)),headline.days)
  val p=payload(e)
  assertEquals("Today",p.daysToGo(0));assertEquals("Tomorrow",p.daysToGo(1));assertEquals("14 days to go",p.daysToGo(14))
 }
 @Test fun ekadashiWidgetLeadsWithTodayAndProgressDuringTheFast() {
  val view=render(NextEkadashiWidgetReceiver(),payload(event(1,-21600)))
  assertEquals("Today is Ekadashi",text(view,R.id.widget_small_badge))
  assertEquals("Event 1",text(view,R.id.widget_small_name))
  assertEquals("Parana in",text(view,R.id.widget_small_countdown_label))
  val progress=view.findViewById<ProgressBar>(R.id.widget_small_progress)
  assertEquals(View.VISIBLE,progress.visibility)
  assertEquals(25.0,progress.progress.toDouble(),2.0)
 }
 @Test fun ekadashiWidgetShowsNextEkadashiAndDaysToGo() {
  val e=event(1,14*86400L)
  val view=render(NextEkadashiWidgetReceiver(),payload(e))
  val days=java.time.temporal.ChronoUnit.DAYS.between(now.atZone(zone).toLocalDate(),LocalDate.parse(e.date))
  assertEquals("Next Ekadashi",text(view,R.id.widget_small_badge))
  assertEquals("$days days to go",text(view,R.id.widget_small_countdown_value))
  assertEquals(View.GONE,view.findViewById<ProgressBar>(R.id.widget_small_progress).visibility)
 }
 @Test fun retiredTodayWidgetKeepsWorkingWithTheEkadashiLayout() {
  val view=render(EkadashiTodayWidgetReceiver(),payload(event(1,-21600)))
  assertEquals("Today is Ekadashi",text(view,R.id.widget_small_badge))
 }
 @Test fun upcomingWidgetIsAListWithoutTheHeroCard() {
  val view=render(UpcomingEkadashisWidgetReceiver(),payload(event(1,86400),event(2,15*86400L)))
  assertEquals("Upcoming Ekadashis",text(view,R.id.widget_large_upcoming_header))
  assertEquals(View.GONE,view.findViewById<View>(R.id.widget_large_hero_card).visibility)
 }
}
