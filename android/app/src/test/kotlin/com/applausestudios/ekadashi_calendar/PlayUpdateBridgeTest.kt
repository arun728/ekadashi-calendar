package com.applausestudios.ekadashi_calendar

import android.app.Activity
import androidx.test.core.app.ApplicationProvider
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.appupdate.testing.FakeAppUpdateManager
import com.google.android.play.core.install.model.AppUpdateType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35])
class PlayUpdateBridgeTest {
    @Test
    fun flexibleOfferAndDownloadedUpdateAreReported() {
        val fake = FakeAppUpdateManager(ApplicationProvider.getApplicationContext())
        fun state() = PlayUpdateBridge.state(fake.appUpdateInfo.result)
        assertNull(state())
        fake.setUpdateAvailable(7, AppUpdateType.IMMEDIATE)
        assertNull(state())
        fake.setUpdateAvailable(7, AppUpdateType.FLEXIBLE)
        assertEquals(mapOf("state" to "available", "versionCode" to 7), state())

        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        fake.startUpdateFlow(fake.appUpdateInfo.result, activity, AppUpdateOptions.defaultOptions(AppUpdateType.FLEXIBLE))
        fake.userAcceptsUpdate()
        fake.downloadStarts()
        assertEquals("downloading", state()?.get("state"))
        fake.downloadCompletes()
        assertEquals("downloaded", state()?.get("state"))
    }
}
