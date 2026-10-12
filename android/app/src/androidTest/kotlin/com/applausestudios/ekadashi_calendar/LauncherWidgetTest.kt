package com.applausestudios.ekadashi_calendar

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.SystemClock
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
 private fun launcherHomeReady(launcher:String):Boolean {
  val workspace=By.res(launcher,"workspace")
  val deadline=SystemClock.uptimeMillis()+60000
  val intent=Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
   .setPackage(launcher)
   .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
  var attempt=0
  while(SystemClock.uptimeMillis()<deadline) {
   // Clearing Launcher3 data can restart it into setup on slower API 33 images.
   // Re-enter its HOME activity within a fixed deadline; widget checks remain strict.
   // On API 33 the system can restart HOME while `pm clear` still has the
   // package frozen ("Package ... is currently frozen"); the failed start leaves
   // a stale process record and later HOME starts never spawn the launcher.
   // A force-stop discards that record so the next start launches it cleanly.
   if(attempt++>0) { device.executeShellCommand("am force-stop $launcher");SystemClock.sleep(1000) }
   context.startActivity(intent)
   device.waitForIdle(1500)
   val remaining=deadline-SystemClock.uptimeMillis()
   if(remaining<=0) break
   if(device.wait(Until.hasObject(workspace),minOf(10000L,remaining))) return true
   val tutorial=device.findObject(By.res(launcher,"cling_dismiss_longpress_info"))
   if(tutorial!=null) { tutorial.click();device.waitForIdle(1000) }
   else { device.pressHome();device.waitForIdle(1000) }
  }
  return device.hasObject(workspace)
 }
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
  // Let the package unfreeze before the first HOME start (see launcherHomeReady).
  SystemClock.sleep(2000)
  val homeReady=launcherHomeReady(launcher)
  if(!homeReady) {
   capture("${receiver}_launcher_setup_failed")
   device.dumpWindowHierarchy(File(output,"${receiver}_launcher_setup_failed.xml"))
  }
  assertTrue("Launcher home is ready",homeReady)
  val width=device.displayWidth;val height=device.displayHeight
  // A visible workspace node can precede its first settled frame after pm clear.
  // Retry only entering the picker; provider binding/render/tap checks stay strict.
  var pickerReady=false
  for(attempt in 0..2) {
   home()
   val workspace=device.wait(Until.findObject(By.res(launcher,"workspace")),30000)
   assertNotNull("Launcher workspace",workspace)
   device.waitForIdle(2000);Thread.sleep(1500)
   requireNotNull(workspace).longClick()
   val tutorial=device.findObject(By.res(launcher,"cling_dismiss_longpress_info"))
   if(tutorial!=null) {
    tutorial.click();device.waitForIdle(1000)
    requireNotNull(device.findObject(By.res(launcher,"workspace"))).longClick()
   }
   val widgets=device.wait(Until.findObject(By.text(Pattern.compile("widgets",Pattern.CASE_INSENSITIVE))),10000)
   if(widgets!=null) {
    widgets.click()
    // Never send picker swipes to the home screen or its all-apps drawer.
    pickerReady=device.wait(Until.hasObject(By.res(Pattern.compile(Pattern.quote(launcher)+":id/.*(widgets_view|primary_widgets_list_view|widgets_list_view|widgets_search_bar_edit_text).*"))),10000)
    if(pickerReady) break
   }
   device.pressBack()
  }
  if(!pickerReady) {
   capture("${receiver}_picker_setup_failed")
   device.dumpWindowHierarchy(File(output,"${receiver}_picker_setup_failed.xml"))
  }
  assertTrue("Launcher widget picker is ready",pickerReady)
  // New Launcher3 versions expose a collapsed app group and do not mark the
  // picker container consistently as scrollable. A Pixel list may report true
  // while its app groups are still collapsed: expand the app group first.
  var expanded=false
  val legacyScroll=UiScrollable(UiSelector().scrollable(true))
  if(launcher=="com.android.launcher3" && legacyScroll.exists()) {
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
   // The Ekadashi widget leads with today's Ekadashi or the next one (docs/ROADMAP.md Phase 6).
   val headings=(if(receiver=="UpcomingEkadashisWidgetReceiver") listOf("widget.upcoming_ekadashis")
    else listOf("widget.next_ekadashi","widget.today_is_ekadashi")).map { payload.localizedStrings.getValue(it) }
   assertTrue("Translated heading $code on launcher",device.wait(Until.hasObject(By.text(Pattern.compile(headings.joinToString("|") { Pattern.quote(it) }))),20000))
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
 // The retired "Ekadashi Today" widget is hidden from the picker; WidgetRedesignTest covers it.
 @Test fun ekadashiWidget()=verify("Ekadashi","NextEkadashiWidgetReceiver","widget_small_root","dashboard")
 @Test fun upcomingWidget()=verify("Upcoming Ekadashis","UpcomingEkadashisWidgetReceiver","widget_large_upcoming_header","today")
}
