package com.applausestudios.ekadashi_calendar.widget.model

import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.time.ZonedDateTime

enum class WidgetState(val value: String) {
    BEFORE_EKADASHI("BEFORE_EKADASHI"),
    FASTING_ACTIVE("FASTING_ACTIVE"),
    PARANA_AVAILABLE("PARANA_AVAILABLE"),
    PARANA_COMPLETED("PARANA_COMPLETED"),
    FALLBACK("FALLBACK");

    companion object {
        fun fromString(value: String?): WidgetState {
            return entries.find { it.value.equals(value, ignoreCase = true) } ?: BEFORE_EKADASHI
        }
    }
}

data class WidgetMetadata(
    val schemaVersion: Int = 2,
    val dataVersion: String = "2.0.0",
    val generatedAtUTC: String,
    val lastUpdatedAtUTC: String,
    val lastSuccessfulCalculationUTC: String = lastUpdatedAtUTC,
    val locale: String = "en",
    val timezone: String = "IST",
    val locationName: String = "Chennai",
    val tradition: String = "General",
    val latitude: Double? = null,
    val longitude: Double? = null,
    val calculationVersion: String = "v10.1"
) {
    fun toJsonObject(): JSONObject {
        return JSONObject().apply {
            put("schemaVersion", schemaVersion)
            put("dataVersion", dataVersion)
            put("generatedAtUTC", generatedAtUTC)
            put("lastUpdatedAtUTC", lastUpdatedAtUTC)
            put("lastSuccessfulCalculationUTC", lastSuccessfulCalculationUTC)
            put("locale", locale)
            put("timezone", timezone)
            put("locationName", locationName)
            put("location", locationName)
            put("tradition", tradition)
            if (latitude != null) put("latitude", latitude)
            if (longitude != null) put("longitude", longitude)
            put("calculationVersion", calculationVersion)
        }
    }

    companion object {
        fun fromJsonObject(json: JSONObject): WidgetMetadata {
            val gen = json.optString("generatedAtUTC", Instant.now().toString())
            val updated = json.optString("lastUpdatedAtUTC", gen)
            val loc = if (json.has("locationName")) json.optString("locationName") else json.optString("location", "Chennai")

            return WidgetMetadata(
                schemaVersion = json.optInt("schemaVersion", 2),
                dataVersion = json.optString("dataVersion", "2.0.0"),
                generatedAtUTC = gen,
                lastUpdatedAtUTC = updated,
                lastSuccessfulCalculationUTC = json.optString("lastSuccessfulCalculationUTC", updated),
                locale = json.optString("locale", "en"),
                timezone = json.optString("timezone", "IST"),
                locationName = loc,
                tradition = json.optString("tradition", "General"),
                latitude = if (json.has("latitude")) json.optDouble("latitude") else null,
                longitude = if (json.has("longitude")) json.optDouble("longitude") else null,
                calculationVersion = json.optString("calculationVersion", "v10.1")
            )
        }
    }
}

