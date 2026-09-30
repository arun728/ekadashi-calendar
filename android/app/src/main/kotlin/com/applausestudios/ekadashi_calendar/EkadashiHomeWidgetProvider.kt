package com.applausestudios.ekadashi_calendar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class EkadashiHomeWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.ekadashi_home_widget)

            val name = widgetData.getString("widget_name", "Ekadashi") ?: "Ekadashi"
            val date = widgetData.getString("widget_date", "—") ?: "—"
            val weekday = widgetData.getString("widget_weekday", "—") ?: "—"
            val start = widgetData.getString("widget_start_fasting", "—") ?: "—"
            val significance =
                widgetData.getString("widget_significance", "") ?: ""

            views.setTextViewText(R.id.widget_name, name)
            views.setTextViewText(
                R.id.widget_weekday_date,
                if (weekday == "—" && date == "—") "—" else "$weekday · $date",
            )
            views.setTextViewText(
                R.id.widget_start_fasting,
                if (start == "—") "—" else "Start fasting · $start",
            )
            views.setTextViewText(R.id.widget_significance, significance)

            val pending = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
