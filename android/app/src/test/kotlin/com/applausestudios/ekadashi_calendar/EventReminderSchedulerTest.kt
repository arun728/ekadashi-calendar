package com.applausestudios.ekadashi_calendar

import android.app.Application
import android.app.NotificationManager
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.work.Configuration
import androidx.work.Data
import androidx.work.ListenableWorker
import androidx.work.WorkManager
import androidx.work.testing.SynchronousExecutor
import androidx.work.testing.TestListenableWorkerBuilder
import androidx.work.testing.WorkManagerTestInitHelper
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import java.util.concurrent.TimeUnit

/** Phase 7 (docs/ROADMAP.md): festival and calendar reminders the app plans. */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [28, 35])
class EventReminderSchedulerTest {
    private lateinit var context: Context
    private lateinit var scheduler: NotificationScheduler
    private lateinit var work: WorkManager

    @Before fun setup() {
        context = ApplicationProvider.getApplicationContext()
        WorkManagerTestInitHelper.initializeTestWorkManager(context,
            Configuration.Builder().setExecutor(SynchronousExecutor()).build())
        work = WorkManager.getInstance(context)
        scheduler = NotificationScheduler(context)
    }

    private fun active(tag: String) = work.getWorkInfosByTag(tag)
        .get(10, TimeUnit.SECONDS).filter { !it.state.isFinished }

    private fun reminder(id: String, inMillis: Long, now: Long) = mapOf<String, Any?>(
        "id" to id, "fireAt" to now + inMillis, "title" to "Amavasya",
        "body" to "Amavasya is tomorrow (Sat, 10 Oct 2026)", "url" to "ekadashi://panchang?date=2026-10-10")

    @Test fun replacesEveryEventReminderAndSkipsPastOnes() {
        val now = System.currentTimeMillis()
        assertEquals(2, scheduler.scheduleEventReminders(listOf(
            reminder("event.a", 3_600_000, now), reminder("event.b", 7_200_000, now),
            reminder("event.past", -1_000, now)), now))
        assertEquals(2, active(NotificationScheduler.TAG_EVENT_REMINDER).size)
        assertEquals(1, scheduler.scheduleEventReminders(listOf(reminder("event.c", 3_600_000, now)), now))
        assertEquals(1, active(NotificationScheduler.TAG_EVENT_REMINDER).size)
        assertEquals(0, scheduler.scheduleEventReminders(emptyList(), now))
        assertTrue(active(NotificationScheduler.TAG_EVENT_REMINDER).isEmpty())
    }

    @Test fun eventRemindersLeaveEkadashiRemindersAlone() {
        val now = System.currentTimeMillis()
        val start = java.time.ZonedDateTime.now().plusDays(5)
        scheduler.scheduleEkadashiNotifications(7, "Rama Ekadashi", start.toOffsetDateTime().toString(),
            start.plusDays(1).toOffsetDateTime().toString(), emptyMap())
        val ekadashi = active("ekadashi_notification").size
        assertTrue(ekadashi > 0)
        scheduler.scheduleEventReminders(listOf(reminder("event.a", 3_600_000, now)), now)
        scheduler.scheduleEventReminders(emptyList(), now)
        assertEquals(ekadashi, active("ekadashi_notification").size)
    }

    @Test fun tappingAnEventReminderOpensItsDay() = runBlocking {
        val worker = TestListenableWorkerBuilder<EkadashiNotificationWorker>(context)
            .setInputData(Data.Builder()
                .putString(EkadashiNotificationWorker.KEY_TITLE, "Amavasya")
                .putString(EkadashiNotificationWorker.KEY_BODY, "Amavasya is tomorrow")
                .putInt(EkadashiNotificationWorker.KEY_NOTIFICATION_ID, 0x40000001)
                .putString(EkadashiNotificationWorker.KEY_URL, "ekadashi://panchang?date=2026-10-10")
                .build())
            .build()
        assertEquals(ListenableWorker.Result.success(), worker.doWork())
        val manager = context.getSystemService(NotificationManager::class.java)
        val posted = Shadows.shadowOf(manager).allNotifications.single()
        val intent = Shadows.shadowOf(posted.contentIntent).savedIntent
        assertEquals("ekadashi://panchang?date=2026-10-10", intent.dataString)
    }
}
