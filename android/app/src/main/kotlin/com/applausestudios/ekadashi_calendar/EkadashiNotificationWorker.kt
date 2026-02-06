package com.applausestudios.ekadashi_calendar

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.*
import java.util.concurrent.TimeUnit

/**
 * WorkManager Worker for Ekadashi notifications
 *
 * WorkManager advantages over AlarmManager:
 * 1. Guaranteed execution (retries on failure)
 * 2. Survives device reboot
 * 3. Battery-friendly scheduling
 * 4. Works even when app is killed
 * 5. Respects Doze mode properly
 */
class EkadashiNotificationWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "EkadashiNotifWorker"
        const val CHANNEL_ID = "ekadashi_reminders"
        const val CHANNEL_NAME = "Ekadashi Reminders"

        // Input data keys
        const val KEY_TITLE = "title"
        const val KEY_BODY = "body"
        const val KEY_EKADASHI_ID = "ekadashi_id"
        const val KEY_NOTIFICATION_TYPE = "notification_type"
        const val KEY_NOTIFICATION_ID = "notification_id"
    }

    override suspend fun doWork(): Result {
        val title = inputData.getString(KEY_TITLE) ?: return Result.failure()
        val body = inputData.getString(KEY_BODY) ?: return Result.failure()
        val notificationId = inputData.getInt(KEY_NOTIFICATION_ID, System.currentTimeMillis().toInt())

        Log.d(TAG, "Showing notification: $title")

        return try {
            showNotification(title, body, notificationId)
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Error showing notification: ${e.message}")
            // Retry up to 3 times
            if (runAttemptCount < 3) {
                Result.retry()
            } else {
                Result.failure()
            }
        }
    }

    private fun showNotification(title: String, body: String, notificationId: Int) {
        val notificationManager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create notification channel for Android O+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Reminders for Ekadashi fasting days"
                enableVibration(true)
                enableLights(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Create intent to open app when notification is tapped
        val intent = Intent(applicationContext, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            applicationContext,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Build notification
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(R.drawable.notification_icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setColor(0xFF00A19B.toInt()) // Teal color
            .apply {
                // Add large icon if available
                try {
                    val largeIcon = BitmapFactory.decodeResource(
                        applicationContext.resources,
                        R.drawable.app_icon
                    )
                    setLargeIcon(largeIcon)
                } catch (e: Exception) {
                    Log.w(TAG, "Could not load large icon: ${e.message}")
                }
            }
            .build()

        notificationManager.notify(notificationId, notification)
        Log.d(TAG, "Notification shown with ID: $notificationId")
    }
}

/**
 * Notification types for different reminder timings
 */
enum class NotificationType(val value: String) {
    TWO_DAYS_BEFORE("2day"),
    ONE_DAY_BEFORE("1day"),
    ON_FASTING_START("start"),
    ON_PARANA("parana")
}