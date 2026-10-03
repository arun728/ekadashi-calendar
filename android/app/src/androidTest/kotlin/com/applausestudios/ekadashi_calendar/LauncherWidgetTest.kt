package com.applausestudios.ekadashi_calendar

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.uiautomator.*
import com.applausestudios.ekadashi_calendar.widget.model.WidgetPayload
import com.applausestudios.ekadashi_calendar.widget.refresh.WidgetRefreshManager
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
import java.io.File

/** Real stock-launcher binding/rendering/taps, using production providers and views.
 * Run after the Flutter integration run creates four locale fixtures in the durable databases directory.
 * This clears the dedicated emulator's Launcher3 data; never run on a user's phone.
 */
@RunWith(AndroidJUnit4::class)
class LauncherWidgetTest {
 private val instrumentation=InstrumentationRegistry.getInstrumentation()
 private val context=instrumentation.targetContext
 private val device=UiDevice.getInstance(instrumentation)
 private val packageName=context.packageName
 private val manager=AppWidgetManager.getInstance(context)
 private val output=File(context.getExternalFilesDir(null),"widget-evidence").apply { mkdirs() }
 private fun capture(name:String) { assertTrue(device.takeScreenshot(File(output,"$name.png"))) }
 private fun home(){device.pressHome();device.waitForIdle(1000)}
 private fun addWidget(label:String,receiver:String):Int {
  // A clean home page prevents overlap from obscuring screenshots or tap targets.
  device.executeShellCommand("pm clear com.android.launcher3")
  home()
  val width=device.displayWidth;val height=device.displayHeight
  device.swipe(width/2,height/2,width/2,height/2,120)
  val widgets=device.wait(Until.findObject(By.text("WIDGETS")),20000)
  assertNotNull("Launcher widget menu",widgets);requireNotNull(widgets).click()
  val scroll=UiScrollable(UiSelector().scrollable(true))
  assertTrue("Find widget $label",scroll.scrollIntoView(UiSelector().text(label)))
  val objectToDrag=device.findObject(UiSelector().text(label))
  assertTrue("Bind $label by dragging from the picker",objectToDrag.dragTo(width/2,height/2,100))
  device.waitForIdle(1000);device.pressBack();device.waitForIdle(1000)
  val component=ComponentName(packageName,"$packageName.widget.provider.$receiver")
  var ids=manager.getAppWidgetIds(component)
  for(i in 0..20) {if(ids.isNotEmpty())break;device.waitForIdle(1000);Thread.sleep(500);ids=manager.getAppWidgetIds(component)}
  assertTrue("Widget must be bound to stock launcher",ids.isNotEmpty())
  return ids.last()
 }
 private fun verify(label:String,receiver:String,rootId:String,route:String) {
  val payloads=listOf("en","ta","hi","te").associateWith { code ->
    val file=context.getDatabasePath("widget-fixture-$code.json")
    assertTrue("Locale fixture $code exists",file.exists())
    WidgetPayload.fromJsonString(file.readText())
  }
  assertTrue(WidgetRefreshManager.updateDataAndRefresh(context,payloads.getValue("en")))
  val id=addWidget(label,receiver)
  for((code,payload) in payloads) {
   assertTrue(WidgetRefreshManager.updateDataAndRefresh(context,payload))
   // Provider updates arrive through broadcasts; wait for the visible heading.
   val expected=payload.localizedStrings[if(receiver=="EkadashiTodayWidgetReceiver")"widget.today_title" else "widget.next_ekadashi"]!!
   assertTrue("Translated heading $code on launcher",device.wait(Until.hasObject(By.text(expected)),20000))
   capture("${receiver}_$code")
   assertNotNull(device.findObject(By.res(packageName,rootId)))
  }
  val monitor=instrumentation.addMonitor("$packageName.MainActivity",null,false)
  requireNotNull(device.findObject(By.res(packageName,rootId))).click()
  val activity=monitor.waitForActivityWithTimeout(30000)
  assertNotNull("Widget tap opens the app",activity)
  assertEquals("ekadashi",requireNotNull(activity).intent.data?.scheme)
  assertEquals(route,activity.intent.data?.host)
  instrumentation.removeMonitor(monitor)
  device.waitForIdle(1000);capture("${receiver}_tap")
  instrumentation.runOnMainSync { activity.finish() }
  home()
  File(output,"${receiver}_bound.txt").writeText("AppWidgetId=$id; provider=$receiver; stock launcher; four locales; route=$route\n")
 }
 @Test fun nextEkadashiWidget()=verify("Next Ekadashi","NextEkadashiWidgetReceiver","widget_small_root","dashboard")
 @Test fun todayWidget()=verify("Ekadashi Today","EkadashiTodayWidgetReceiver","widget_medium_root","today")
 @Test fun upcomingWidget()=verify("Upcoming Ekadashis","UpcomingEkadashisWidgetReceiver","widget_large_hero_card","today")
}
