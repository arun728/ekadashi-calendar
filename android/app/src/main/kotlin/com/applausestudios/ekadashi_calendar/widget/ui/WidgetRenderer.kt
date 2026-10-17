package com.applausestudios.ekadashi_calendar.widget.ui

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
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
import java.time.Duration
import java.time.Instant
import java.time.format.DateTimeFormatter

import com.applausestudios.ekadashi_calendar.widget.model.WidgetTimeline
import com.applausestudios.ekadashi_calendar.widget.data.WidgetLocalization
import java.time.LocalDate
import java.util.Locale
import kotlin.math.ceil

/** The installed widgets and Settings previews use these same native layouts and binders. */
object WidgetRenderer {
    fun localized(context: Context, payload: WidgetPayload): WidgetPayload = payload.copy(
        localizedStrings = WidgetLocalization.strings(context, payload.metadata.locale) + payload.localizedStrings)

    fun single(context: Context, payload: WidgetPayload, width: Int, height: Int, now: Instant = Instant.now()): RemoteViews {
        val p = localized(context, payload)
        val headline = WidgetHeadline.of(p, now)
        val views = if (width >= 250) buildMediumWidget(context, p, headline, now) else buildSmallWidget(context, p, headline, now)
        if (width >= 250 && height < 145) {
            views.setViewVisibility(R.id.widget_medium_metadata, View.GONE)
            views.setViewVisibility(R.id.widget_medium_progress, View.GONE)
        }
        if (width < 250 && height < 145) {
            views.setInt(R.id.widget_small_name, "setMaxLines", 1)
            views.setViewVisibility(R.id.widget_small_countdown_label, View.GONE)
            if (headline is WidgetHeadline.Today) views.setTextViewText(R.id.widget_small_countdown_value,
                "${remainingPercent(headline.progress)}% ${p.localized("widget.remaining", "")}")
        }
        if (width < 250 && height < 100) {
            // Keep the same compact card's essential name and countdown in very short host placements.
            for (id in listOf(R.id.widget_small_header, R.id.widget_small_chevron, R.id.widget_small_date, R.id.widget_small_progress, R.id.widget_small_countdown_label)) views.setViewVisibility(id, View.GONE)
            views.setInt(R.id.widget_small_name, "setMaxLines", 1)
            views.setTextViewTextSize(R.id.widget_small_name, android.util.TypedValue.COMPLEX_UNIT_SP, 10f)
            views.setTextViewTextSize(R.id.widget_small_countdown_value, android.util.TypedValue.COMPLEX_UNIT_SP, 10f)
        }
        fit(context, views, width, height)
        return views
    }

