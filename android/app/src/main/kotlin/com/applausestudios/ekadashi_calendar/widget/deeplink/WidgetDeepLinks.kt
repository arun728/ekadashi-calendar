package com.applausestudios.ekadashi_calendar.widget.deeplink

import android.content.Context
import android.content.Intent
import android.net.Uri

/**
 * Canonical deep link generator and router constants for Ekadashi Calendar 2.0.
 */
object WidgetDeepLinks {
    const val SCHEME = "ekadashi"
    const val HOST_DASHBOARD = "dashboard"
    const val HOST_TODAY = "today"
    const val HOST_CALENDAR = "calendar"

    const val PARAM_ACTION = "action"
    const val PARAM_DATE = "date"
    const val ACTION_PARANA = "parana"

    fun buildDashboardUri(): Uri {
        return Uri.parse("$SCHEME://$HOST_DASHBOARD")
    }

    fun buildParanaUri(): Uri {
        return Uri.parse("$SCHEME://$HOST_DASHBOARD?$PARAM_ACTION=$ACTION_PARANA")
    }

    fun buildTodayUri(): Uri {
        return Uri.parse("$SCHEME://$HOST_TODAY")
    }

    fun buildCalendarUri(isoDate: String): Uri {
        return Uri.parse("$SCHEME://$HOST_CALENDAR?$PARAM_DATE=$isoDate")
    }

    fun createIntent(context: Context, uri: Uri): Intent {
        return Intent(Intent.ACTION_VIEW, uri).apply {
            setPackage(context.packageName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
    }
}
