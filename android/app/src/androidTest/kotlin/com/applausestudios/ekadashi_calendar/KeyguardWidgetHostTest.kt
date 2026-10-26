package com.applausestudios.ekadashi_calendar

import android.Manifest
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Bundle
import android.view.View
import android.widget.ListView
import android.widget.TextView
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.SdkSuppress
import androidx.test.platform.app.InstrumentationRegistry
import com.applausestudios.ekadashi_calendar.widget.model.WidgetHeadline
import com.applausestudios.ekadashi_calendar.widget.model.WidgetPayload
import com.applausestudios.ekadashi_calendar.widget.model.WidgetTimeline
import com.applausestudios.ekadashi_calendar.widget.provider.NextEkadashiWidgetReceiver
import com.applausestudios.ekadashi_calendar.widget.provider.UpcomingEkadashisWidgetReceiver
import com.applausestudios.ekadashi_calendar.widget.refresh.WidgetRefreshManager
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Real framework KEYGUARD host; this does not claim to be the manufacturer's System UI. */
@RunWith(AndroidJUnit4::class)
@SdkSuppress(minSdkVersion = 29)
class KeyguardWidgetHostTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private val manager = AppWidgetManager.getInstance(context)

    @Test fun bothNativeProvidersRenderInAKeyguardHostInEveryLanguage() {
        instrumentation.uiAutomation.adoptShellPermissionIdentity(Manifest.permission.BIND_APPWIDGET)
        val host = AppWidgetHost(context, 7242026)
        try {
            host.startListening()
            for (upcoming in listOf(false, true)) {
                val receiver = if (upcoming) UpcomingEkadashisWidgetReceiver::class.java else NextEkadashiWidgetReceiver::class.java
                val info = manager.installedProviders.first { it.provider.className == receiver.name }
                assertTrue(info.widgetCategory and AppWidgetProviderInfo.WIDGET_CATEGORY_KEYGUARD != 0)
                assertTrue(info.initialKeyguardLayout != 0)
                val id = host.allocateAppWidgetId()
                val options = Bundle().apply {
                    putInt(AppWidgetManager.OPTION_APPWIDGET_HOST_CATEGORY, AppWidgetProviderInfo.WIDGET_CATEGORY_KEYGUARD)
                    putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 320)
                    putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 320)
                    putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 240)
                    putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 240)
                }
                assertTrue("Bind native keyguard widget", manager.bindAppWidgetIdIfAllowed(id, info.provider, options))
                lateinit var view: AppWidgetHostView
                instrumentation.runOnMainSync { view = host.createView(context, id, info) }
                for (language in listOf("en", "hi", "ta", "te", "gu", "bn")) {
                    val fixture = context.getDatabasePath("widget-fixture-$language.json")
                    assertTrue("Run android_widget_parity_test.dart first: $language fixture", fixture.exists())
                    val payload = WidgetPayload.fromJsonString(fixture.readText())
                    assertTrue(WidgetRefreshManager.updateDataAndRefresh(context, payload))
                    val deadline = System.currentTimeMillis() + 20000
                    var ready = false
                    while (!ready && System.currentTimeMillis() < deadline) {
                        instrumentation.runOnMainSync {
                            val title = if (upcoming) view.findViewById<TextView>(R.id.widget_large_upcoming_header)
                                else view.findViewById<TextView>(R.id.widget_medium_name)
                            val expected = if (upcoming) payload.localized("widget.upcoming_ekadashis")
                                else WidgetHeadline.of(payload)!!.item.localizedName
                            ready = title?.text?.toString() == expected
                            val density = context.resources.displayMetrics.density
                            view.measure(View.MeasureSpec.makeMeasureSpec((320 * density).toInt(), View.MeasureSpec.EXACTLY),
                                View.MeasureSpec.makeMeasureSpec((240 * density).toInt(), View.MeasureSpec.EXACTLY))
                            view.layout(0, 0, view.measuredWidth, view.measuredHeight)
                            if (upcoming) {
                                val list = view.findViewById<ListView>(R.id.widget_large_list)
                                val first = list?.getChildAt(0)?.findViewById<TextView>(R.id.widget_upcoming_item_name)
                                ready = ready && list?.adapter?.count == WidgetTimeline.upcoming(payload).size &&
                                    first?.text?.toString() == WidgetTimeline.upcoming(payload).first().localizedName
                            }
                        }
                        if (!ready) Thread.sleep(200)
                    }
                    assertTrue("$language provider update reaches keyguard host", ready)
                    instrumentation.runOnMainSync {
                        val density = context.resources.displayMetrics.density
                        val width = (320 * density).toInt(); val height = (240 * density).toInt()
                        view.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY))
                        view.layout(0, 0, width, height)
                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        view.draw(Canvas(bitmap))
                        val folder = File(context.getExternalFilesDir(null), "widget-keyguard-evidence").apply { mkdirs() }
                        File(folder, "${if (upcoming) "upcoming" else "ekadashi"}-$language.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                    }
                }
                host.deleteAppWidgetId(id)
            }
        } finally {
            host.stopListening(); host.deleteHost()
            instrumentation.uiAutomation.dropShellPermissionIdentity()
        }
    }
}
