package com.applausestudios.ekadashi_calendar.widget.ui

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.FrameLayout
import android.widget.ListView
import com.applausestudios.ekadashi_calendar.R
import com.applausestudios.ekadashi_calendar.widget.model.WidgetHeadline
import com.applausestudios.ekadashi_calendar.widget.model.WidgetPayload
import com.applausestudios.ekadashi_calendar.widget.model.WidgetTimeline
import java.time.Instant

/** A regular native view for Settings; no widget binding permission or fake AppWidget ID. */
class WidgetPreviewHost(context: Context, private val onOpen: (String) -> Unit) : FrameLayout(context) {
    fun update(payload: WidgetPayload, upcoming: Boolean, width: Int, height: Int, now: Instant, liveCountdown: Boolean = false) {
        removeAllViews()
        val remote = if (upcoming) WidgetRenderer.upcoming(context, payload, now = now, height = height)
            else WidgetRenderer.single(context, payload, width, height, now, liveCountdown)
        val content = remote.apply(context, this)
        addView(content, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        if (upcoming) {
            val items = WidgetTimeline.upcoming(payload, now)
            val list = content.findViewById<ListView>(R.id.widget_large_list)
            list.adapter = object : BaseAdapter() {
                override fun getCount() = items.size
                override fun getItem(position: Int) = items[position]
                override fun getItemId(position: Int) = items[position].occurrenceUid.hashCode().toLong()
                override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
                    val item = items[position]
                    return WidgetRenderer.upcomingRow(context, payload, item, collectionItem = false).apply(context, parent).apply {
                        setOnClickListener { onOpen(item.occurrenceUid) }
                    }
                }
            }
            list.emptyView = content.findViewById(R.id.widget_large_empty)
            val openFirst = View.OnClickListener { items.firstOrNull()?.let { onOpen(it.occurrenceUid) } }
            content.findViewById<View>(R.id.widget_large_upcoming_header).setOnClickListener(openFirst)
            content.setOnClickListener(openFirst)
        } else {
            content.setOnClickListener { WidgetHeadline.of(payload, now)?.let { onOpen(it.item.occurrenceUid) } }
        }
    }
}