data class EkadashiItem(
    val id: Int,
    val name: String,
    val localizedName: String,
    val date: String, // YYYY-MM-DD
    val localizedDate: String,
    val paksha: String,
    val month: String,
    val fastingStartUTC: String,
    val fastingEndUTC: String,
    val paranaStartUTC: String,
    val paranaEndUTC: String,
    val targetTimestampUTC: String = fastingStartUTC,
    val countdownTarget: String = fastingStartUTC,
    val description: String? = null
) {
    fun toJsonObject(): JSONObject {
        return JSONObject().apply {
            put("id", id)
            put("name", name)
            put("localizedName", localizedName)
            put("date", date)
            put("localizedDate", localizedDate)
            put("paksha", paksha)
            put("month", month)
            put("fastingStartUTC", fastingStartUTC)
            put("fastingEndUTC", fastingEndUTC)
            put("paranaStartUTC", paranaStartUTC)
            put("paranaEndUTC", paranaEndUTC)
            put("targetTimestampUTC", targetTimestampUTC)
            put("countdownTarget", countdownTarget)
            if (description != null) put("description", description)
        }
    }

    val fastingStartInstant: Instant?
        get() = parseInstant(fastingStartUTC)

    val fastingEndInstant: Instant?
        get() = parseInstant(fastingEndUTC)

    val paranaStartInstant: Instant?
        get() = parseInstant(paranaStartUTC)

    val paranaEndInstant: Instant?
        get() = parseInstant(paranaEndUTC)

    val targetTimestampInstant: Instant?
        get() = parseInstant(targetTimestampUTC) ?: fastingStartInstant

    val countdownTargetInstant: Instant?
        get() = parseInstant(countdownTarget) ?: targetTimestampInstant ?: fastingStartInstant

    fun stateAt(instant: Instant = Instant.now()): WidgetState {
        val fStart = fastingStartInstant ?: return WidgetState.BEFORE_EKADASHI
        val pStart = paranaStartInstant ?: return WidgetState.BEFORE_EKADASHI
        val pEnd = paranaEndInstant ?: return WidgetState.BEFORE_EKADASHI

        return when {
            instant.isBefore(fStart) -> WidgetState.BEFORE_EKADASHI
            !instant.isBefore(fStart) && instant.isBefore(pStart) -> WidgetState.FASTING_ACTIVE
            !instant.isBefore(pStart) && instant.isBefore(pEnd) -> WidgetState.PARANA_AVAILABLE
            else -> WidgetState.PARANA_COMPLETED
        }
    }

    companion object {
        fun parseInstant(str: String): Instant? {
            if (str.isEmpty()) return null
            return try {
                Instant.parse(str)
            } catch (e1: Exception) {
                try {
                    OffsetDateTime.parse(str).toInstant()
                } catch (e2: Exception) {
                    try {
                        ZonedDateTime.parse(str).toInstant()
                    } catch (e3: Exception) {
                        try {
                            LocalDate.parse(str).atStartOfDay(ZoneOffset.UTC).toInstant()
                        } catch (e4: Exception) {
                            null
                        }
                    }
                }
            }
        }

        fun fromJsonObject(json: JSONObject): EkadashiItem {
            val fStart = json.optString("fastingStartUTC", "")
            val target = if (json.has("targetTimestampUTC")) json.optString("targetTimestampUTC") else fStart
            val countTarget = if (json.has("countdownTarget")) json.optString("countdownTarget") else target

            return EkadashiItem(
                id = json.optInt("id", 0),
                name = json.optString("name", ""),
                localizedName = json.optString("localizedName", json.optString("name", "")),
                date = if (json.has("date")) json.optString("date") else json.optString("dateISO", ""),
                localizedDate = if (json.has("localizedDate")) json.optString("localizedDate") else json.optString("displayDate", ""),
                paksha = json.optString("paksha", ""),
                month = json.optString("month", ""),
                fastingStartUTC = fStart,
                fastingEndUTC = json.optString("fastingEndUTC", ""),
                paranaStartUTC = json.optString("paranaStartUTC", ""),
                paranaEndUTC = json.optString("paranaEndUTC", ""),
                targetTimestampUTC = target,
                countdownTarget = countTarget,
                description = if (json.has("description")) json.optString("description") else null
            )
        }
    }
}

data class TodayStatus(
    val isEkadashi: Boolean,
    val name: String,
    val fastingStatus: String,
    val fastingStartUTC: String,
    val paranaStartUTC: String,
    val paranaEndUTC: String,
    val state: String
) {
    val fastingStartInstant: Instant? get() = EkadashiItem.parseInstant(fastingStartUTC)
    val paranaStartInstant: Instant? get() = EkadashiItem.parseInstant(paranaStartUTC)
    val paranaEndInstant: Instant? get() = EkadashiItem.parseInstant(paranaEndUTC)

    fun toJsonObject(): JSONObject = JSONObject().apply {
        put("isEkadashi", isEkadashi)
        put("name", name)
        put("fastingStatus", fastingStatus)
        put("fastingStartUTC", fastingStartUTC)
        put("paranaStartUTC", paranaStartUTC)
        put("paranaEndUTC", paranaEndUTC)
        put("state", state)
    }

    companion object {
        fun fromJsonObject(json: JSONObject): TodayStatus {
            return TodayStatus(
                isEkadashi = json.optBoolean("isEkadashi", false),
                name = json.optString("name", ""),
                fastingStatus = json.optString("fastingStatus", "No Ekadashi Today"),
                fastingStartUTC = json.optString("fastingStartUTC", ""),
                paranaStartUTC = json.optString("paranaStartUTC", ""),
                paranaEndUTC = json.optString("paranaEndUTC", ""),
                state = json.optString("state", "NO_EKADASHI_TODAY")
            )
        }

        fun empty(): TodayStatus = TodayStatus(
            isEkadashi = false,
            name = "",
            fastingStatus = "No Ekadashi Today",
            fastingStartUTC = "",
            paranaStartUTC = "",
            paranaEndUTC = "",
            state = "NO_EKADASHI_TODAY"
        )
    }
}

