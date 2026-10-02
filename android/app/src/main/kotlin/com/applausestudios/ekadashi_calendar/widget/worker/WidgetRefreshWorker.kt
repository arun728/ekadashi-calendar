package com.applausestudios.ekadashi_calendar.widget.worker

import android.content.Context
import android.util.Log
import androidx.work.*
import com.applausestudios.ekadashi_calendar.widget.refresh.WidgetRefreshManager
import com.applausestudios.ekadashi_calendar.widget.storage.WidgetStorage
import java.time.Duration
import java.time.Instant
import java.util.concurrent.TimeUnit

/**
 * WorkManager worker for battery-conscious background widget updates.
 *
 * Responsibilities:
 * 1. Reads cached shared data from WidgetStorage.
 * 2. Determines current state and updates widget UI.
 * 3. Enqueues the next one-shot execution at the exact upcoming state transition
 *    (e.g., fasting start, parana start, parana end) without polling.
 * 4. NEVER executes network operations.
 */
class WidgetRefreshWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    companion object {
        private const val TAG = "EKADASHI_WIDGET"
        private const val UNIQUE_WORK_NAME = "ekadashi_widget_transition_worker"

        /**
         * Enqueues or reschedules the worker at the next meaningful transition point.
         */
        fun scheduleNextTransition(context: Context) {
            val storage = WidgetStorage.getInstance(context)
            val result = storage.loadPayload()
            if (!result.status.canDisplay) {
                Log.w(TAG, "Cannot schedule transition worker: cache status is ${result.status}")
                return
            }

            val nextEkadashi = result.payload.nextEkadashi ?: return
            val upcoming = result.payload.upcomingEkadashis.firstOrNull()
            val now = Instant.now()

            // Find closest upcoming transition points across current and next upcoming Ekadashi
            val candidates = mutableListOf<Instant>()
            nextEkadashi.fastingStartInstant?.takeIf { it.isAfter(now) }?.let { candidates.add(it) }
            nextEkadashi.paranaStartInstant?.takeIf { it.isAfter(now) }?.let { candidates.add(it) }
            nextEkadashi.paranaEndInstant?.takeIf { it.isAfter(now) }?.let {
                candidates.add(it)
                // Transition to NEXT_EKADASHI 2 hours after Parana ends
                candidates.add(it.plusSeconds(7200))
            }

            // Include transitions for upcoming Ekadashi
            upcoming?.let { up ->
                up.fastingStartInstant?.takeIf { it.isAfter(now) }?.let { candidates.add(it) }
                up.paranaStartInstant?.takeIf { it.isAfter(now) }?.let { candidates.add(it) }
            }

            val nextTransition = candidates.filter { it.isAfter(now) }.minOrNull()
            if (nextTransition != null) {
                val delayMs = Duration.between(now, nextTransition).toMillis().coerceAtLeast(1000)
                Log.i(TAG, "Scheduling next widget transition in ${delayMs / 1000}s (at $nextTransition)")

                val request = OneTimeWorkRequestBuilder<WidgetRefreshWorker>()
                    .setInitialDelay(delayMs, TimeUnit.MILLISECONDS)
                    .setConstraints(
                        Constraints.Builder()
                            .setRequiresBatteryNotLow(false)
                            .build()
                    )
                    .build()

                WorkManager.getInstance(context).enqueueUniqueWork(
                    UNIQUE_WORK_NAME,
                    ExistingWorkPolicy.REPLACE,
                    request
                )
            } else {
                Log.d(TAG, "No immediate state transitions found for current Ekadashi.")
            }
        }
    }

    override suspend fun doWork(): Result {
        Log.d(TAG, "Executing scheduled widget refresh...")
        return try {
            // Trigger UI update
            WidgetRefreshManager.refreshAllWidgets(context)

            // Re-schedule for subsequent transition
            scheduleNextTransition(context)

            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Error executing widget refresh worker: ${e.message}", e)
            Result.retry()
        }
    }
}
