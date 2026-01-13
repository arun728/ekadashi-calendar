package com.example.ekadashi_calendar

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.work.*
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.concurrent.TimeUnit

/**
 * Notification Scheduler using WorkManager
 *
 * Schedules 4 types of notifications per Ekadashi:
 * 1. 48 hours before fasting starts
 * 2. 24 hours before fasting starts
 * 3. When fasting starts (sunrise time)
 * 4. When parana (break fast) window opens
 */
class NotificationScheduler(private val context: Context) {

    companion object {
        private const val TAG = "NotificationScheduler"
        private const val PREFS_NAME = "notification_prefs"
        private const val KEY_NOTIFICATIONS_ENABLED = "notifications_enabled"
        private const val KEY_REMIND_2_DAYS = "remind_2_days"
        private const val KEY_REMIND_1_DAY = "remind_1_day"
        private const val KEY_REMIND_ON_START = "remind_on_start"
        private const val KEY_REMIND_ON_PARANA = "remind_on_parana"

        // Work tags
        private const val TAG_EKADASHI_NOTIFICATION = "ekadashi_notification"
    }

    private val workManager = WorkManager.getInstance(context)

    private val prefs: SharedPreferences by lazy {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    /**
     * Schedule a single notification
     *
     * @param ekadashiId Unique identifier for the Ekadashi
     * @param scheduledTime When to show the notification
     * @param title Notification title
     * @param body Notification body
     * @param notificationType Type of notification (for tracking)
     */
    fun scheduleNotification(
        ekadashiId: Int,
        scheduledTime: ZonedDateTime,
        title: String,
        body: String,
        notificationType: NotificationType
    ): Boolean {
        val now = ZonedDateTime.now()

        // Don't schedule if time is in the past
        if (scheduledTime.isBefore(now)) {
            Log.d(TAG, "Skipping past notification: $title at $scheduledTime")
            return false
        }

        val delayMillis = Duration.between(now, scheduledTime).toMillis()

        // Create unique work name
        val workName = "ekadashi_${ekadashiId}_${notificationType.value}"
        val notificationId = (ekadashiId * 10) + notificationType.ordinal

        // Input data for the worker
        val inputData = Data.Builder()
            .putString(EkadashiNotificationWorker.KEY_TITLE, title)
            .putString(EkadashiNotificationWorker.KEY_BODY, body)
            .putInt(EkadashiNotificationWorker.KEY_EKADASHI_ID, ekadashiId)
            .putString(EkadashiNotificationWorker.KEY_NOTIFICATION_TYPE, notificationType.value)
            .putInt(EkadashiNotificationWorker.KEY_NOTIFICATION_ID, notificationId)
            .build()

        // Create work request with delay
        val workRequest = OneTimeWorkRequestBuilder<EkadashiNotificationWorker>()
            .setInitialDelay(delayMillis, TimeUnit.MILLISECONDS)
            .setInputData(inputData)
            .addTag(TAG_EKADASHI_NOTIFICATION)
            .addTag("ekadashi_$ekadashiId")
            .setConstraints(
                Constraints.Builder()
                    .setRequiresBatteryNotLow(false) // Allow even on low battery
                    .build()
            )
            .build()

        // Enqueue with REPLACE policy (updates if already exists)
        workManager.enqueueUniqueWork(
            workName,
            ExistingWorkPolicy.REPLACE,
            workRequest
        )

        Log.d(TAG, "Scheduled: $workName for ${scheduledTime.format(DateTimeFormatter.ISO_OFFSET_DATE_TIME)} (delay: ${delayMillis}ms)")
        return true
    }

    /**
     * Schedule all notifications for an Ekadashi
     *
     * @param ekadashiId Unique ID
     * @param ekadashiName Name of the Ekadashi
     * @param fastingStartTime ISO-8601 datetime string
     * @param paranaStartTime ISO-8601 datetime string
     * @param texts Localized notification texts
     */
    fun scheduleEkadashiNotifications(
        ekadashiId: Int,
        ekadashiName: String,
        fastingStartTime: String,
        paranaStartTime: String,
        texts: Map<String, String>
    ): Int {
        var scheduledCount = 0

        try {
            val fastingStart = ZonedDateTime.parse(fastingStartTime)
            val paranaStart = ZonedDateTime.parse(paranaStartTime)

            // 48 hours before (2 days)
            if (prefs.getBoolean(KEY_REMIND_2_DAYS, true)) {
                val time2Days = fastingStart.minusHours(48)
                val title = texts["notif_2day_title"] ?: "Upcoming Ekadashi"
                val body = "$ekadashiName ${texts["notif_2day_body"] ?: "is in 2 days. Prepare for your fast."}"
                if (scheduleNotification(ekadashiId, time2Days, title, body, NotificationType.TWO_DAYS_BEFORE)) {
                    scheduledCount++
                }
            }

            // 24 hours before (1 day)
            if (prefs.getBoolean(KEY_REMIND_1_DAY, true)) {
                val time1Day = fastingStart.minusHours(24)
                val title = texts["notif_1day_title"] ?: "Ekadashi Tomorrow!"
                val fastTime = fastingStart.format(DateTimeFormatter.ofPattern("hh:mm a"))
                val body = "$ekadashiName ${texts["notif_1day_body"] ?: "is tomorrow. Fasting starts at"} $fastTime"
                if (scheduleNotification(ekadashiId, time1Day, title, body, NotificationType.ONE_DAY_BEFORE)) {
                    scheduledCount++
                }
            }

            // At fasting start time
            if (prefs.getBoolean(KEY_REMIND_ON_START, true)) {
                val title = texts["notif_start_title"] ?: "Ekadashi Starts Now"
                val bodyPrefix = texts["notif_start_body"] ?: "Today is"
                val bodySuffix = texts["notif_start_suffix"] ?: "Fasting begins now."
                val body = "$bodyPrefix $ekadashiName. $bodySuffix"
                if (scheduleNotification(ekadashiId, fastingStart, title, body, NotificationType.ON_FASTING_START)) {
                    scheduledCount++
                }
            }

            // At parana time
            if (prefs.getBoolean(KEY_REMIND_ON_PARANA, false)) {
                val title = texts["notif_parana_title"] ?: "Parana Time"
                val body = "$ekadashiName ${texts["notif_parana_body"] ?: "- You can break your fast now."}"
                if (scheduleNotification(ekadashiId, paranaStart, title, body, NotificationType.ON_PARANA)) {
                    scheduledCount++
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling notifications for Ekadashi $ekadashiId: ${e.message}")
        }

        return scheduledCount
    }

    /**
     * Cancel all scheduled notifications
     */
    fun cancelAllNotifications() {
        workManager.cancelAllWorkByTag(TAG_EKADASHI_NOTIFICATION)
        Log.d(TAG, "Cancelled all Ekadashi notifications")
    }

    /**
     * Cancel notifications for a specific Ekadashi
     */
    fun cancelEkadashiNotifications(ekadashiId: Int) {
        workManager.cancelAllWorkByTag("ekadashi_$ekadashiId")
        Log.d(TAG, "Cancelled notifications for Ekadashi $ekadashiId")
    }

    /**
     * Get count of pending notifications
     */
    suspend fun getPendingNotificationCount(): Int {
        return try {
            val workInfos = workManager.getWorkInfosByTag(TAG_EKADASHI_NOTIFICATION).get()
            workInfos.count { it.state == WorkInfo.State.ENQUEUED }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting pending count: ${e.message}")
            0
        }
    }

    /**
     * Show instant test notification
     */
    fun showTestNotification(title: String, body: String) {
        val inputData = Data.Builder()
            .putString(EkadashiNotificationWorker.KEY_TITLE, title)
            .putString(EkadashiNotificationWorker.KEY_BODY, body)
            .putInt(EkadashiNotificationWorker.KEY_NOTIFICATION_ID, 0)
            .build()

        val workRequest = OneTimeWorkRequestBuilder<EkadashiNotificationWorker>()
            .setInputData(inputData)
            .build()

        workManager.enqueue(workRequest)
        Log.d(TAG, "Test notification queued")
    }

    // Preference getters/setters

    fun isNotificationsEnabled(): Boolean = prefs.getBoolean(KEY_NOTIFICATIONS_ENABLED, true)

    fun setNotificationsEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_NOTIFICATIONS_ENABLED, enabled).apply()
        if (!enabled) {
            cancelAllNotifications()
        }
    }

    fun isRemind2DaysEnabled(): Boolean = prefs.getBoolean(KEY_REMIND_2_DAYS, true)

    fun setRemind2DaysEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_REMIND_2_DAYS, enabled).apply()
    }

    fun isRemind1DayEnabled(): Boolean = prefs.getBoolean(KEY_REMIND_1_DAY, true)

    fun setRemind1DayEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_REMIND_1_DAY, enabled).apply()
    }

    fun isRemindOnStartEnabled(): Boolean = prefs.getBoolean(KEY_REMIND_ON_START, true)

    fun setRemindOnStartEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_REMIND_ON_START, enabled).apply()
    }

    fun isRemindOnParanaEnabled(): Boolean = prefs.getBoolean(KEY_REMIND_ON_PARANA, false)

    fun setRemindOnParanaEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_REMIND_ON_PARANA, enabled).apply()
    }

    /**
     * Get all preference settings as map
     */
    fun getSettings(): Map<String, Boolean> = mapOf(
        "notifications_enabled" to isNotificationsEnabled(),
        "remind_2_days" to isRemind2DaysEnabled(),
        "remind_1_day" to isRemind1DayEnabled(),
        "remind_on_start" to isRemindOnStartEnabled(),
        "remind_on_parana" to isRemindOnParanaEnabled()
    )

    /**
     * Update settings from map
     */
    fun updateSettings(settings: Map<String, Boolean>) {
        settings["notifications_enabled"]?.let { setNotificationsEnabled(it) }
        settings["remind_2_days"]?.let { setRemind2DaysEnabled(it) }
        settings["remind_1_day"]?.let { setRemind1DayEnabled(it) }
        settings["remind_on_start"]?.let { setRemindOnStartEnabled(it) }
        settings["remind_on_parana"]?.let { setRemindOnParanaEnabled(it) }
    }
}