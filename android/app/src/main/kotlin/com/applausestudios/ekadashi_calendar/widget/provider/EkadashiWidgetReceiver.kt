package com.applausestudios.ekadashi_calendar.widget.provider

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import com.applausestudios.ekadashi_calendar.R
import com.applausestudios.ekadashi_calendar.widget.deeplink.WidgetDeepLinks
import com.applausestudios.ekadashi_calendar.widget.model.EkadashiItem
import com.applausestudios.ekadashi_calendar.widget.model.WidgetHeadline
import com.applausestudios.ekadashi_calendar.widget.model.daysToGo
import com.applausestudios.ekadashi_calendar.widget.model.zoneId
import com.applausestudios.ekadashi_calendar.widget.model.WidgetPayload
import com.applausestudios.ekadashi_calendar.widget.model.WidgetState
import com.applausestudios.ekadashi_calendar.widget.service.EkadashiListWidgetService
import com.applausestudios.ekadashi_calendar.widget.storage.WidgetStorage
import java.time.Duration
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

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
            val headline = if (canDisplay) WidgetHeadline.of(payload) else null
            val views: RemoteViews = when (preferredMode) {
                WidgetMode.UPCOMING -> buildUpcomingWidget(context, payload, appWidgetId)
                // Wide placements (4x2) get the timings; otherwise the compact card.
                WidgetMode.EKADASHI -> if (minWidth >= 250) buildMediumWidget(context, payload, headline)
                    else buildSmallWidget(context, payload, headline)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "Successfully updated widget $appWidgetId")
        } catch (e: Throwable) {
            Log.e(TAG, "Exception rendering widget $appWidgetId: ${e.message}. Displaying safe fallback.", e)
            try {
                val fallbackViews = buildSmallWidget(context, WidgetPayload.fallback(), null)
                appWidgetManager.updateAppWidget(appWidgetId, fallbackViews)
            } catch (fallbackError: Throwable) {
                Log.e(TAG, "Emergency fallback also failed: ${fallbackError.message}", fallbackError)
            }
        }
    }

    private fun displayName(item: EkadashiItem) = item.localizedName.ifEmpty { item.name }

    private fun badge(payload: WidgetPayload, headline: WidgetHeadline) = when (headline) {
        is WidgetHeadline.Today -> payload.localized("widget.today_is_ekadashi", "Today is Ekadashi")
        is WidgetHeadline.Next -> payload.localized("widget.next_ekadashi", "Next Ekadashi")
    }

    /** The countdown row: Parana in / Parana ends on an Ekadashi, else the days to go. */
    private fun countdown(payload: WidgetPayload, headline: WidgetHeadline): Pair<String, String> = when (headline) {
        is WidgetHeadline.Today -> if (headline.item.stateAt(Instant.now()) == WidgetState.PARANA_AVAILABLE) {
            payload.localized("widget.parana_ends", "Parana ends") to formatRemaining(payload, headline.item.paranaEndInstant)
        } else {
            payload.localized("widget.parana_in", "Parana in") to formatRemaining(payload, headline.item.paranaStartInstant)
        }
        is WidgetHeadline.Next -> "" to payload.daysToGo(headline.days)
    }

    private fun setProgress(views: RemoteViews, id: Int, payload: WidgetPayload, headline: WidgetHeadline?) {
        if (headline is WidgetHeadline.Today) {
            val percent = (headline.progress * 100).toInt()
            views.setViewVisibility(id, View.VISIBLE)
            views.setProgressBar(id, 100, percent, false)
            views.setContentDescription(id, payload.localized("widget.fast_done", "{value0}% of the fast done").replace("{value0}", "$percent"))
        } else {
            views.setViewVisibility(id, View.GONE)
        }
    }

    private fun deepLink(headline: WidgetHeadline?): Uri =
        if (headline?.item?.stateAt(Instant.now()) == WidgetState.PARANA_AVAILABLE) WidgetDeepLinks.buildParanaUri()
        else WidgetDeepLinks.buildDashboardUri()

    // =========================================================================
    // EKADASHI — compact (2x2)
    // =========================================================================
    private fun buildSmallWidget(context: Context, payload: WidgetPayload, headline: WidgetHeadline?): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_small)
        views.setTextColor(R.id.widget_small_badge, android.graphics.Color.WHITE)

        if (headline != null) {
            val item = headline.item
            views.setTextViewText(R.id.widget_small_badge, badge(payload, headline))
            views.setTextViewText(R.id.widget_small_name, displayName(item))
            views.setTextViewText(R.id.widget_small_date, "${item.localizedDate} • ${item.paksha}")
            val (label, value) = countdown(payload, headline)
            views.setTextViewText(R.id.widget_small_countdown_label, label)
            views.setViewVisibility(R.id.widget_small_countdown_label, if (label.isEmpty()) View.GONE else View.VISIBLE)
            views.setTextViewText(R.id.widget_small_countdown_value, value)
        } else {
            views.setTextViewText(R.id.widget_small_badge, payload.localized("widget.notice", "NOTICE"))
            views.setTextViewText(R.id.widget_small_name, payload.localized("widget.title", "Ekadashi Calendar"))
            views.setTextViewText(R.id.widget_small_date, payload.localized("widget.open_app_to_refresh", "Open the app\nto calculate timings"))
            views.setTextViewText(R.id.widget_small_countdown_label, "")
            views.setTextViewText(R.id.widget_small_countdown_value, "")
        }
        setProgress(views, R.id.widget_small_progress, payload, headline)

        val intent = WidgetDeepLinks.createIntent(context, deepLink(headline))
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_small_root, pendingIntent)

        return views
    }

    // =========================================================================
    // EKADASHI — wide (4x2) with timings
    // =========================================================================
    private fun buildMediumWidget(context: Context, payload: WidgetPayload, headline: WidgetHeadline?): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_medium)
        views.setTextViewText(R.id.widget_medium_fasting_label, payload.localized("widget.fasting_starts", "Fasting Start"))
        views.setTextViewText(R.id.widget_medium_parana_label, payload.localized("widget.parana_window", "Parana Window"))

        if (headline != null) {
            val item = headline.item
            views.setTextViewText(R.id.widget_medium_title, badge(payload, headline))
            views.setTextViewText(R.id.widget_medium_name, displayName(item))
            views.setTextViewText(R.id.widget_medium_date, "${item.localizedDate} • ${item.paksha}")
            views.setTextViewText(R.id.widget_medium_location, "📍 ${payload.metadata.locationName}")
            views.setTextViewText(R.id.widget_medium_fasting_time, formatDisplayTime(payload, item.fastingStartInstant))
            views.setTextViewText(R.id.widget_medium_parana_time, "${formatDisplayTime(payload, item.paranaStartInstant)} - ${formatDisplayTime(payload, item.paranaEndInstant)}")
            when (item.stateAt(Instant.now())) {
                WidgetState.FASTING_ACTIVE -> {
                    views.setTextColor(R.id.widget_medium_badge, context.getColor(R.color.widget_amber))
                    views.setTextViewText(R.id.widget_medium_badge, payload.localized("widget.fasting_active", "FASTING ACTIVE"))
                }
                WidgetState.PARANA_AVAILABLE -> {
                    views.setTextColor(R.id.widget_medium_badge, context.getColor(R.color.widget_green))
                    views.setTextViewText(R.id.widget_medium_badge, payload.localized("widget.parana_available", "PARANA AVAILABLE"))
                }
                else -> {
                    views.setTextColor(R.id.widget_medium_badge, context.getColor(R.color.widget_gold))
                    views.setTextViewText(R.id.widget_medium_badge, payload.daysToGo((headline as? WidgetHeadline.Next)?.days ?: 0))
                }
            }
            val (label, value) = countdown(payload, headline)
            views.setTextViewText(R.id.widget_medium_countdown_label, label.ifEmpty { payload.localized("widget.starts_in", "Starts in") })
            views.setTextViewText(R.id.widget_medium_countdown_value,
                if (headline is WidgetHeadline.Next) formatRemaining(payload, item.fastingStartInstant) else value)
        } else {
            views.setTextViewText(R.id.widget_medium_title, payload.localized("widget.title", "Ekadashi Calendar"))
            views.setTextViewText(R.id.widget_medium_badge, payload.localized("widget.notice", "NOTICE"))
            views.setTextViewText(R.id.widget_medium_name, payload.localized("widget.title", "Ekadashi Calendar"))
            views.setTextViewText(R.id.widget_medium_date, payload.localized("widget.open_app_to_refresh", "Open the app\nto calculate timings"))
            views.setTextViewText(R.id.widget_medium_location, "")
            views.setTextViewText(R.id.widget_medium_fasting_time, "--")
            views.setTextViewText(R.id.widget_medium_parana_time, "--")
            views.setTextViewText(R.id.widget_medium_countdown_label, "")
            views.setTextViewText(R.id.widget_medium_countdown_value, "--")
        }
        setProgress(views, R.id.widget_medium_progress, payload, headline)

        val intent = WidgetDeepLinks.createIntent(context, deepLink(headline))
        val pendingIntent = PendingIntent.getActivity(
            context, 1, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_medium_root, pendingIntent)

        return views
    }

    // =========================================================================
    // UPCOMING EKADASHIS — scrollable list
    // =========================================================================
    private fun buildUpcomingWidget(context: Context, payload: WidgetPayload, appWidgetId: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_large)
        // A list only (docs/ROADMAP.md Phase 6): the Ekadashi widget leads with the next one.
        views.setViewVisibility(R.id.widget_large_hero_card, View.GONE)
        views.setTextViewText(R.id.widget_large_upcoming_header, payload.localized("widget.upcoming_ekadashis", "Upcoming Ekadashis"))
        views.setTextViewText(R.id.widget_large_empty, payload.localized("widget.open_app_to_refresh", "Open app to refresh"))
        views.setTextViewText(R.id.widget_large_footer, if (payload.metadata.locationName.isNotEmpty()) "📍 ${payload.metadata.locationName}" else "")

        val headerIntent = WidgetDeepLinks.createIntent(context, WidgetDeepLinks.buildTodayUri())
        val headerPendingIntent = PendingIntent.getActivity(
            context, 2, headerIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_large_upcoming_header, headerPendingIntent)

        // Set up Scrollable ListView Collection via EkadashiListWidgetService
        val serviceIntent = Intent(context, EkadashiListWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.widget_large_list, serviceIntent)
        views.setEmptyView(R.id.widget_large_list, R.id.widget_large_empty)

        // PendingIntent template for ListView child item clicks (ekadashi://calendar?date={iso_date})
        val itemClickIntent = Intent(Intent.ACTION_VIEW).apply {
            setPackage(context.packageName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val templateFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val itemPendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId,
            itemClickIntent,
            templateFlags
        )
        views.setPendingIntentTemplate(R.id.widget_large_list, itemPendingIntent)

        return views
    }

    private fun formatRemaining(payload: WidgetPayload, target: Instant?): String {
        if (target == null) return "--"
        val now = Instant.now()
        val duration = Duration.between(now, target)
        if (duration.isNegative) return payload.localized("widget.now", "Now")

        val days = duration.toDays()
        val hours = duration.toHours() % 24
        val minutes = duration.toMinutes() % 60

        return when {
            days > 0 -> "$days ${payload.localized("widget.day_unit", "d")} $hours ${payload.localized("widget.hour_unit", "h")}"
            hours > 0 -> "$hours ${payload.localized("widget.hour_unit", "h")} $minutes ${payload.localized("widget.minute_unit", "min")}"
            else -> "$minutes ${payload.localized("widget.minute_unit", "min")}"
        }
    }

    private fun formatDisplayTime(payload: WidgetPayload, instant: Instant?): String {
        if (instant == null) return "--"
        return try {
            val formatter = DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(java.util.Locale.forLanguageTag(payload.metadata.locale))
            formatter.format(instant.atZone(payload.zoneId()))
        } catch (e: Exception) {
            "--"
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
