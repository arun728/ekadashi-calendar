package com.applausestudios.ekadashi_calendar

import android.app.Activity
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.plugin.common.MethodChannel

/** Lets Google Play own the confirmation, download and installation. */
internal class PlayUpdateBridge(
    private val activity: Activity,
    private val manager: AppUpdateManager,
    private val channel: MethodChannel
) {
    private val listener = InstallStateUpdatedListener { update ->
        val status = when (update.installStatus()) {
            InstallStatus.PENDING, InstallStatus.DOWNLOADING -> "downloading"
            InstallStatus.DOWNLOADED -> "downloaded"
            InstallStatus.FAILED -> "failed"
            else -> null
        }
        if (status != null) channel.invokeMethod("state", mapOf("state" to status))
    }

    init {
        manager.registerListener(listener)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "check" -> manager.appUpdateInfo
                    .addOnSuccessListener { result.success(state(it)) }
                    .addOnFailureListener { result.success(null) }
                "start" -> start(result)
                "complete" -> complete(result)
                else -> result.notImplemented()
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        manager.unregisterListener(listener)
    }

    private fun start(result: MethodChannel.Result) {
        manager.appUpdateInfo.addOnSuccessListener { info ->
            if (state(info)?.get("state") != "available") {
                result.success(false)
                return@addOnSuccessListener
            }
            manager.startUpdateFlow(info, activity, flexibleOptions)
                .addOnSuccessListener { code ->
                    when (code) {
                        Activity.RESULT_OK -> result.success(true)
                        Activity.RESULT_CANCELED -> result.success(false)
                        else -> result.error("PLAY_UPDATE_FAILED", null, null)
                    }
                }
                .addOnFailureListener { result.error("PLAY_UPDATE_FAILED", null, null) }
        }.addOnFailureListener { result.error("PLAY_UPDATE_FAILED", null, null) }
    }

    private fun complete(result: MethodChannel.Result) {
        manager.appUpdateInfo.addOnSuccessListener { info ->
            if (info.installStatus() != InstallStatus.DOWNLOADED) {
                result.success(false)
                return@addOnSuccessListener
            }
            manager.completeUpdate()
                .addOnSuccessListener { result.success(true) }
                .addOnFailureListener { result.error("PLAY_UPDATE_FAILED", null, null) }
        }.addOnFailureListener { result.error("PLAY_UPDATE_FAILED", null, null) }
    }

    companion object {
        private val flexibleOptions = AppUpdateOptions.defaultOptions(AppUpdateType.FLEXIBLE)

        internal fun state(info: AppUpdateInfo): Map<String, Any>? {
            val status = when (info.installStatus()) {
                InstallStatus.PENDING, InstallStatus.DOWNLOADING -> "downloading"
                InstallStatus.DOWNLOADED -> "downloaded"
                else -> if (
                    info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
                    info.isUpdateTypeAllowed(flexibleOptions)
                ) "available" else return null
            }
            return mapOf("state" to status, "versionCode" to info.availableVersionCode())
        }
    }
}
