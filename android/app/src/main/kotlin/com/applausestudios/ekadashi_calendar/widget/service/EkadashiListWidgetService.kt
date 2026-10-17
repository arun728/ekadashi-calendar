package com.applausestudios.ekadashi_calendar.widget.service

import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
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
            val upcoming = com.applausestudios.ekadashi_calendar.widget.model.WidgetTimeline.upcoming(payload)
            items.addAll(upcoming)
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
        val views = com.applausestudios.ekadashi_calendar.widget.ui.WidgetRenderer.upcomingRow(context, WidgetStorage.getInstance(context).loadPayload().payload, item)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = items.getOrNull(position)?.id?.toLong() ?: position.toLong()

    override fun hasStableIds(): Boolean = true
}
