package com.applausestudios.ekadashi_calendar.widget.provider

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle
import android.util.Log
import android.widget.RemoteViews
import com.applausestudios.ekadashi_calendar.widget.model.WidgetPayload
import com.applausestudios.ekadashi_calendar.widget.storage.WidgetStorage
import com.applausestudios.ekadashi_calendar.widget.ui.WidgetRenderer

/** Phase 6 (docs/ROADMAP.md): an Ekadashi widget and an Upcoming list. */
enum class WidgetMode {
    /** Today's Ekadashi with progress, or the next one and the days to go. */
    EKADASHI,
    /** A list of upcoming Ekadashis. */
    UPCOMING
}

open class EkadashiWidgetReceiver : AppWidgetProvider() {

    open val preferredMode: WidgetMode = WidgetMode.EKADASHI

    companion object {
        private const val TAG = "EKADASHI_WIDGET"
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Log.i(TAG, "onUpdate invoked for ${appWidgetIds.size} widgets (${javaClass.simpleName}): ${appWidgetIds.joinToString()}")
        try {
            val storage = WidgetStorage.getInstance(context)
            val loadResult = storage.loadPayload()
            Log.d(TAG, "Loaded cache status: ${loadResult.status}, nextEkadashi: ${loadResult.payload.nextEkadashi?.name}")

            for (appWidgetId in appWidgetIds) {
                val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
                updateWidget(context, appWidgetManager, appWidgetId, options, loadResult.payload, loadResult.status.canDisplay)
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Error in onUpdate: ${e.message}", e)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        Log.i(TAG, "onAppWidgetOptionsChanged for widget ID: $appWidgetId (${javaClass.simpleName})")
        try {
            val storage = WidgetStorage.getInstance(context)
            val loadResult = storage.loadPayload()
            updateWidget(context, appWidgetManager, appWidgetId, newOptions, loadResult.payload, loadResult.status.canDisplay)
        } catch (e: Throwable) {
            Log.e(TAG, "Error in onAppWidgetOptionsChanged: ${e.message}", e)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        options: Bundle,
        payload: WidgetPayload,
        canDisplay: Boolean
    ) {
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 140)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
        Log.d(TAG, "Updating widget $appWidgetId: mode=$preferredMode, dimensions=${minWidth}x${minHeight}dp, canDisplay=$canDisplay")

        try {
            val views: RemoteViews = when (preferredMode) {
                WidgetMode.UPCOMING -> WidgetRenderer.upcoming(context, payload, appWidgetId, height = minHeight)
                // Wide placements (4x2) get the timings; otherwise the compact card.
                WidgetMode.EKADASHI -> WidgetRenderer.single(context, payload, minWidth, minHeight)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "Successfully updated widget $appWidgetId")
        } catch (e: Throwable) {
            Log.e(TAG, "Exception rendering widget $appWidgetId: ${e.message}. Displaying safe fallback.", e)
            try {
                val fallbackViews = WidgetRenderer.single(context, WidgetPayload.fallback().copy(metadata = payload.metadata), minWidth, minHeight)
                appWidgetManager.updateAppWidget(appWidgetId, fallbackViews)
            } catch (fallbackError: Throwable) {
                Log.e(TAG, "Emergency fallback also failed: ${fallbackError.message}", fallbackError)
            }
        }
    }


}

/**
 * Ekadashi: today's Ekadashi with progress, or the next one and the days to go.
 * Keeps the original provider so placed "Next Ekadashi" widgets become this one.
 */
class NextEkadashiWidgetReceiver : EkadashiWidgetReceiver() {
    override val preferredMode = WidgetMode.EKADASHI
}

/**
 * Retired "Ekadashi Today" widget: hidden from the picker, but placed widgets
 * keep working with the Ekadashi layout.
 */
class EkadashiTodayWidgetReceiver : EkadashiWidgetReceiver() {
    override val preferredMode = WidgetMode.EKADASHI
}

/**
 * Upcoming Ekadashis: a scrollable list.
 */
class UpcomingEkadashisWidgetReceiver : EkadashiWidgetReceiver() {
    override val preferredMode = WidgetMode.UPCOMING
}
