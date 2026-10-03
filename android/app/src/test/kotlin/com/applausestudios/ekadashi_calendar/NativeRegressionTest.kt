package com.applausestudios.ekadashi_calendar

import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.work.Configuration
import androidx.work.WorkManager
import androidx.work.WorkInfo
import androidx.work.Data
import androidx.work.ListenableWorker
import androidx.work.testing.TestListenableWorkerBuilder
import androidx.work.testing.SynchronousExecutor
import androidx.work.testing.WorkManagerTestInitHelper
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.Shadows
import kotlinx.coroutines.runBlocking
import java.time.ZonedDateTime
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [28])
class NativeRegressionTest {
    private lateinit var context: Context
    private lateinit var scheduler: NotificationScheduler
    private lateinit var work: WorkManager

    @Before fun setup() {
        context = ApplicationProvider.getApplicationContext()
        context.getSharedPreferences("ekadashi_settings", Context.MODE_PRIVATE).edit().clear().commit()
        context.getSharedPreferences("notification_prefs", Context.MODE_PRIVATE).edit().clear().commit()
        WorkManagerTestInitHelper.initializeTestWorkManager(context,
            Configuration.Builder().setExecutor(SynchronousExecutor()).build())
        work = WorkManager.getInstance(context)
        scheduler = NotificationScheduler(context)
    }
    private fun active() = work.getWorkInfosByTag("ekadashi_notification")
        .get(10, TimeUnit.SECONDS).filter { !it.state.isFinished }

    @Test fun partialSettingsUpdatePreservesOtherReminders() {
        val settings = SettingsService(context)
        assertTrue(settings.updateNotificationSettings(mapOf("remindOnParana" to false)))
        assertEquals(false, settings.getNotificationSettings()["remindOnParana"])
        assertEquals(true, SettingsService(context).getNotificationSettings()["remind1Day"])
    }
    @Test fun selectedLocationCanReturnToAutomaticWithoutStaleCity() {
        val settings = SettingsService(context)
        settings.updateLocationSettings(false, "new_york", "EST")
        assertEquals("EST", SettingsService(context).getLocationSettings()["timezone"])
        settings.updateLocationSettings(true, null, "IST")
        assertNull(settings.getLocationSettings()["cityId"])
        assertEquals(true, settings.getLocationSettings()["autoDetect"])
    }
    @Test fun languageThemeAndResetPersistAcrossServiceInstances() {
        val settings = SettingsService(context)
        settings.setLanguageCode("ta")
        settings.setDarkMode(true)
        assertEquals("ta", SettingsService(context).getLanguageCode())
        assertTrue(SettingsService(context).isDarkMode())
        assertTrue(settings.resetToDefaults())
        assertEquals("en", settings.getLanguageCode())
        assertFalse(settings.isDarkMode())
    }
    @Test fun pastNotificationIsNotQueued() {
        assertFalse(scheduler.scheduleNotification(1, ZonedDateTime.now().minusMinutes(1),
            "Past", "Body", NotificationType.ON_FASTING_START))
        assertTrue(active().isEmpty())
    }
    @Test fun futureOccurrenceQueuesFourDistinctReminders() {
        val start = ZonedDateTime.now().plusDays(10)
        assertEquals(4, scheduler.scheduleEkadashiNotifications(7, "Test", start.toString(),
            start.plusDays(1).toString(), emptyMap()))
        assertEquals(4, active().size)
        assertTrue(active().all { "ekadashi_7" in it.tags && it.state == WorkInfo.State.ENQUEUED })
    }
    @Test fun rescheduleReplacesRatherThanDuplicatesOccurrence() {
        val start = ZonedDateTime.now().plusDays(10)
        repeat(2) { scheduler.scheduleEkadashiNotifications(7, "Test", start.toString(),
            start.plusDays(1).toString(), emptyMap()) }
        assertEquals(4, active().size)
    }
    @Test fun adjacentYearsDoNotReplaceOrCancelEachOthersReminders() {
        val start = ZonedDateTime.now().plusDays(10)
        for (id in listOf(1, 2027001)) scheduler.scheduleEkadashiNotifications(id, "Test",
            start.toString(), start.plusDays(1).toString(), emptyMap())
        assertEquals(8, active().size)
        scheduler.cancelEkadashiNotifications(2027001)
        assertEquals(4, active().size)
        assertTrue(active().all { "ekadashi_1" in it.tags })
    }

