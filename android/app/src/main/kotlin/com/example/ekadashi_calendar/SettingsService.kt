package com.example.ekadashi_calendar

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Native Settings Service - handles all permissions and settings natively
 * to avoid Flutter plugin freezes and permission handling issues.
 *
 * Benefits over Flutter plugins:
 * - Runs on native threads (no main thread blocking)
 * - Faster permission checks
 * - Smoother lifecycle handling when returning from system settings
 * - No black screen or delay issues
 */
class SettingsService(private val context: Context) {

    companion object {
        private const val PREFS_NAME = "ekadashi_settings"

        // Notification settings keys
        const val KEY_NOTIFICATIONS_ENABLED = "notifications_enabled"
        const val KEY_REMIND_2_DAYS = "remind_two_days_before"
        const val KEY_REMIND_1_DAY = "remind_one_day_before"
        const val KEY_REMIND_ON_START = "remind_on_day"
        const val KEY_REMIND_ON_PARANA = "remind_on_parana"

        // Location settings keys
        const val KEY_AUTO_DETECT_LOCATION = "auto_detect_location"
        const val KEY_SELECTED_CITY_ID = "selected_city_id"
        const val KEY_CURRENT_TIMEZONE = "current_timezone"

        // Theme settings keys
        const val KEY_DARK_MODE = "dark_mode"

        // Language settings keys
        const val KEY_LANGUAGE_CODE = "language_code"
    }