data class WidgetPayload(
    val metadata: WidgetMetadata,
    val currentState: WidgetState,
    val nextEkadashi: EkadashiItem?,
    val today: TodayStatus? = null,
    val upcomingEkadashis: List<EkadashiItem>,
    val localizedStrings: Map<String, String>
) {
    fun localized(key: String, default: String = ""): String {
        return localizedStrings[key] ?: default
    }

    fun toJsonString(): String {
        val json = JSONObject().apply {
            put("metadata", metadata.toJsonObject())
            put("currentState", currentState.value)
            if (nextEkadashi != null) {
                put("nextEkadashi", nextEkadashi.toJsonObject())
            } else {
                put("nextEkadashi", JSONObject.NULL)
            }

            if (today != null) {
                put("today", today.toJsonObject())
            }

            val upcomingArray = JSONArray()
            upcomingEkadashis.forEach { upcomingArray.put(it.toJsonObject()) }
            put("upcomingEkadashis", upcomingArray)
            put("upcoming", upcomingArray)

            val stringsObj = JSONObject()
            localizedStrings.forEach { (k, v) -> stringsObj.put(k, v) }
            put("localizedStrings", stringsObj)
        }
        return json.toString()
    }

    companion object {
        fun fromJsonString(jsonStr: String): WidgetPayload {
            val json = JSONObject(jsonStr)
            val metadata = WidgetMetadata.fromJsonObject(json.getJSONObject("metadata"))
            val state = WidgetState.fromString(json.optString("currentState"))

            val nextObj = json.optJSONObject("nextEkadashi")
            val nextEkadashi = if (nextObj != null && nextObj != JSONObject.NULL) {
                EkadashiItem.fromJsonObject(nextObj)
            } else null

            val todayObj = json.optJSONObject("today")
            val today = if (todayObj != null && todayObj != JSONObject.NULL) {
                TodayStatus.fromJsonObject(todayObj)
            } else null

            val upcomingList = mutableListOf<EkadashiItem>()
            val upcomingArray = json.optJSONArray("upcomingEkadashis") ?: json.optJSONArray("upcoming")
            if (upcomingArray != null) {
                for (i in 0 until upcomingArray.length()) {
                    val item = upcomingArray.optJSONObject(i)
                    if (item != null) upcomingList.add(EkadashiItem.fromJsonObject(item))
                }
            }

            val stringsMap = mutableMapOf<String, String>()
            val stringsObj = json.optJSONObject("localizedStrings")
            if (stringsObj != null) {
                val keys = stringsObj.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    stringsMap[key] = stringsObj.optString(key)
                }
            }

            return WidgetPayload(
                metadata = metadata,
                currentState = state,
                nextEkadashi = nextEkadashi,
                today = today,
                upcomingEkadashis = upcomingList,
                localizedStrings = stringsMap
            )
        }

        fun fallback(): WidgetPayload {
            return WidgetPayload(
                metadata = WidgetMetadata(
                    generatedAtUTC = Instant.now().toString(),
                    lastUpdatedAtUTC = Instant.now().toString()
                ),
                currentState = WidgetState.FALLBACK,
                nextEkadashi = null,
                today = TodayStatus.empty(),
                upcomingEkadashis = emptyList(),
                localizedStrings = mapOf(
                    "widget.title" to "Ekadashi Calendar",
                    "widget.open_app_to_refresh" to "Open app to refresh timings",
                    "widget.next_ekadashi" to "NEXT EKADASHI",
                    "widget.fasting_active" to "Fasting Active",
                    "widget.parana_available" to "Break Fasting (Parana)",
                    "widget.parana_completed" to "Parana Completed"
                )
            )
        }
    }
}
