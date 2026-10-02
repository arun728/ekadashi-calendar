package com.applausestudios.ekadashi_calendar.widget.data

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.applausestudios.ekadashi_calendar.widget.model.EkadashiItem
import com.applausestudios.ekadashi_calendar.widget.model.TodayStatus
import com.applausestudios.ekadashi_calendar.widget.model.WidgetMetadata
import com.applausestudios.ekadashi_calendar.widget.model.WidgetPayload
import com.applausestudios.ekadashi_calendar.widget.model.WidgetState
import com.applausestudios.ekadashi_calendar.widget.storage.CacheStatus
import com.applausestudios.ekadashi_calendar.widget.storage.LoadResult
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.time.Instant
import java.time.format.DateTimeFormatter

/**
 * Single controlled repository for widget snapshot persistence and retrieval.
 * Implements strict cache validation and automatic initial-seed loading on first install.
 */
class WidgetDataRepository private constructor(private val context: Context) {

    companion object {
        private const val TAG = "EKADASHI_WIDGET"
        private const val PREFS_NAME = "ekadashi_widget_prefs_v2"
        private const val KEY_PAYLOAD = "key_widget_payload_json"
        private const val KEY_LAST_SAVED = "key_widget_last_saved_timestamp"
        private const val EXPECTED_SCHEMA_VERSION = 2
        private const val MAX_CACHE_AGE_MS = 14L * 24 * 60 * 60 * 1000 // 14 days

        @Volatile
        private var instance: WidgetDataRepository? = null

        fun getInstance(context: Context): WidgetDataRepository {
            return instance ?: synchronized(this) {
                instance ?: WidgetDataRepository(context.applicationContext).also { instance = it }
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
            prefs.edit()
                .putString(KEY_PAYLOAD, jsonString)
                .putLong(KEY_LAST_SAVED, now)
                .commit()
            Log.i(TAG, "Successfully saved widget snapshot (${jsonString.length} chars, next: ${payload.nextEkadashi?.name}).")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save widget snapshot: ${e.message}", e)
            false
        }
    }

    @Synchronized
    fun getWidgetSnapshot(): LoadResult {
        var rawJson = prefs.getString(KEY_PAYLOAD, null)

        // Cold-start self initialization: if SharedPreferences is empty, attempt to seed from bundled asset
        if (rawJson == null) {
            Log.i(TAG, "No cached snapshot found in SharedPreferences. Attempting asset seed...")
            val seededPayload = seedFromBundledAssets()
            if (seededPayload != null) {
                saveWidgetSnapshot(seededPayload)
                return LoadResult(seededPayload, CacheStatus.VALID)
            }
            return LoadResult(WidgetPayload.fallback(), CacheStatus.UNAVAILABLE)
        }

        return try {
            val payload = WidgetPayload.fromJsonString(rawJson)

            // 1. Schema Validation
            if (payload.metadata.schemaVersion != EXPECTED_SCHEMA_VERSION) {
                Log.w(TAG, "Schema mismatch: expected $EXPECTED_SCHEMA_VERSION, got ${payload.metadata.schemaVersion}")
                return LoadResult(WidgetPayload.fallback(), CacheStatus.INVALID)
            }

            // 2. Metadata Validation
            val meta = payload.metadata
            if (meta.generatedAtUTC.isEmpty() || meta.lastUpdatedAtUTC.isEmpty() || meta.timezone.isEmpty()) {
                Log.w(TAG, "Incomplete metadata in snapshot")
                return LoadResult(WidgetPayload.fallback(), CacheStatus.INVALID)
            }

            // 3. Next Ekadashi Validation
            val next = payload.nextEkadashi
            if (next != null) {
                if (next.name.isEmpty() || next.date.isEmpty()) {
                    Log.w(TAG, "Invalid nextEkadashi record (missing name or date)")
                    return LoadResult(WidgetPayload.fallback(), CacheStatus.INVALID)
                }

                val fStart = next.fastingStartInstant
                val pStart = next.paranaStartInstant
                val pEnd = next.paranaEndInstant

                if (fStart == null || pStart == null || pEnd == null) {
                    Log.w(TAG, "Unparseable timestamps in nextEkadashi (${next.fastingStartUTC})")
                    // Do not fail immediately if targetTimestampInstant is valid
                    if (next.targetTimestampInstant == null) {
                        return LoadResult(WidgetPayload.fallback(), CacheStatus.INVALID)
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
            val seededPayload = seedFromBundledAssets()
            if (seededPayload != null) {
                saveWidgetSnapshot(seededPayload)
                return LoadResult(seededPayload, CacheStatus.VALID)
            }
            LoadResult(WidgetPayload.fallback(), CacheStatus.CORRUPTED)
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

    /**
     * Seeds canonical Ekadashi data from bundled Flutter asset 'flutter_assets/assets/ekadashi_data.json'.
     * Guarantees that when a widget is added on first install, real data is displayed immediately.
     */
    private fun seedFromBundledAssets(): WidgetPayload? {
        val assetPaths = listOf(
            "flutter_assets/assets/ekadashi_data.json",
            "assets/ekadashi_data.json"
        )

        for (path in assetPaths) {
            try {
                context.assets.open(path).use { inputStream ->
                    val reader = BufferedReader(InputStreamReader(inputStream))
                    val content = reader.readText()
                    val root = JSONObject(content)
                    val ekadashisArray = root.optJSONArray("ekadashis") ?: return@use

                    val now = Instant.now()
                    val targetTz = "IST"

                    var nextEkadashi: EkadashiItem? = null
                    val upcoming = mutableListOf<EkadashiItem>()

                    for (i in 0 until ekadashisArray.length()) {
                        val ekObj = ekadashisArray.getJSONObject(i)
                        val id = ekObj.optInt("id", i + 1)
                        val nameObj = ekObj.optJSONObject("name")
                        val name = nameObj?.optString("en") ?: "Ekadashi"
                        val paksha = ekObj.optString("paksha", "")
                        val month = ekObj.optString("month", "")

                        val timingObj = ekObj.optJSONObject("timing")?.optJSONObject(targetTz)
                            ?: ekObj.optJSONObject("timing")?.optJSONObject("IST")
                            ?: continue

                        val date = timingObj.optString("date", "")
                        val fStart = timingObj.optString("fasting_start", "")
                        val pStart = timingObj.optString("parana_start", "")
                        val pEnd = timingObj.optString("parana_end", "")

                        val item = EkadashiItem(
                            id = id,
                            name = name,
                            localizedName = name,
                            date = date,
                            localizedDate = date,
                            paksha = paksha,
                            month = month,
                            fastingStartUTC = fStart,
                            fastingEndUTC = pStart,
                            paranaStartUTC = pStart,
                            paranaEndUTC = pEnd,
                            targetTimestampUTC = fStart,
                            countdownTarget = fStart
                        )

                        val pEndInstant = item.paranaEndInstant
                        if (pEndInstant != null && now.isBefore(pEndInstant)) {
                            if (nextEkadashi == null) {
                                nextEkadashi = item
                            } else if (upcoming.size < 10) {
                                upcoming.add(item)
                            }
                        }
                    }

                    if (nextEkadashi != null) {
                        Log.i(TAG, "Successfully seeded initial widget payload from asset: $path (next: ${nextEkadashi.name})")
                        return WidgetPayload(
                            metadata = WidgetMetadata(
                                schemaVersion = 2,
                                generatedAtUTC = now.toString(),
                                lastUpdatedAtUTC = now.toString(),
                                timezone = targetTz,
                                locationName = "India (IST)"
                            ),
                            currentState = nextEkadashi.stateAt(now),
                            nextEkadashi = nextEkadashi,
                            today = TodayStatus(
                                isEkadashi = false,
                                name = nextEkadashi.name,
                                fastingStatus = "Upcoming",
                                fastingStartUTC = nextEkadashi.fastingStartUTC,
                                paranaStartUTC = nextEkadashi.paranaStartUTC,
                                paranaEndUTC = nextEkadashi.paranaEndUTC,
                                state = "BEFORE_EKADASHI"
                            ),
                            upcomingEkadashis = upcoming,
                            localizedStrings = mapOf(
                                "widget.title" to "Ekadashi Calendar",
                                "widget.next_ekadashi" to "NEXT EKADASHI",
                                "widget.fasting_active" to "Fasting Active",
                                "widget.parana_available" to "Break Fasting (Parana)",
                                "widget.parana_completed" to "Parana Completed",
                                "widget.upcoming_ekadashis" to "Upcoming Ekadashis",
                                "widget.fasting_starts" to "Fasting Start",
                                "widget.parana_window" to "Parana Window"
                            )
                        )
                    }
                }
            } catch (e: Exception) {
                Log.d(TAG, "Asset seed failed for $path: ${e.message}")
            }
        }
        return null
    }
}