    private val prefs: SharedPreferences by lazy {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    // ============================================================
    // PERMISSION CHECKS - All run on IO thread for performance
    // ============================================================

    /**
     * Check if notification permission is granted.
     * For Android 13+ (API 33+), checks POST_NOTIFICATIONS permission.
     * For older versions, checks if notifications are enabled.
     */
    suspend fun hasNotificationPermission(): Boolean = withContext(Dispatchers.IO) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // Android 13+ requires POST_NOTIFICATIONS permission
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS
                ) == PackageManager.PERMISSION_GRANTED
            } else {
                // For older versions, check if notifications are enabled
                NotificationManagerCompat.from(context).areNotificationsEnabled()
            }
        } catch (e: Exception) {
            android.util.Log.e("SettingsService", "Error checking notification permission: $e")
            false
        }
    }

    /**
     * Check if exact alarm permission is granted.
     * Required for Android 12+ (API 31+) to schedule exact alarms.
     */
    suspend fun hasExactAlarmPermission(): Boolean = withContext(Dispatchers.IO) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                alarmManager?.canScheduleExactAlarms() ?: false
            } else {
                // Not required for older versions
                true
            }
        } catch (e: Exception) {
            android.util.Log.e("SettingsService", "Error checking exact alarm permission: $e")
            false
        }
    }

    /**
     * Check if location permission is granted.
     */
    suspend fun hasLocationPermission(): Boolean = withContext(Dispatchers.IO) {
        try {
            val fineLocation = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED

            val coarseLocation = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED

            fineLocation || coarseLocation
        } catch (e: Exception) {
            android.util.Log.e("SettingsService", "Error checking location permission: $e")
            false
        }
    }

    /**
     * Check if battery optimization is disabled (app can run in background).
     */
    suspend fun isBatteryOptimizationDisabled(): Boolean = withContext(Dispatchers.IO) {
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            powerManager?.isIgnoringBatteryOptimizations(context.packageName) ?: false
        } catch (e: Exception) {
            android.util.Log.e("SettingsService", "Error checking battery optimization: $e")
            false
        }
    }

    /**
     * Check all permissions at once - more efficient than multiple calls.
     * Returns a map with all permission states.
     * Catches all exceptions (including DeadObjectException) to prevent crashes
     * when returning from system settings.
     */
    suspend fun checkAllPermissions(): Map<String, Any> = withContext(Dispatchers.IO) {
        val result = mutableMapOf<String, Any>()

        try {
            // Wrap each check individually to get partial results if some fail
            result["hasNotificationPermission"] = try { hasNotificationPermission() } catch (e: Exception) { false }
            result["hasExactAlarmPermission"] = try { hasExactAlarmPermission() } catch (e: Exception) { true }
            result["hasLocationPermission"] = try { hasLocationPermission() } catch (e: Exception) { false }
            result["isBatteryOptimizationDisabled"] = try { isBatteryOptimizationDisabled() } catch (e: Exception) { false }
            result["androidVersion"] = Build.VERSION.SDK_INT
            result["requiresExactAlarmPermission"] = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
            result["requiresNotificationPermission"] = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
        } catch (e: Exception) {
            // Catch-all for any unexpected exceptions (including DeadObjectException)
            android.util.Log.e("SettingsService", "Error checking all permissions: $e")
            // Return safe defaults
            result["hasNotificationPermission"] = false
            result["hasExactAlarmPermission"] = true
            result["hasLocationPermission"] = false
            result["isBatteryOptimizationDisabled"] = false
            result["androidVersion"] = Build.VERSION.SDK_INT
            result["requiresExactAlarmPermission"] = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
            result["requiresNotificationPermission"] = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
        }

        result
    }

    // ============================================================
    // OPEN SETTINGS INTENTS - Native intents are more reliable
    // ============================================================

    /**
     * Open app notification settings.
     */
    fun openNotificationSettings(): Boolean {
        return try {
            val intent = Intent().apply {
                when {
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> {
                        action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                        putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    }
                    else -> {
                        action = "android.settings.APP_NOTIFICATION_SETTINGS"
                        putExtra("app_package", context.packageName)
                        putExtra("app_uid", context.applicationInfo.uid)
                    }
                }
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            android.util.Log.e("SettingsService", "Error opening notification settings: $e")
            false
        }
    }

    /**
     * Open exact alarm settings (Android 12+).
     */
    fun openExactAlarmSettings(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                true
            } else {
                // Not needed for older versions
                false
            }
        } catch (e: Exception) {
            android.util.Log.e("SettingsService", "Error opening exact alarm settings: $e")
            false
        }
    }

    /**
     * Open battery optimization settings.
     */
    fun openBatteryOptimizationSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            android.util.Log.e("SettingsService", "Error opening battery optimization settings: $e")
            // Fallback to general battery settings
            try {
                val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(fallbackIntent)
                true
            } catch (e2: Exception) {
                false
            }
        }
    }

    /**
     * Open app settings page.
     */
    fun openAppSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            android.util.Log.e("SettingsService", "Error opening app settings: $e")
            false
        }
    }

    /**
     * Open location settings.
     */
    fun openLocationSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            android.util.Log.e("SettingsService", "Error opening location settings: $e")
            false
        }
    }

    // ============================================================
    // NOTIFICATION SETTINGS - Stored locally
    // ============================================================

    /**
     * Get all notification settings at once.
     */
    fun getNotificationSettings(): Map<String, Any> {
        return mapOf(
            "enabled" to prefs.getBoolean(KEY_NOTIFICATIONS_ENABLED, true),
            "remind2Days" to prefs.getBoolean(KEY_REMIND_2_DAYS, true),
            "remind1Day" to prefs.getBoolean(KEY_REMIND_1_DAY, true),
            "remindOnStart" to prefs.getBoolean(KEY_REMIND_ON_START, true),
            "remindOnParana" to prefs.getBoolean(KEY_REMIND_ON_PARANA, true)  // Default true in v2.0
        )
    }

    /**
     * Update notification settings.
     */
    fun updateNotificationSettings(settings: Map<String, Boolean>): Boolean {
        return try {
            prefs.edit().apply {
                settings["enabled"]?.let { putBoolean(KEY_NOTIFICATIONS_ENABLED, it) }
                settings["remind2Days"]?.let { putBoolean(KEY_REMIND_2_DAYS, it) }
                settings["remind1Day"]?.let { putBoolean(KEY_REMIND_1_DAY, it) }
                settings["remindOnStart"]?.let { putBoolean(KEY_REMIND_ON_START, it) }
                settings["remindOnParana"]?.let { putBoolean(KEY_REMIND_ON_PARANA, it) }
                apply()
            }
            true
        } catch (e: Exception) {
            android.util.Log.e("SettingsService", "Error updating notification settings: $e")
            false
        }
    }

    /**
     * Set individual notification setting.
     */
    fun setNotificationSetting(key: String, value: Boolean): Boolean {
        return try {
            prefs.edit().putBoolean(key, value).apply()
            true
        } catch (e: Exception) {
            android.util.Log.e("SettingsService", "Error setting $key: $e")
            false
        }
    }

    // ============================================================
    // LOCATION SETTINGS
    // ============================================================

    /**
     * Get location settings.
     */
    fun getLocationSettings(): Map<String, Any?> {
        return mapOf(
            "autoDetect" to prefs.getBoolean(KEY_AUTO_DETECT_LOCATION, true),
            "cityId" to prefs.getString(KEY_SELECTED_CITY_ID, null),
            "timezone" to prefs.getString(KEY_CURRENT_TIMEZONE, "IST")
        )
    }

    /**
     * Update location settings.
     */
    fun updateLocationSettings(autoDetect: Boolean, cityId: String?, timezone: String): Boolean {
        return try {
            prefs.edit().apply {
                putBoolean(KEY_AUTO_DETECT_LOCATION, autoDetect)
                if (cityId != null) {
                    putString(KEY_SELECTED_CITY_ID, cityId)
                } else {
                    remove(KEY_SELECTED_CITY_ID)
                }
                putString(KEY_CURRENT_TIMEZONE, timezone)
                apply()
            }
            true
        } catch (e: Exception) {
            android.util.Log.e("SettingsService", "Error updating location settings: $e")
            false
        }
    }

    // ============================================================
    // THEME SETTINGS
    // ============================================================

    /**
     * Get dark mode setting.
     */
    fun isDarkMode(): Boolean {
        return prefs.getBoolean(KEY_DARK_MODE, false)
    }

    /**
     * Set dark mode setting.
     */
    fun setDarkMode(enabled: Boolean): Boolean {
        return try {
            prefs.edit().putBoolean(KEY_DARK_MODE, enabled).apply()
            true
        } catch (e: Exception) {
            android.util.Log.e("SettingsService", "Error setting dark mode: $e")
            false
        }
    }

    // ============================================================
    // LANGUAGE SETTINGS
    // ============================================================

    /**
     * Get current language code.
     */
    fun getLanguageCode(): String {
        return prefs.getString(KEY_LANGUAGE_CODE, "en") ?: "en"
    }

    /**
     * Set language code.
     */
    fun setLanguageCode(code: String): Boolean {
        return try {
            prefs.edit().putString(KEY_LANGUAGE_CODE, code).apply()
            true
        } catch (e: Exception) {
            android.util.Log.e("SettingsService", "Error setting language: $e")
            false
        }
    }

    // ============================================================
    // UTILITY METHODS
    // ============================================================

    /**
     * Get all settings at once for initial load.
     */
    suspend fun getAllSettings(): Map<String, Any?> = withContext(Dispatchers.IO) {
        val permissions = checkAllPermissions()
        val notifications = getNotificationSettings()
        val location = getLocationSettings()

        mapOf(
            "permissions" to permissions,
            "notifications" to notifications,
            "location" to location,
            "darkMode" to isDarkMode(),
            "languageCode" to getLanguageCode()
        )
    }

    /**
     * Reset all settings to defaults.
     */
    fun resetToDefaults(): Boolean {
        return try {
            prefs.edit().clear().apply()
            true
        } catch (e: Exception) {
            android.util.Log.e("SettingsService", "Error resetting settings: $e")
            false
        }
    }
}