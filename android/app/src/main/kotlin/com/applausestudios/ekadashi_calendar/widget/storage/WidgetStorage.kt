package com.applausestudios.ekadashi_calendar.widget.storage

import android.content.Context
import com.applausestudios.ekadashi_calendar.widget.data.WidgetDataRepository
import com.applausestudios.ekadashi_calendar.widget.model.WidgetPayload

enum class CacheStatus(val canDisplay: Boolean) {
    VALID(true),
    STALE(true),
    INVALID(false),
    CORRUPTED(false),
    UNAVAILABLE(false)
}

data class LoadResult(
    val payload: WidgetPayload,
    val status: CacheStatus
)

/**
 * Delegating façade maintaining full backwards compatibility while utilizing WidgetDataRepository.
 */
class WidgetStorage(context: Context) {
    private val repository = WidgetDataRepository.getInstance(context)

    companion object {
        @Volatile
        private var instance: WidgetStorage? = null

        fun getInstance(context: Context): WidgetStorage {
            return instance ?: synchronized(this) {
                instance ?: WidgetStorage(context).also { instance = it }
            }
        }
    }

    fun savePayload(payload: WidgetPayload): Boolean = repository.saveWidgetSnapshot(payload)

    fun loadPayload(): LoadResult = repository.getWidgetSnapshot()

    fun clearPayload() = repository.clearInvalidSnapshot()
}
