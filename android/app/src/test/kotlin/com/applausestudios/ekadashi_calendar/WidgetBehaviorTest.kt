package com.applausestudios.ekadashi_calendar
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.res.Configuration
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import com.applausestudios.ekadashi_calendar.widget.model.*
import com.applausestudios.ekadashi_calendar.widget.provider.*
import com.applausestudios.ekadashi_calendar.widget.storage.WidgetStorage
import com.applausestudios.ekadashi_calendar.widget.deeplink.WidgetDeepLinks
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import java.time.Instant
import java.time.ZoneOffset
import java.util.Locale
@RunWith(RobolectricTestRunner::class)
@Config(sdk=[28,35])
class WidgetBehaviorTest {
 private val context=ApplicationProvider.getApplicationContext<Context>()
 private val now=Instant.now()
 private fun event(id:Int,offset:Long):EkadashiItem {
  val start=now.plusSeconds(offset)
  return EkadashiItem(id,"Event $id","వైకుంఠ ఏకాదశి",start.atOffset(ZoneOffset.UTC).toLocalDate().toString(),"జనవరి 2027","శుక్ల","పుష్య",start.toString(),start.plusSeconds(86400).toString(),start.plusSeconds(86400).toString(),start.plusSeconds(90000).toString())
 }
 private fun payload(e:EkadashiItem?,strings:Map<String,String>)=WidgetPayload(WidgetMetadata(generatedAtUTC=now.toString(),lastUpdatedAtUTC=now.toString(),locale="te",timezone="Asia/Kolkata"),e?.stateAt(now)?:WidgetState.FALLBACK,e,upcomingEkadashis=emptyList(),localizedStrings=strings)
 private fun render(provider:EkadashiWidgetReceiver,layout:Int,p:WidgetPayload):android.view.View {
  assertTrue(WidgetStorage.getInstance(context).savePayload(p))
  val manager=AppWidgetManager.getInstance(context);val host=Shadows.shadowOf(manager)
  val id=host.createWidget(provider.javaClass,layout)
  provider.onUpdate(context,manager,intArrayOf(id));return host.getViewFor(id)
 }
 @Test fun allThreeProvidersUseTranslatedHeadingsAndNames() {
  val strings=mapOf("widget.next_ekadashi" to "తదుపరి ఏకాదశి","widget.today_title" to "నేటి ఏకాదశి","widget.fasting_starts" to "ఉపవాస ప్రారంభం","widget.parana_window" to "పారణ సమయం","widget.starts_in" to "ప్రారంభానికి మిగిలిన సమయం")
  val p=payload(event(2027001,86400),strings)
  val small=render(NextEkadashiWidgetReceiver(),R.layout.widget_small,p)
  assertEquals(strings["widget.next_ekadashi"],small.findViewById<TextView>(R.id.widget_small_badge).text.toString())
  assertEquals("వైకుంఠ ఏకాదశి",small.findViewById<TextView>(R.id.widget_small_name).text.toString())
  val medium=render(EkadashiTodayWidgetReceiver(),R.layout.widget_medium,p)
  assertEquals(strings["widget.fasting_starts"],medium.findViewById<TextView>(R.id.widget_medium_fasting_label).text.toString())
  val large=render(UpcomingEkadashisWidgetReceiver(),R.layout.widget_large,p)
  assertEquals(strings["widget.next_ekadashi"],large.findViewById<TextView>(R.id.widget_large_hero_title).text.toString())
  assertEquals(strings["widget.parana_window"],large.findViewById<TextView>(R.id.widget_large_parana_label).text.toString())
 }
 @Test fun allThreeProvidersShowSafeTranslatedEmptyState() {
  val p=payload(null,mapOf("widget.notice" to "సూచన","widget.title" to "ఏకాదశి క్యాలెండర్","widget.open_app_to_refresh" to "యాప్ తెరవండి"))
  val modes=listOf(Triple(NextEkadashiWidgetReceiver(),R.layout.widget_small,R.id.widget_small_name),Triple(EkadashiTodayWidgetReceiver(),R.layout.widget_medium,R.id.widget_medium_name),Triple(UpcomingEkadashisWidgetReceiver(),R.layout.widget_large,R.id.widget_large_hero_name))
  modes.forEach { (provider,layout,name) -> assertEquals("ఏకాదశి క్యాలెండర్",render(provider,layout,p).findViewById<TextView>(name).text.toString()) }
 }
 @Test fun transitionBoundariesAreExclusiveAtParanaEnd() {
  val e=event(1,-100)
  assertEquals(WidgetState.BEFORE_EKADASHI,e.stateAt(e.fastingStartInstant!!.minusSeconds(1)))
  assertEquals(WidgetState.FASTING_ACTIVE,e.stateAt(e.fastingStartInstant!!))
  assertEquals(WidgetState.PARANA_AVAILABLE,e.stateAt(e.paranaStartInstant!!))
  assertEquals(WidgetState.PARANA_COMPLETED,e.stateAt(e.paranaEndInstant!!))
 }
 @Test fun widgetPickerNamesHaveNativeTranslationsForAllSupportedLanguages() {
  for(code in listOf("ta","hi","te")) {
   val config=Configuration(context.resources.configuration);config.setLocale(Locale(code))
   val localized=context.createConfigurationContext(config)
   assertNotEquals("Next Ekadashi",localized.getString(R.string.widget_a_title))
   assertNotEquals("Ekadashi Today",localized.getString(R.string.widget_b_title))
   assertNotEquals("Upcoming Ekadashis",localized.getString(R.string.widget_c_title))
  }
 }
 @Test fun upcomingTapContainsFullYearDate() {
  assertEquals("ekadashi://calendar?date=2027-01-07",WidgetDeepLinks.buildCalendarUri("2027-01-07").toString())
 }
}