    @Test fun cancelOneOccurrencePreservesAnother() {
        val start = ZonedDateTime.now().plusDays(10)
        for (id in listOf(7, 8)) scheduler.scheduleEkadashiNotifications(id, "Test",
            start.toString(), start.plusDays(1).toString(), emptyMap())
        scheduler.cancelEkadashiNotifications(7)
        assertEquals(4, active().size)
        assertTrue(active().all { "ekadashi_8" in it.tags })
    }
    @Test fun masterDisableCancelsQueuedWork() {
        val start = ZonedDateTime.now().plusDays(10)
        scheduler.scheduleEkadashiNotifications(7, "Test", start.toString(),
            start.plusDays(1).toString(), emptyMap())
        scheduler.setNotificationsEnabled(false)
        assertTrue(active().isEmpty())
    }

    // Required behavior, currently fails on main: master opt-out must prevent
    // subsequent callers from creating new work, not only cancel old jobs.
    @Test fun masterDisablePreventsNewReminders() {
        scheduler.setNotificationsEnabled(false)
        val start = ZonedDateTime.now().plusDays(10)
        assertEquals(0, scheduler.scheduleEkadashiNotifications(7, "Test", start.toString(),
            start.plusDays(1).toString(), emptyMap()))
        assertTrue(active().isEmpty())
    }

    @Test fun settingsChannelOptOutIsHonoredByNotificationChannel() {
        SettingsService(context).updateNotificationSettings(mapOf("enabled" to false))
        assertFalse(scheduler.isNotificationsEnabled())
        val start = ZonedDateTime.now().plusDays(10)
        assertEquals(0, scheduler.scheduleEkadashiNotifications(7, "Test", start.toString(),
            start.plusDays(1).toString(), emptyMap()))
        assertTrue(active().isEmpty())
    }

    @Test fun reminderChoicesAreSharedAcrossNativeChannels() {
        SettingsService(context).updateNotificationSettings(mapOf("remind1Day" to false))
        val start = ZonedDateTime.now().plusDays(10)
        assertEquals(3, scheduler.scheduleEkadashiNotifications(7, "Test", start.toString(),
            start.plusDays(1).toString(), emptyMap()))
        assertEquals(false, scheduler.getSettings()["remind_1_day"])
    }

    @Test fun workerRejectsMissingBodyWithoutPosting() = runBlocking {
        val worker = TestListenableWorkerBuilder<EkadashiNotificationWorker>(context)
            .setInputData(Data.Builder().putString(EkadashiNotificationWorker.KEY_TITLE, "Test").build())
            .build()
        assertEquals(ListenableWorker.Result.failure(), worker.doWork())
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        assertTrue(Shadows.shadowOf(manager).allNotifications.isEmpty())
    }

    @Test fun workerPostsLocalizedTextAndCreatesReminderChannel() = runBlocking {
        val worker = TestListenableWorkerBuilder<EkadashiNotificationWorker>(context)
            .setInputData(Data.Builder()
                .putString(EkadashiNotificationWorker.KEY_TITLE, "ஏகாதசி")
                .putString(EkadashiNotificationWorker.KEY_BODY, "व्रत प्रारंभ")
                .putInt(EkadashiNotificationWorker.KEY_NOTIFICATION_ID, 77).build())
            .build()
        assertEquals(ListenableWorker.Result.success(), worker.doWork())
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notification = Shadows.shadowOf(manager).getNotification(77)
        assertNotNull(notification)
        assertEquals("ஏகாதசி", notification.extras.getString(Notification.EXTRA_TITLE))
        assertEquals("व्रत प्रारंभ", notification.extras.getString(Notification.EXTRA_TEXT))
        assertNotNull(notification.contentIntent)
        assertEquals(NotificationManager.IMPORTANCE_HIGH,
            manager.getNotificationChannel(EkadashiNotificationWorker.CHANNEL_ID).importance)
    }
}
