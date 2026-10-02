package com.applausestudios.ekadashi_calendar.widget.refresh

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import com.applausestudios.ekadashi_calendar.widget.model.WidgetPayload
import com.applausestudios.ekadashi_calendar.widget.provider.EkadashiWidgetReceiver
import com.applausestudios.ekadashi_calendar.widget.storage.WidgetStorage
import com.applausestudios.ekadashi_calendar.widget.worker.WidgetRefreshWorker

/**
 * Central manager for coordinating Android widget refreshes.
 */
object WidgetRefreshManager {
    private const val TAG = "EKADASHI_WIDGET"

    /**
     * Called when the main Flutter application updates cached Module 10 data.
     */
    fun updateDataAndRefresh(context: Context, payload: WidgetPayload): Boolean {
        Log.i(TAG, "Updating widget data and triggering refresh...")
        val storage = WidgetStorage.getInstance(context)
        val saved = storage.savePayload(payload)
        if (saved) {
            refreshAllWidgets(context)
            // Schedule background transition timer
            WidgetRefreshWorker.scheduleNextTransition(context)
        }
        return saved
    }

    /**
     * Broadcasts an update intent to all registered Ekadashi app widget instances.
     */
    fun refreshAllWidgets(context: Context) {
        val receiverClasses = listOf(
            com.applausestudios.ekadashi_calendar.widget.provider.NextEkadashiWidgetReceiver::class.java,
            com.applausestudios.ekadashi_calendar.widget.provider.EkadashiTodayWidgetReceiver::class.java,
            com.applausestudios.ekadashi_calendar.widget.provider.UpcomingEkadashisWidgetReceiver::class.java,
            EkadashiWidgetReceiver::class.java
        )

        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            for (receiverClass in receiverClasses) {
                val componentName = ComponentName(context, receiverClass)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

                if (appWidgetIds.isNotEmpty()) {
                    val updateIntent = Intent(context, receiverClass).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
                    }
                    context.sendBroadcast(updateIntent)

                    // Notify scrollable ListView adapter to reload upcoming events collection
                    if (receiverClass == com.applausestudios.ekadashi_calendar.widget.provider.UpcomingEkadashisWidgetReceiver::class.java ||
                        receiverClass == EkadashiWidgetReceiver::class.java) {
                        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, com.applausestudios.ekadashi_calendar.R.id.widget_large_list)
                    }

                    Log.d(TAG, "Sent ACTION_APPWIDGET_UPDATE broadcast for ${appWidgetIds.size} widgets (${receiverClass.simpleName}).")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error refreshing widgets: ${e.message}", e)
        }
    }
}
