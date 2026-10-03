package com.applausestudios.ekadashi_calendar

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterView
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.uiautomator.*
import com.applausestudios.ekadashi_calendar.widget.model.WidgetPayload
import com.applausestudios.ekadashi_calendar.widget.refresh.WidgetRefreshManager
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
import java.io.File
import java.util.regex.Pattern

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
 private fun capture(name:String) {
  // Accessibility can expose updated RemoteViews before the launcher draws its
  // frame (and the collection adapter updates separately). Capture settled UI.
  device.waitForIdle(1000)
  Thread.sleep(1000)
  assertTrue(device.takeScreenshot(File(output,"$name.png")))
 }
 private fun home(){device.pressHome();device.waitForIdle(1000)}
 private fun flutterView(view:View):FlutterView? {
  if(view is FlutterView) return view
  if(view is ViewGroup) for(i in 0 until view.childCount) {
   val found=flutterView(view.getChildAt(i))
   if(found!=null) return found
  }
  return null
 }
 private fun addWidget(label:String,receiver:String):Int {
  // A clean home page prevents overlap from obscuring screenshots or tap targets.
  home()
  assertTrue("Stock launcher is foreground",device.wait(Until.hasObject(By.pkg(Pattern.compile("com\\.(android\\.launcher3|google\\.android\\.apps\\.nexuslauncher)"))),30000))
  val launcher=requireNotNull(device.currentPackageName)
  assertTrue("Dedicated stock launcher only",launcher in listOf("com.android.launcher3","com.google.android.apps.nexuslauncher"))
  device.executeShellCommand("pm clear $launcher")
  home()
  assertTrue("Launcher home is ready",device.wait(Until.hasObject(By.res(launcher,"workspace")),30000))
  val width=device.displayWidth;val height=device.displayHeight
  device.swipe(width/2,height/2,width/2,height/2,120)
  // Clearing Launcher3 can reveal its first-use tutorial on compact screens.
  val tutorial=device.findObject(By.res(launcher,"cling_dismiss_longpress_info"))
  if(tutorial!=null) {
   tutorial.click();device.waitForIdle(1000)
   device.swipe(width/2,height/2,width/2,height/2,120)
  }
  val widgets=device.wait(Until.findObject(By.text(Pattern.compile("widgets",Pattern.CASE_INSENSITIVE))),20000)
  assertNotNull("Launcher widget menu",widgets);requireNotNull(widgets).click()
  // New Launcher3 versions expose a collapsed app group and do not mark the
  // picker container as scrollable. Find visible items first, then swipe.
  var expanded=false
  val legacyScroll=UiScrollable(UiSelector().scrollable(true))
  if(legacyScroll.exists()) {
   legacyScroll.scrollIntoView(UiSelector().text(label))
  } else {
   for(attempt in 0..12) {
    if(device.hasObject(By.text(label))) break
    val appGroup=device.findObject(By.text("Ekadashi Calendar"))
    if(appGroup!=null && !expanded) { appGroup.click();expanded=true }
    else { device.swipe(width/2,height*4/5,width/2,height/3,30) }
    device.waitForIdle(1000)
   }
  }
  capture("${receiver}_picker")
  device.dumpWindowHierarchy(File(output,"${receiver}_picker.xml"))
  assertTrue("Find widget $label",device.hasObject(By.text(label)))
  val labelObject=requireNotNull(device.findObject(By.text(label)))
  var cell:UiObject2?=labelObject
  while(cell!=null && !cell.className.endsWith("WidgetCell")) cell=cell.parent
  val preview=cell?.findObject(By.res(launcher,"widget_preview_container"))
  // Pixel Launcher attaches the long-press listener to the preview, not label.
  val dragBounds=(preview ?: labelObject).visibleBounds
  assertTrue("Bind $label by dragging its preview",device.drag(dragBounds.centerX(),dragBounds.centerY(),width/2,height/2,100))
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
  // Activity creation precedes Flutter's first frame. Verify the destination
  // actually renders before closing it; a splash screenshot is insufficient.
  var flutterVisible=false
  for(attempt in 0..60) {
   instrumentation.runOnMainSync { flutterVisible=flutterView(activity.window.decorView)?.attachedFlutterEngine?.renderer?.isDisplayingFlutterUi==true }
   if(flutterVisible) break
   Thread.sleep(500)
  }
  assertTrue("Widget destination must draw Flutter UI",flutterVisible)
  val searchLabel=Pattern.compile("(?s).*(Search|தேடல்|खोज|శోధన).*")
  assertTrue("Widget destination must expose app navigation",device.wait(Until.hasObject(By.pkg(packageName).desc(searchLabel)),30000))
  device.waitForIdle(1000);capture("${receiver}_tap")
  instrumentation.runOnMainSync { activity.finish() }
  home()
  File(output,"${receiver}_bound.txt").writeText("AppWidgetId=$id; provider=$receiver; stock launcher; four locales; route=$route\n")
 }
 @Test fun nextEkadashiWidget()=verify("Next Ekadashi","NextEkadashiWidgetReceiver","widget_small_root","dashboard")
 @Test fun todayWidget()=verify("Ekadashi Today","EkadashiTodayWidgetReceiver","widget_medium_root","today")
 @Test fun upcomingWidget()=verify("Upcoming Ekadashis","UpcomingEkadashisWidgetReceiver","widget_large_hero_card","today")
}
