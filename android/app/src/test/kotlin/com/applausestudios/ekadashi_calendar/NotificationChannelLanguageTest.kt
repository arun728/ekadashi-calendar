package com.applausestudios.ekadashi_calendar

import android.app.Application
import android.app.NotificationManager
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.work.Configuration
import androidx.work.Data
import androidx.work.ListenableWorker
import androidx.work.testing.SynchronousExecutor
import androidx.work.testing.TestListenableWorkerBuilder
import androidx.work.testing.WorkManagerTestInitHelper
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** The notification channel is named in the app language (system Settings). */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [28, 35])
class NotificationChannelLanguageTest {
    private lateinit var context: Context
    private lateinit var scheduler: NotificationScheduler
    private lateinit var manager: NotificationManager

    @Before fun setup() {
        context = ApplicationProvider.getApplicationContext()
        WorkManagerTestInitHelper.initializeTestWorkManager(context,
            Configuration.Builder().setExecutor(SynchronousExecutor()).build())
        scheduler = NotificationScheduler(context)
        manager = context.getSystemService(NotificationManager::class.java)
    }

    private fun channel() = manager.getNotificationChannel(EkadashiNotificationWorker.CHANNEL_ID)

    @Test fun localizeChannelRenamesTheSameChannel() {
        scheduler.localizeChannel("सूचनाएँ", "एकादशी, त्योहार और कार्यक्रम")
        assertEquals("सूचनाएँ", channel().name.toString())
        assertEquals("एकादशी, त्योहार और कार्यक्रम", channel().description)
        assertEquals(NotificationManager.IMPORTANCE_HIGH, channel().importance)
        // A new language renames it; the id stays.
        scheduler.localizeChannel("அறிவிப்புகள்", "ஏகாதசி")
        assertEquals("அறிவிப்புகள்", channel().name.toString())
        assertEquals(1, manager.notificationChannels.count { it.id == EkadashiNotificationWorker.CHANNEL_ID })
    }

    @Test fun aNotificationKeepsTheLocalizedName() = runBlocking {
        scheduler.localizeChannel("সূচনা", "একাদশী")
        val worker = TestListenableWorkerBuilder<EkadashiNotificationWorker>(context)
            .setInputData(Data.Builder()
                .putString(EkadashiNotificationWorker.KEY_TITLE, "একাদশী")
                .putString(EkadashiNotificationWorker.KEY_BODY, "আগামীকাল")
                .putInt(EkadashiNotificationWorker.KEY_NOTIFICATION_ID, 7)
                .build())
            .build()
        assertEquals(ListenableWorker.Result.success(), worker.doWork())
        assertEquals("সূচনা", channel().name.toString())
        assertEquals("একাদশী", channel().description)
    }

    @Test fun beforeAnyLanguageTheEnglishNameIsUsed() {
        EkadashiNotificationWorker.ensureChannel(context)
        assertEquals(EkadashiNotificationWorker.CHANNEL_NAME, channel().name.toString())
    }
}