    /** Preserve the existing typography whenever it fits; shrink constrained text before the host clips it. */
    private fun fit(context: Context, views: RemoteViews, width: Int, height: Int) {
        val density = context.resources.displayMetrics.density
        repeat(10) {
            val root = views.apply(context, android.widget.FrameLayout(context))
            root.measure(View.MeasureSpec.makeMeasureSpec((width * density).toInt(), View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec((height * density).toInt(), View.MeasureSpec.EXACTLY))
            root.layout(0, 0, root.measuredWidth, root.measuredHeight)
            val texts = mutableListOf<android.widget.TextView>()
            var overflow = false
            fun visit(view: View, x: Int, y: Int) {
                if (view.visibility != View.VISIBLE) return
                if (view is android.widget.TextView && view.text.isNotEmpty()) {
                    texts.add(view)
                    val layout = view.layout
                    if (layout != null && view.id in listOf(R.id.widget_medium_fasting_time, R.id.widget_medium_parana_time) &&
                        (0 until minOf(layout.lineCount, view.maxLines)).any { layout.getEllipsisCount(it) > 0 }) overflow = true
                    if (x + view.width > root.width || y + view.height > root.height ||
                        (layout != null && layout.lineCount > 0 && layout.getLineBottom(minOf(layout.lineCount, view.maxLines) - 1) > view.height - view.compoundPaddingTop - view.compoundPaddingBottom + 1)) overflow = true
                }
                if (view is android.view.ViewGroup) for (i in 0 until view.childCount) {
                    val child = view.getChildAt(i); visit(child, x + child.left, y + child.top)
                }
            }
            visit(root, 0, 0)
            if (!overflow) return
            for (text in texts) if (text.id != View.NO_ID) views.setTextViewTextSize(text.id,
                android.util.TypedValue.COMPLEX_UNIT_PX, (text.textSize * 0.88f).coerceAtLeast(8 * density))
        }
    }

    fun date(payload: WidgetPayload, item: EkadashiItem): String = runCatching {
        LocalDate.parse(item.date).format(DateTimeFormatter.ofPattern("EEE, d MMM yyyy", Locale.forLanguageTag(payload.metadata.locale)))
    }.getOrDefault(item.localizedDate)

    fun upcomingRow(context: Context, payload: WidgetPayload, item: EkadashiItem, collectionItem: Boolean = true): RemoteViews = RemoteViews(context.packageName, R.layout.widget_upcoming_item).apply {
        setTextViewText(R.id.widget_upcoming_item_name, displayName(item))
        setTextViewText(R.id.widget_upcoming_item_date, date(payload, item))
        if (collectionItem) setOnClickFillInIntent(R.id.widget_upcoming_item_root, Intent().apply { data = WidgetDeepLinks.buildOccurrenceUri(item.occurrenceUid) })
    }

    private fun remainingPercent(fraction: Double) = ceil((fraction * 100).coerceIn(0.0, 100.0) - 0.000000001).toInt()

    private fun displayName(item: EkadashiItem) = item.localizedName.ifEmpty { item.name }

    private fun badge(payload: WidgetPayload, headline: WidgetHeadline) = when (headline) {
        is WidgetHeadline.Today -> payload.localized("widget.today_is_ekadashi", "Today is Ekadashi")
        is WidgetHeadline.Next -> payload.localized("widget.next_ekadashi", "Next Ekadashi")
    }

    /** Remaining percentage today, otherwise calendar days to go. */
    private fun countdown(payload: WidgetPayload, headline: WidgetHeadline): Pair<String, String> = when (headline) {
        is WidgetHeadline.Today -> payload.localized("widget.remaining", "remaining") to "${remainingPercent(headline.progress)}%"
        is WidgetHeadline.Next -> "" to payload.daysToGo(headline.days)
    }

    private fun setProgress(views: RemoteViews, id: Int, payload: WidgetPayload, headline: WidgetHeadline?) {
        if (headline is WidgetHeadline.Today) {
            val percent = remainingPercent(headline.progress)
            views.setViewVisibility(id, View.VISIBLE)
            views.setProgressBar(id, 100, percent, false)
            views.setContentDescription(id, "$percent% ${payload.localized("widget.remaining", "remaining")}")
        } else {
            views.setViewVisibility(id, View.GONE)
        }
    }

    private fun deepLink(headline: WidgetHeadline?): Uri = headline?.item?.let { WidgetDeepLinks.buildOccurrenceUri(it.occurrenceUid) }
        ?: WidgetDeepLinks.buildDashboardUri()

    // =========================================================================
    // EKADASHI — compact (2x2)
    // =========================================================================
    private fun buildSmallWidget(context: Context, payload: WidgetPayload, headline: WidgetHeadline?, now: Instant): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_small)
        views.setTextColor(R.id.widget_small_badge, android.graphics.Color.WHITE)

        if (headline != null) {
            val item = headline.item
            views.setTextViewText(R.id.widget_small_badge, badge(payload, headline))
            views.setTextViewText(R.id.widget_small_name, displayName(item))
            views.setTextViewText(R.id.widget_small_date, listOf(date(payload, item), item.paksha).filter { it.isNotBlank() }.joinToString(" • "))
            val (label, value) = countdown(payload, headline)
            views.setTextViewText(R.id.widget_small_countdown_label, label)
            views.setViewVisibility(R.id.widget_small_countdown_label, if (label.isEmpty()) View.GONE else View.VISIBLE)
            views.setTextViewText(R.id.widget_small_countdown_value, value)
        } else {
            views.setTextViewText(R.id.widget_small_badge, payload.localized("widget.notice", "NOTICE"))
            views.setTextViewText(R.id.widget_small_name, payload.localized("widget.title", "Ekadashi Calendar"))
            views.setTextViewText(R.id.widget_small_date, if (WidgetTimeline.all(payload).isEmpty()) payload.localized("widget.open_app_to_refresh", "") else payload.localized("widget.no_next", ""))
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
    private fun buildMediumWidget(context: Context, payload: WidgetPayload, headline: WidgetHeadline?, now: Instant): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_medium)
        views.setTextViewText(R.id.widget_medium_fasting_label, payload.localized("widget.fasting_starts", "Fasting Start"))
        views.setTextViewText(R.id.widget_medium_parana_label, payload.localized("widget.parana_window", "Parana Window"))

