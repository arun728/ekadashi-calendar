package com.applausestudios.ekadashi_calendar.widget.model
import java.time.Instant
object WidgetTimeline {
 fun remaining(payload:WidgetPayload,now:Instant=Instant.now()):List<EkadashiItem> =
   (listOfNotNull(payload.nextEkadashi)+payload.upcomingEkadashis)
     .distinctBy { it.id }.sortedBy { it.fastingStartInstant }
     .filter { it.paranaEndInstant?.isAfter(now)==true }
}
