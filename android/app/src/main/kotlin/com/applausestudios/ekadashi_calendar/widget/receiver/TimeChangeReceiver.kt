package com.applausestudios.ekadashi_calendar.widget.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.applausestudios.ekadashi_calendar.widget.refresh.WidgetRefreshManager

/**
 * BroadcastReceiver for system time, timezone, and device boot changes.
 *
 * Triggers an immediate local widget UI refresh without performing network requests.
 */
class TimeChangeReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "EKADASHI_WIDGET"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.d(TAG, "Received system broadcast action: $action")

        when (action) {
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.i(TAG, "Invalidating and refreshing widget on system event: $action")
                WidgetRefreshManager.refreshAllWidgets(context)
            }
            else -> {
                Log.d(TAG, "Unhandled broadcast action: $action")
            }
        }
    }
}