        if (headline != null) {
            val item = headline.item
            views.setTextViewText(R.id.widget_medium_title, badge(payload, headline))
            views.setTextViewText(R.id.widget_medium_name, displayName(item))
            views.setTextViewText(R.id.widget_medium_date, listOf(date(payload, item), item.paksha).filter { it.isNotBlank() }.joinToString(" • "))
            views.setTextViewText(R.id.widget_medium_location, "📍 ${payload.metadata.locationName}")
            views.setTextViewText(R.id.widget_medium_fasting_time, formatDisplayTime(context, payload, item.fastingStartInstant))
            views.setTextViewText(R.id.widget_medium_parana_time, "${formatDisplayTime(context, payload, item.paranaStartInstant)}\n– ${formatDisplayTime(context, payload, item.paranaEndInstant)}")
            when (item.stateAt(now)) {
                WidgetState.FASTING_ACTIVE -> {
                    views.setTextColor(R.id.widget_medium_badge, context.getColor(R.color.widget_amber))
                    views.setTextViewText(R.id.widget_medium_badge, "${remainingPercent((headline as? WidgetHeadline.Today)?.progress ?: 1.0)}% ${payload.localized("widget.remaining", "remaining")}")
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
                if (headline is WidgetHeadline.Next) formatRemaining(payload, item.fastingStartInstant, now) else value)
        } else {
            views.setTextViewText(R.id.widget_medium_title, payload.localized("widget.title", "Ekadashi Calendar"))
            views.setTextViewText(R.id.widget_medium_badge, payload.localized("widget.notice", "NOTICE"))
            views.setTextViewText(R.id.widget_medium_name, payload.localized("widget.title", "Ekadashi Calendar"))
            views.setTextViewText(R.id.widget_medium_date, if (WidgetTimeline.all(payload).isEmpty()) payload.localized("widget.open_app_to_refresh", "") else payload.localized("widget.no_next", ""))
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
    fun upcoming(context: Context, snapshot: WidgetPayload, appWidgetId: Int? = null, now: Instant = Instant.now(), height: Int = 280): RemoteViews {
        val payload = localized(context, snapshot)
        val views = RemoteViews(context.packageName, R.layout.widget_large)
        // A list only (docs/ROADMAP.md Phase 6): the Ekadashi widget leads with the next one.
        views.setViewVisibility(R.id.widget_large_hero_card, View.GONE)
        views.setTextViewText(R.id.widget_large_upcoming_header, payload.localized("widget.upcoming_ekadashis", "Upcoming Ekadashis"))
        views.setTextViewText(R.id.widget_large_empty, if (WidgetTimeline.all(payload).isEmpty()) payload.localized("widget.open_app_to_refresh", "Open app to refresh") else payload.localized("widget.no_next", ""))
        views.setTextViewText(R.id.widget_large_footer, if (payload.metadata.locationName.isNotEmpty()) "📍 ${payload.metadata.locationName}" else "")

        val headerIntent = WidgetDeepLinks.createIntent(context, WidgetTimeline.upcoming(payload, now).firstOrNull()?.let { WidgetDeepLinks.buildOccurrenceUri(it.occurrenceUid) } ?: WidgetDeepLinks.buildDashboardUri())
        val headerPendingIntent = PendingIntent.getActivity(
            context, 2, headerIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_large_upcoming_header, headerPendingIntent)
        views.setOnClickPendingIntent(R.id.widget_large_root, headerPendingIntent)
        if (height < 140) {
            views.setViewVisibility(R.id.widget_large_upcoming_header, View.GONE)
            views.setViewVisibility(R.id.widget_large_footer, View.GONE)
        }

        // Set up Scrollable ListView Collection via EkadashiListWidgetService
        if (appWidgetId != null) {
            val serviceIntent = Intent(context, EkadashiListWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_large_list, serviceIntent)
            views.setEmptyView(R.id.widget_large_list, R.id.widget_large_empty)

            // Each row fills in its exact occurrence UID on the explicit app intent.
            val itemClickIntent = Intent(context, com.applausestudios.ekadashi_calendar.MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
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
        }

        return views
    }

    private fun formatRemaining(payload: WidgetPayload, target: Instant?, now: Instant): String {
        if (target == null) return "--"
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

    private fun formatDisplayTime(context: Context, payload: WidgetPayload, instant: Instant?): String {
        if (instant == null) return "--"
        return try {
            // The app language's own AM/PM words (Java writes them in Latin
            // letters for most Indian languages).
            val local = instant.atZone(payload.zoneId())
            val config = android.content.res.Configuration(context.resources.configuration)
            config.setLocale(java.util.Locale.forLanguageTag(payload.metadata.locale))
            val localized = context.createConfigurationContext(config)
            val marker = localized.getString(if (local.hour < 12) R.string.widget_am else R.string.widget_pm)
            val hour = if (local.hour % 12 == 0) 12 else local.hour % 12
            "%d:%02d %s".format(java.util.Locale.ROOT, hour, local.minute, marker)
        } catch (e: Exception) {
            "--"
        }
    }
}
