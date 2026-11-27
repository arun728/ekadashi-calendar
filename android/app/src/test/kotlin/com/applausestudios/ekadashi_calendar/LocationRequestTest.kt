package com.applausestudios.ekadashi_calendar

import android.app.Application
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.google.android.gms.location.Priority
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * M52 launch timing (27 November 2026): every launch waited about 2.1 s for
 * a fresh GPS fix and 0.2 s for the city name, while iOS answers at once
 * with a reduced-accuracy (city-level) fix.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [28])
class LocationRequestTest {

    @Test
    fun asksForACityLevelFixAndAcceptsARecentOne() {
        val request = LocationService.currentLocationRequest()
        assertEquals(Priority.PRIORITY_BALANCED_POWER_ACCURACY, request.priority)
        assertTrue(request.maxUpdateAgeMillis >= 5 * 60 * 1000L)
        assertTrue(request.durationMillis <= 15_000L)
    }

    @Test
    fun reusesTheSavedNameNearTheLastFixInsteadOfGeocodingAgain() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        context.getSharedPreferences("location_cache", Context.MODE_PRIVATE)
            .edit().clear().commit()
        val service = LocationService(context)
        var lookups = 0
        val geocode = { _: Double, _: Double -> lookups++; "Chennai" }

        // Nothing saved yet: the name is looked up.
        assertEquals("Chennai", service.cityName(13.0129, 80.1615, geocode))
        assertEquals(1, lookups)
        service.remember(13.0129, 80.1615, "Chennai", "IST")

        // About 2.8 km away: the saved name, no lookup.
        assertEquals("Chennai", service.cityName(13.0300, 80.1800, geocode))
        assertEquals(1, lookups)

        // 13 km away: looked up again.
        assertEquals("Chennai", service.cityName(13.0827, 80.2707, geocode))
        assertEquals(2, lookups)
    }
}
