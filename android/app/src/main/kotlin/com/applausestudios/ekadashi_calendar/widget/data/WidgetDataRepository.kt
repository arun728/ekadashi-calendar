package com.applausestudios.ekadashi_calendar.widget.data

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.applausestudios.ekadashi_calendar.widget.model.EkadashiItem
import com.applausestudios.ekadashi_calendar.widget.model.TodayStatus
import com.applausestudios.ekadashi_calendar.widget.model.WidgetPayload
import com.applausestudios.ekadashi_calendar.widget.storage.CacheStatus
import com.applausestudios.ekadashi_calendar.widget.storage.LoadResult

/**
 * Single controlled repository for widget snapshot persistence and retrieval.
 * Validates the cached Home engine schedule; missing data shows a localized refresh prompt.
 */
class WidgetDataRepository private constructor(private val context: Context) {

    companion object {
        private const val TAG = "EKADASHI_WIDGET"
        private const val PREFS_NAME = "ekadashi_widget_prefs_v2"
        private const val KEY_PAYLOAD = "key_widget_payload_json"
        private const val KEY_LAST_SAVED = "key_widget_last_saved_timestamp"
        private const val EXPECTED_SCHEMA_VERSION = 2
        private const val MAX_CACHE_AGE_MS = 14L * 24 * 60 * 60 * 1000 // 14 days

        // Holds only the application context (see getInstance), which lives as
        // long as the process, so nothing can leak.
        @SuppressLint("StaticFieldLeak")
        @Volatile
        private var instance: WidgetDataRepository? = null

        fun getInstance(context: Context): WidgetDataRepository {
            val application = context.applicationContext
            return instance?.takeIf { it.context === application } ?: synchronized(this) {
                instance?.takeIf { it.context === application } ?: WidgetDataRepository(application).also { instance = it }
            }
        }
    }

    private val prefs: SharedPreferences by lazy {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    @Synchronized
    fun saveWidgetSnapshot(payload: WidgetPayload): Boolean {
        return try {
            val jsonString = payload.toJsonString()
            val now = System.currentTimeMillis()
            val committed = prefs.edit()
                .putString(KEY_PAYLOAD, jsonString)
                .putLong(KEY_LAST_SAVED, now)
                .commit()
            Log.i(TAG, "Successfully saved widget snapshot (${jsonString.length} chars, next: ${payload.nextEkadashi?.name}).")
            committed
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save widget snapshot: ${e.message}", e)
            false
        }
    }

    @Synchronized
    fun getWidgetSnapshot(): LoadResult {
        val rawJson = prefs.getString(KEY_PAYLOAD, null)

        if (rawJson == null) return LoadResult(localizedFallback(), CacheStatus.UNAVAILABLE)

        return try {
            val payload = WidgetPayload.fromJsonString(rawJson)

            // 1. Schema Validation
            if (payload.metadata.schemaVersion != EXPECTED_SCHEMA_VERSION) {
                Log.w(TAG, "Schema mismatch: expected $EXPECTED_SCHEMA_VERSION, got ${payload.metadata.schemaVersion}")
                return LoadResult(localizedFallback(), CacheStatus.INVALID)
            }

            // 2. Metadata Validation
            val meta = payload.metadata
            if (meta.generatedAtUTC.isEmpty() || meta.lastUpdatedAtUTC.isEmpty() || meta.timezone.isEmpty()) {
                Log.w(TAG, "Incomplete metadata in snapshot")
                return LoadResult(localizedFallback(), CacheStatus.INVALID)
            }

            // 3. Next Ekadashi Validation
            val next = payload.nextEkadashi
            if (next != null) {
                if (next.name.isEmpty() || next.date.isEmpty()) {
                    Log.w(TAG, "Invalid nextEkadashi record (missing name or date)")
                    return LoadResult(localizedFallback(), CacheStatus.INVALID)
                }

                val fStart = next.fastingStartInstant
                val pStart = next.paranaStartInstant
                val pEnd = next.paranaEndInstant

                if (fStart == null || pStart == null || pEnd == null) {
                    Log.w(TAG, "Unparseable timestamps in nextEkadashi (${next.fastingStartUTC})")
                    // Do not fail immediately if targetTimestampInstant is valid
                    if (next.targetTimestampInstant == null) {
                        return LoadResult(localizedFallback(), CacheStatus.INVALID)
                    }
                }
            }

            // 4. Freshness Validation
            val lastSaved = prefs.getLong(KEY_LAST_SAVED, 0L)
            if (lastSaved > 0 && (System.currentTimeMillis() - lastSaved) > MAX_CACHE_AGE_MS) {
                Log.w(TAG, "Snapshot is stale (> 14 days)")
                return LoadResult(payload, CacheStatus.STALE)
            }

            LoadResult(payload, CacheStatus.VALID)
        } catch (e: Exception) {
            Log.e(TAG, "Error decoding widget snapshot: ${e.message}", e)
            LoadResult(localizedFallback(), CacheStatus.CORRUPTED)
        }
    }

    fun getNextEkadashi(): EkadashiItem? = getWidgetSnapshot().payload.nextEkadashi

    fun getTodayStatus(): TodayStatus? = getWidgetSnapshot().payload.today

    fun getUpcomingEkadashis(): List<EkadashiItem> = getWidgetSnapshot().payload.upcomingEkadashis

    fun isSnapshotValid(): Boolean = getWidgetSnapshot().status.canDisplay

    @Synchronized
    fun clearInvalidSnapshot() {
        prefs.edit().clear().commit()
        Log.i(TAG, "Cleared invalid widget snapshot.")
    }

    private fun localizedFallback(): WidgetPayload = WidgetPayload.fallback().copy(
        metadata = WidgetPayload.fallback().metadata.copy(locale=WidgetLocalization.locale(context), locationName=""),
        localizedStrings = WidgetLocalization.strings(context))

}
