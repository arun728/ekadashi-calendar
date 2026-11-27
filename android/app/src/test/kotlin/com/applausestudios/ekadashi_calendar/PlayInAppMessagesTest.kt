package com.applausestudios.ekadashi_calendar

import com.android.billingclient.api.InAppMessageResult
import org.junit.Assert.assertEquals
import org.junit.Test

/// Report issue 5 (25 Nov 2026): Android shows Google Play's own "fix your
/// payment" message after a declined renewal, as iOS shows its billing card.
class PlayInAppMessagesTest {
    @Test
    fun playResultsMapToWhatTheAppDoesNext() {
        assertEquals(
            "updated",
            PlayInAppMessages.outcome(InAppMessageResult.InAppMessageResponseCode.SUBSCRIPTION_STATUS_UPDATED),
        )
        assertEquals("none", PlayInAppMessages.outcome(InAppMessageResult.InAppMessageResponseCode.NO_ACTION_NEEDED))
        assertEquals("error", PlayInAppMessages.outcome(null))
        assertEquals("error", PlayInAppMessages.outcome(-99))
        assertEquals("com.ekadashi.play_messages", PlayInAppMessages.CHANNEL)
    }
}
