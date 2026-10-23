package com.applausestudios.ekadashi_calendar.widget.service

import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.applausestudios.ekadashi_calendar.R
import com.applausestudios.ekadashi_calendar.widget.model.WidgetPayload
import com.applausestudios.ekadashi_calendar.widget.model.WidgetTimeline
import com.applausestudios.ekadashi_calendar.widget.ui.WidgetRenderer
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

    @Volatile private var snapshot = WidgetPayload.fallback()

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
        try {
            val payload = WidgetStorage.getInstance(context).loadPayload().payload
            // Publish one immutable snapshot; never expose a cleared, partially rebuilt list.
            snapshot = payload
            Log.d(TAG, "Loaded ${WidgetTimeline.upcoming(payload).size} upcoming Ekadashi items for scrollable list")
        } catch (e: Exception) {
            Log.e(TAG, "Error loading upcoming list items: ${e.message}", e)
        }
    }

    override fun onDestroy() {
        snapshot = WidgetPayload.fallback()
    }

    override fun getCount(): Int = WidgetTimeline.upcoming(snapshot).size

    override fun getViewAt(position: Int): RemoteViews {
        val payload = snapshot
        val item = WidgetTimeline.upcoming(payload).getOrNull(position)
        // Android 16 can finish an older collection request after an empty refresh/destroy.
        // It parcels every returned row without a null check; keep late rows blank and inert.
        return if (item != null) WidgetRenderer.upcomingRow(context, payload, item)
        else RemoteViews(context.packageName, R.layout.widget_upcoming_item).apply {
            setTextViewText(R.id.widget_upcoming_item_name, "")
            setTextViewText(R.id.widget_upcoming_item_date, "")
            setTextViewText(R.id.widget_upcoming_item_decoration_0, "")
        }
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = WidgetTimeline.upcoming(snapshot).getOrNull(position)?.id?.toLong() ?: position.toLong()

    override fun hasStableIds(): Boolean = true
}
