package com.example.ekadashi_calendar

import android.app.AlarmManager
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.ekadashi.permissions"
    private val TAG = "EkadashiPermission"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canScheduleExactAlarms" -> {
                    val canSchedule = canScheduleExactAlarms()
                    Log.d(TAG, "canScheduleExactAlarms returning: $canSchedule")
                    result.success(canSchedule)
                }
                "openAlarmSettings" -> {
                    val opened = openAlarmSettings()
                    Log.d(TAG, "openAlarmSettings returning: $opened")
                    result.success(opened)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Open the system's Alarms & Reminders settings page.
     * Uses multiple fallback strategies to ensure compatibility across all Android devices.
     */
    private fun openAlarmSettings(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                // Primary: Direct intent to exact alarm settings (Android 12+)
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                Log.d(TAG, "Opened alarm settings via ACTION_REQUEST_SCHEDULE_EXACT_ALARM")
                return true
            } catch (e: Exception) {
                Log.w(TAG, "ACTION_REQUEST_SCHEDULE_EXACT_ALARM failed: ${e.message}")

                // Fallback 1: Try generic app notification settings
                try {
                    val fallbackIntent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                        putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(fallbackIntent)
                    Log.d(TAG, "Opened alarm settings via ACTION_APP_NOTIFICATION_SETTINGS")
                    return true
                } catch (e2: Exception) {
                    Log.w(TAG, "ACTION_APP_NOTIFICATION_SETTINGS failed: ${e2.message}")

                    // Fallback 2: Open app details settings
                    try {
                        val detailsIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(detailsIntent)
                        Log.d(TAG, "Opened alarm settings via ACTION_APPLICATION_DETAILS_SETTINGS")
                        return true
                    } catch (e3: Exception) {
                        Log.e(TAG, "All alarm settings intents failed", e3)
                        return false
                    }
                }
            }
        } else {
            // Pre-Android 12: Open app details settings
            try {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to open app settings", e)
                return false
            }
        }
    }

    /**
     * Check if the app can schedule exact alarms using multiple methods.
     * Samsung One UI has a known bug where AlarmManager.canScheduleExactAlarms()
     * returns cached/stale values. We use AppOpsManager as a more reliable check.
     */
    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Method 1: Use AppOpsManager (more reliable on Samsung)
            val appOpsResult = checkViaAppOps()
            Log.d(TAG, "AppOpsManager check: $appOpsResult")

            // Method 2: Use AlarmManager (standard API)
            val alarmManagerResult = checkViaAlarmManager()
            Log.d(TAG, "AlarmManager check: $alarmManagerResult")

            // On Samsung devices, AppOpsManager is more reliable
            // If they disagree, trust AppOpsManager
            if (appOpsResult != null) {
                return appOpsResult
            }

            // Fallback to AlarmManager if AppOpsManager fails
            return alarmManagerResult
        }
        // Pre-Android 12 doesn't need this permission
        return true
    }

    /**
     * Check permission via AppOpsManager - more reliable on Samsung devices
     */
    private fun checkViaAppOps(): Boolean? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager

                // OPSTR_SCHEDULE_EXACT_ALARM = "android:schedule_exact_alarm"
                val opStr = "android:schedule_exact_alarm"

                val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    appOpsManager.unsafeCheckOpNoThrow(opStr, Process.myUid(), packageName)
                } else {
                    @Suppress("DEPRECATION")
                    appOpsManager.checkOpNoThrow(opStr, Process.myUid(), packageName)
                }

                Log.d(TAG, "AppOps mode for schedule_exact_alarm: $mode")

                return when (mode) {
                    AppOpsManager.MODE_ALLOWED -> true
                    AppOpsManager.MODE_IGNORED, AppOpsManager.MODE_ERRORED -> false
                    AppOpsManager.MODE_DEFAULT -> {
                        // MODE_DEFAULT means check the underlying permission
                        // Fall through to AlarmManager check
                        null
                    }
                    else -> null
                }
            } catch (e: Exception) {
                Log.e(TAG, "AppOpsManager check failed", e)
                return null
            }
        }
        return null
    }

    /**
     * Check permission via AlarmManager - standard API
     */
    private fun checkViaAlarmManager(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                // Use applicationContext to avoid any activity-level caching
                val alarmManager = applicationContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                return alarmManager.canScheduleExactAlarms()
            } catch (e: Exception) {
                Log.e(TAG, "AlarmManager check failed", e)
                return false
            }
        }
        return true
    }
}