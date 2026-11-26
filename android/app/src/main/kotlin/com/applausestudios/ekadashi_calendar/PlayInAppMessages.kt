package com.applausestudios.ekadashi_calendar

import android.app.Activity
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.InAppMessageParams
import com.android.billingclient.api.InAppMessageResult
import com.android.billingclient.api.PendingPurchasesParams
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/// Google Play's own "fix your payment" message (Play in-app messaging,
/// transactional category): after a declined renewal Play shows it over the
/// app and lets the user update the payment method, as iOS shows its
/// billing-retry card (report issue 5, 25 Nov 2026). Play decides when there
/// is something to show; otherwise nothing appears.
object PlayInAppMessages {
    const val CHANNEL = "com.ekadashi.play_messages"

    fun outcome(responseCode: Int?): String = when (responseCode) {
        InAppMessageResult.InAppMessageResponseCode.SUBSCRIPTION_STATUS_UPDATED -> "updated"
        InAppMessageResult.InAppMessageResponseCode.NO_ACTION_NEEDED -> "none"
        else -> "error"
    }

    fun attach(activity: Activity, channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "showSubscriptionMessages") return@setMethodCallHandler result.notImplemented()
            show(activity) { outcome -> activity.runOnUiThread { result.success(outcome) } }
        }
    }

    private fun show(activity: Activity, done: (String) -> Unit) {
        val finished = AtomicBoolean(false)
        fun finish(outcome: String) { if (finished.compareAndSet(false, true)) done(outcome) }
        val client = BillingClient.newBuilder(activity)
            .setListener { _, _ -> }
            .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
            .build()
        client.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                    client.endConnection(); finish("error"); return
                }
                val params = InAppMessageParams.newBuilder()
                    .addInAppMessageCategoryToShow(InAppMessageParams.InAppMessageCategoryId.TRANSACTIONAL)
                    .build()
                activity.runOnUiThread {
                    client.showInAppMessages(activity, params) { message ->
                        client.endConnection(); finish(outcome(message.responseCode))
                    }
                }
            }

            override fun onBillingServiceDisconnected() = finish("error")
        })
    }
}
