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
import com.applausestudios.ekadashi_calendar.widget.model.WidgetPayload
import com.applausestudios.ekadashi_calendar.widget.model.WidgetState
import com.applausestudios.ekadashi_calendar.widget.service.EkadashiListWidgetService
import com.applausestudios.ekadashi_calendar.widget.storage.WidgetStorage
import java.time.Duration
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

enum class WidgetMode {
    ADAPTIVE,
    SMALL,
    MEDIUM,
    LARGE
}

open class EkadashiWidgetReceiver : AppWidgetProvider() {

    open val preferredMode: WidgetMode = WidgetMode.ADAPTIVE

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
            val (activeEkadashi, activePayload) = resolveActivePayload(payload)

            // Select layout based on preferred mode or dimensions
            val views: RemoteViews = when (preferredMode) {
                WidgetMode.SMALL -> buildSmallWidget(context, activePayload, activeEkadashi, canDisplay)
                WidgetMode.MEDIUM -> buildMediumWidget(context, activePayload, activeEkadashi, canDisplay)
                WidgetMode.LARGE -> buildLargeWidget(context, activePayload, activeEkadashi, canDisplay, minHeight, appWidgetId)
                WidgetMode.ADAPTIVE -> when {
                    minWidth >= 280 && minHeight >= 220 -> {
                        buildLargeWidget(context, activePayload, activeEkadashi, canDisplay, minHeight, appWidgetId)
                    }
                    minWidth >= 200 || minHeight >= 110 -> {
                        buildMediumWidget(context, activePayload, activeEkadashi, canDisplay)
                    }
                    else -> {
                        buildSmallWidget(context, activePayload, activeEkadashi, canDisplay)
                    }
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "Successfully updated widget $appWidgetId")
        } catch (e: Throwable) {
            Log.e(TAG, "Exception rendering widget $appWidgetId: ${e.message}. Displaying safe fallback.", e)
            try {
                val fallbackViews = buildSmallWidget(context, WidgetPayload.fallback(), null, false)
                appWidgetManager.updateAppWidget(appWidgetId, fallbackViews)
            } catch (fallbackError: Throwable) {
                Log.e(TAG, "Emergency fallback also failed: ${fallbackError.message}", fallbackError)
            }
        }
    }

    private fun resolveActivePayload(payload: WidgetPayload): Pair<EkadashiItem?, WidgetPayload> {
        val next = payload.nextEkadashi ?: return Pair(null, payload)
        val now = Instant.now()
        val pEnd = next.paranaEndInstant

        // If parana window completed + 2 hours grace period, advance to upcoming item
        if (pEnd != null && now.isAfter(pEnd.plusSeconds(7200))) {
            if (payload.upcomingEkadashis.isNotEmpty()) {
                val firstUpcoming = payload.upcomingEkadashis.first()
                val advancedPayload = WidgetPayload(
                    metadata = payload.metadata,
                    currentState = firstUpcoming.stateAt(now),
                    nextEkadashi = firstUpcoming,
                    upcomingEkadashis = payload.upcomingEkadashis.drop(1),
                    localizedStrings = payload.localizedStrings
                )
                return Pair(firstUpcoming, advancedPayload)
            }
        }
        return Pair(next, payload)
    }

    // =========================================================================
    // WIDGET A — SMALL (2x2)
    // =========================================================================
    private fun buildSmallWidget(context: Context, payload: WidgetPayload, next: EkadashiItem?, canDisplay: Boolean): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_small)

        if (canDisplay && next != null) {
            val state = next.stateAt(Instant.now())
            views.setTextViewText(R.id.widget_small_name, if (next.localizedName.isNotEmpty()) next.localizedName else next.name)
            views.setTextViewText(R.id.widget_small_date, "${next.localizedDate} • ${next.paksha}")

            // Heading is always NEXT EKADASHI
            views.setTextColor(R.id.widget_small_badge, android.graphics.Color.WHITE)
            views.setTextViewText(R.id.widget_small_badge, "NEXT EKADASHI")

            when (state) {
                WidgetState.FASTING_ACTIVE -> {
                    views.setTextViewText(R.id.widget_small_countdown_label, "◷ PARANA IN")
                    views.setTextViewText(R.id.widget_small_countdown_value, formatRemaining(next.paranaStartInstant))
                }
                WidgetState.PARANA_AVAILABLE -> {
                    views.setTextViewText(R.id.widget_small_countdown_label, "◷ PARANA ENDS")
                    views.setTextViewText(R.id.widget_small_countdown_value, formatRemaining(next.paranaEndInstant))
                }
                WidgetState.PARANA_COMPLETED -> {
                    views.setTextViewText(R.id.widget_small_countdown_label, "◷ NEXT IN")
                    views.setTextViewText(R.id.widget_small_countdown_value, formatRemaining(next.countdownTargetInstant))
                }
                else -> {
                    views.setTextViewText(R.id.widget_small_countdown_label, "◷ STARTS IN")
                    views.setTextViewText(R.id.widget_small_countdown_value, formatRemaining(next.countdownTargetInstant ?: next.fastingStartInstant))
                }
            }
        } else {
            views.setTextViewText(R.id.widget_small_badge, "NOTICE")
            views.setTextViewText(R.id.widget_small_name, payload.localized("widget.title", "Ekadashi Calendar"))
            views.setTextViewText(R.id.widget_small_date, payload.localized("widget.open_app_to_refresh", "Open the app\nto calculate timings"))
            views.setTextViewText(R.id.widget_small_countdown_label, "")
            views.setTextViewText(R.id.widget_small_countdown_value, "")
        }

        // Deep link: ekadashi://dashboard
        val intent = WidgetDeepLinks.createIntent(context, WidgetDeepLinks.buildDashboardUri())
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_small_root, pendingIntent)

        return views
    }

    // =========================================================================
    // WIDGET B — MEDIUM (4x2)
    // =========================================================================
    private fun buildMediumWidget(context: Context, payload: WidgetPayload, next: EkadashiItem?, canDisplay: Boolean): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_medium)

        val activeItem = if (payload.today != null && payload.today.isEkadashi) {
            next
        } else {
            next
        }

        val deepLinkUri = if (canDisplay && activeItem != null && activeItem.stateAt(Instant.now()) == WidgetState.PARANA_AVAILABLE) {
            WidgetDeepLinks.buildParanaUri()
        } else {
            WidgetDeepLinks.buildTodayUri()
        }

        if (canDisplay && activeItem != null) {
            val state = activeItem.stateAt(Instant.now())
            views.setTextViewText(R.id.widget_medium_name, if (activeItem.localizedName.isNotEmpty()) activeItem.localizedName else activeItem.name)
            views.setTextViewText(R.id.widget_medium_date, "${activeItem.localizedDate} • ${activeItem.paksha}")
            views.setTextViewText(R.id.widget_medium_location, "📍 ${payload.metadata.locationName} • ${payload.metadata.timezone}")

            views.setTextViewText(R.id.widget_medium_fasting_label, payload.localized("widget.fasting_starts", "FASTING START").uppercase())
            views.setTextViewText(R.id.widget_medium_fasting_time, formatDisplayTime(activeItem.fastingStartInstant))

            views.setTextViewText(R.id.widget_medium_parana_label, payload.localized("widget.parana_window", "PARANA WINDOW").uppercase())
            views.setTextViewText(R.id.widget_medium_parana_time, "${formatDisplayTime(activeItem.paranaStartInstant)} - ${formatDisplayTime(activeItem.paranaEndInstant)}")

            when (state) {
                WidgetState.FASTING_ACTIVE -> {
                    views.setTextColor(R.id.widget_medium_badge, context.getColor(R.color.widget_amber))
                    views.setTextViewText(R.id.widget_medium_badge, "FASTING ACTIVE")
                    views.setTextViewText(R.id.widget_medium_countdown_label, "PARANA IN")
                    views.setTextViewText(R.id.widget_medium_countdown_value, formatRemaining(activeItem.paranaStartInstant))
                }
                WidgetState.PARANA_AVAILABLE -> {
                    views.setTextColor(R.id.widget_medium_badge, context.getColor(R.color.widget_green))
                    views.setTextViewText(R.id.widget_medium_badge, "PARANA AVAILABLE")
                    views.setTextViewText(R.id.widget_medium_countdown_label, "PARANA ENDS")
                    views.setTextViewText(R.id.widget_medium_countdown_value, formatRemaining(activeItem.paranaEndInstant))
                }
                WidgetState.PARANA_COMPLETED -> {
                    views.setTextColor(R.id.widget_medium_badge, context.getColor(R.color.widget_text_muted))
                    views.setTextViewText(R.id.widget_medium_badge, "PARANA COMPLETED")
                    views.setTextViewText(R.id.widget_medium_countdown_label, "NEXT IN")
                    views.setTextViewText(R.id.widget_medium_countdown_value, formatRemaining(activeItem.countdownTargetInstant))
                }
                else -> {
                    views.setTextColor(R.id.widget_medium_badge, context.getColor(R.color.widget_gold))
                    views.setTextViewText(R.id.widget_medium_badge, "UPCOMING")
                    views.setTextViewText(R.id.widget_medium_countdown_label, "STARTS IN")
                    views.setTextViewText(R.id.widget_medium_countdown_value, formatRemaining(activeItem.countdownTargetInstant ?: activeItem.fastingStartInstant))
                }
            }
        } else {
            views.setTextViewText(R.id.widget_medium_badge, "NOTICE")
            views.setTextViewText(R.id.widget_medium_name, payload.localized("widget.title", "Ekadashi Calendar"))
            views.setTextViewText(R.id.widget_medium_date, payload.localized("widget.open_app_to_refresh", "Open the app\nto calculate timings"))
            views.setTextViewText(R.id.widget_medium_location, "")
            views.setTextViewText(R.id.widget_medium_fasting_time, "--")
            views.setTextViewText(R.id.widget_medium_parana_time, "--")
            views.setTextViewText(R.id.widget_medium_countdown_value, "--")
        }

        val intent = WidgetDeepLinks.createIntent(context, deepLinkUri)
        val pendingIntent = PendingIntent.getActivity(
            context, 1, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_medium_root, pendingIntent)

        return views
    }

    // =========================================================================
    // WIDGET C — LARGE (4x4) / RESPONSIVE SCROLLABLE UPCOMING LIST
    // =========================================================================
    private fun buildLargeWidget(
        context: Context,
        payload: WidgetPayload,
        next: EkadashiItem?,
        canDisplay: Boolean,
        minHeight: Int,
        appWidgetId: Int
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_large)

        // Intelligently adapt when the user reduces widget height
        // If minHeight < 220dp, collapse the hero card so the scrollable list receives maximum space
        if (minHeight < 220) {
            views.setViewVisibility(R.id.widget_large_hero_card, View.GONE)
            views.setTextViewText(R.id.widget_large_upcoming_header, payload.localized("widget.upcoming_ekadashis", "UPCOMING EKADASHIS").uppercase())
        } else {
            views.setViewVisibility(R.id.widget_large_hero_card, View.VISIBLE)
            // If height is between 220 and 260dp, hide timings row to save vertical space
            if (minHeight < 260) {
                views.setViewVisibility(R.id.widget_large_timings_row, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_large_timings_row, View.VISIBLE)
            }
        }

        if (canDisplay && next != null) {
            val state = next.stateAt(Instant.now())
            views.setTextViewText(R.id.widget_large_hero_title, "EKADASHI TODAY")
            views.setTextViewText(R.id.widget_large_hero_name, if (next.localizedName.isNotEmpty()) next.localizedName else next.name)
            views.setTextViewText(R.id.widget_large_hero_date, "${next.localizedDate} • ${next.paksha} Paksha")

            views.setTextViewText(R.id.widget_large_fasting_label, "FASTING START")
            views.setTextViewText(R.id.widget_large_fasting_val, formatDisplayTime(next.fastingStartInstant))

            views.setTextViewText(R.id.widget_large_parana_label, "PARANA WINDOW")
            views.setTextViewText(R.id.widget_large_parana_val, "${formatDisplayTime(next.paranaStartInstant)} - ${formatDisplayTime(next.paranaEndInstant)}")

            when (state) {
                WidgetState.FASTING_ACTIVE -> {
                    views.setTextColor(R.id.widget_large_badge, context.getColor(R.color.widget_amber))
                    views.setTextViewText(R.id.widget_large_badge, "FASTING ACTIVE")
                }
                WidgetState.PARANA_AVAILABLE -> {
                    views.setTextColor(R.id.widget_large_badge, context.getColor(R.color.widget_green))
                    views.setTextViewText(R.id.widget_large_badge, "PARANA AVAILABLE")
                }
                else -> {
                    views.setTextColor(R.id.widget_large_badge, android.graphics.Color.WHITE)
                    views.setTextViewText(R.id.widget_large_badge, "NEXT EKADASHI")
                }
            }

            views.setTextViewText(R.id.widget_large_footer, "📍 ${payload.metadata.locationName} (${payload.metadata.timezone}) • v${payload.metadata.calculationVersion}")
        } else {
            views.setTextViewText(R.id.widget_large_badge, "NOTICE")
            views.setTextViewText(R.id.widget_large_hero_name, payload.localized("widget.title", "Ekadashi Calendar"))
            views.setTextViewText(R.id.widget_large_hero_date, payload.localized("widget.open_app_to_refresh", "Open the app\nto calculate timings"))
            views.setTextViewText(R.id.widget_large_fasting_val, "--")
            views.setTextViewText(R.id.widget_large_parana_val, "--")
        }

        // Hero card click -> parana if parana is available, else today
        val heroUri = if (canDisplay && next != null && next.stateAt(Instant.now()) == WidgetState.PARANA_AVAILABLE) {
            WidgetDeepLinks.buildParanaUri()
        } else {
            WidgetDeepLinks.buildTodayUri()
        }
        val heroIntent = WidgetDeepLinks.createIntent(context, heroUri)
        val heroPendingIntent = PendingIntent.getActivity(
            context, 2, heroIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_large_hero_card, heroPendingIntent)

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

    private fun formatRemaining(target: Instant?): String {
        if (target == null) return "--"
        val now = Instant.now()
        val duration = Duration.between(now, target)
        if (duration.isNegative) return "Now"

        val days = duration.toDays()
        val hours = duration.toHours() % 24
        val minutes = duration.toMinutes() % 60

        return when {
            days > 0 -> String.format("%dd %02dh %02dm", days, hours, minutes)
            hours > 0 -> String.format("%dh %02dm", hours, minutes)
            else -> "$minutes min"
        }
    }

    private fun formatDisplayTime(instant: Instant?): String {
        if (instant == null) return "--"
        return try {
            val formatter = DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT)
            formatter.format(instant.atZone(java.time.ZoneId.systemDefault()))
        } catch (e: Exception) {
            "--"
        }
    }
}

/**
 * Card 1 — Next Ekadashi (Small / 2x2)
 */
class NextEkadashiWidgetReceiver : EkadashiWidgetReceiver() {
    override val preferredMode = WidgetMode.SMALL
}

/**
 * Card 2 — Ekadashi Today (Medium / 4x2)
 */
class EkadashiTodayWidgetReceiver : EkadashiWidgetReceiver() {
    override val preferredMode = WidgetMode.MEDIUM
}

/**
 * Card 3 — Upcoming Ekadashis (Large / 4x4)
 */
class UpcomingEkadashisWidgetReceiver : EkadashiWidgetReceiver() {
    override val preferredMode = WidgetMode.LARGE
}

