package com.applausestudios.ekadashi_calendar.widget.service

import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.applausestudios.ekadashi_calendar.R
import com.applausestudios.ekadashi_calendar.widget.deeplink.WidgetDeepLinks
import com.applausestudios.ekadashi_calendar.widget.model.EkadashiItem
import com.applausestudios.ekadashi_calendar.widget.storage.WidgetStorage

/**
 * RemoteViewsService providing the scrollable collection adapter for Widget C (Upcoming Ekadashis).
 */
class EkadashiListWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return EkadashiListRemoteViewsFactory(this.applicationContext, intent)
    }
}

/**
 * RemoteViewsFactory that dynamically populates upcoming Ekadashis from the cached data model.
 */
class EkadashiListRemoteViewsFactory(
    private val context: Context,
    private val intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private val items = ArrayList<EkadashiItem>()

    companion object {
        private const val TAG = "EKADASHI_LIST_FACTORY"
    }

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    private fun loadData() {
        items.clear()
        try {
            val storage = WidgetStorage.getInstance(context)
            val payload = storage.loadPayload().payload
            val upcoming = com.applausestudios.ekadashi_calendar.widget.model.WidgetTimeline.remaining(payload)
            val now=java.time.Instant.now()
            items.addAll(upcoming.filter { it.paranaEndInstant?.isAfter(now)==true })
            Log.d(TAG, "Loaded ${items.size} upcoming Ekadashi items for scrollable list")
        } catch (e: Exception) {
            Log.e(TAG, "Error loading upcoming list items: ${e.message}", e)
        }
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews? {
        if (position < 0 || position >= items.size) return null

        val item = items[position]
        val views = RemoteViews(context.packageName, R.layout.widget_upcoming_item)

        val displayName = if (item.localizedName.isNotEmpty()) item.localizedName else item.name
        views.setTextViewText(R.id.widget_upcoming_item_name, displayName)

        val formattedDate = item.localizedDate.ifEmpty { item.date }
        views.setTextViewText(R.id.widget_upcoming_item_date, formattedDate)

        // Deep link fill-in intent: ekadashi://calendar?date={iso_date}
        val fillInIntent = Intent().apply {
            data = WidgetDeepLinks.buildCalendarUri(item.date)
        }
        views.setOnClickFillInIntent(R.id.widget_upcoming_item_root, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = items.getOrNull(position)?.id?.toLong() ?: position.toLong()

    override fun hasStableIds(): Boolean = true
}
