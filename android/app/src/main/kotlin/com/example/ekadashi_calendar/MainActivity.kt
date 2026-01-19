package com.example.ekadashi_calendar

import android.Manifest
import android.app.AlarmManager
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Log
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity: FlutterActivity() {
    // Channel names
    private val PERMISSION_CHANNEL = "com.ekadashi.permissions"
    private val LOCATION_CHANNEL = "com.ekadashi.location"
    private val NOTIFICATION_CHANNEL = "com.ekadashi.notifications"
    private val SETTINGS_CHANNEL = "com.ekadashi.settings"

    private val TAG = "EkadashiMain"

    // Coroutine scope for async operations
    private val mainScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    // Permission request launchers
    private var locationPermissionResult: MethodChannel.Result? = null
    private lateinit var locationPermissionLauncher: ActivityResultLauncher<Array<String>>

    // Services
    private lateinit var locationService: LocationService
    private lateinit var notificationScheduler: NotificationScheduler
    private lateinit var settingsService: SettingsService

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize permission launcher before configureFlutterEngine
        locationPermissionLauncher = registerForActivityResult(
            ActivityResultContracts.RequestMultiplePermissions()
        ) { permissions ->
            val fineLocationGranted = permissions[Manifest.permission.ACCESS_FINE_LOCATION] ?: false
            val coarseLocationGranted = permissions[Manifest.permission.ACCESS_COARSE_LOCATION] ?: false
            val granted = fineLocationGranted || coarseLocationGranted

            Log.d(TAG, "Location permission result: fine=$fineLocationGranted, coarse=$coarseLocationGranted")

            locationPermissionResult?.success(granted)
            locationPermissionResult = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize services
        locationService = LocationService(applicationContext)
        notificationScheduler = NotificationScheduler(applicationContext)
        settingsService = SettingsService(applicationContext)

        // Setup permission channel (existing)
        setupPermissionChannel(flutterEngine)

        // Setup location channel (new)
        setupLocationChannel(flutterEngine)

        // Setup notification channel (new)
        setupNotificationChannel(flutterEngine)

        // Setup settings channel (new - for native permission handling)
        setupSettingsChannel(flutterEngine)
    }

    override fun onDestroy() {
        super.onDestroy()
        mainScope.cancel()
    }

    // ==================== PERMISSION CHANNEL ====================

    private fun setupPermissionChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSION_CHANNEL).setMethodCallHandler { call, result ->
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

    // ==================== LOCATION CHANNEL ====================

    private fun setupLocationChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentLocation" -> {
                    mainScope.launch {
                        try {
                            val locationResult = locationService.getCurrentLocation()
                            when (locationResult) {
                                is LocationServiceResult.Success -> result.success(locationResult.toMap())
                                is LocationServiceResult.Error -> result.success(locationResult.toMap())
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "getCurrentLocation error: ${e.message}")
                            result.error("LOCATION_ERROR", e.message, null)
                        }
                    }
                }

                "getCachedLocation" -> {
                    val cached = locationService.getCachedLocation()
                    if (cached != null) {
                        result.success(cached.toMap())
                    } else {
                        result.success(mapOf("success" to false, "errorCode" to "NO_CACHE", "errorMessage" to "No cached location"))
                    }
                }

                "hasLocationPermission" -> {
                    result.success(locationService.hasLocationPermission())
                }

                "requestLocationPermission" -> {
                    // Check if already granted
                    if (locationService.hasLocationPermission()) {
                        Log.d(TAG, "Location permission already granted")
                        result.success(true)
                        return@setMethodCallHandler
                    }

                    // Store the result for the callback
                    locationPermissionResult = result

                    // Request both permissions
                    try {
                        locationPermissionLauncher.launch(
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION
                            )
                        )
                        Log.d(TAG, "Location permission request launched")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error launching permission request: ${e.message}")
                        locationPermissionResult = null
                        result.success(false)
                    }
                }

                "isLocationEnabled" -> {
                    mainScope.launch {
                        result.success(locationService.isLocationEnabled())
                    }
                }

                "getSelectedCityId" -> {
                    result.success(locationService.getSelectedCityId())
                }

                "setSelectedCityId" -> {
                    val cityId = call.argument<String?>("cityId")
                    locationService.setSelectedCityId(cityId)
                    result.success(true)
                }

                "isAutoDetectEnabled" -> {
                    result.success(locationService.isAutoDetectEnabled())
                }

                "setAutoDetectEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    locationService.setAutoDetectEnabled(enabled)
                    result.success(true)
                }

                "getCurrentTimezone" -> {
                    result.success(locationService.getCurrentTimezone())
                }

                "setTimezone" -> {
                    val timezone = call.argument<String>("timezone") ?: "IST"
                    locationService.setTimezone(timezone)
                    result.success(true)
                }

                "clearLocationCache" -> {
                    locationService.clearCache()
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // ==================== NOTIFICATION CHANNEL ====================

    private fun setupNotificationChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleNotification" -> {
                    try {
                        val ekadashiId = call.argument<Int>("ekadashiId") ?: 0
                        val ekadashiName = call.argument<String>("ekadashiName") ?: ""
                        val fastingStartTime = call.argument<String>("fastingStartTime") ?: ""
                        val paranaStartTime = call.argument<String>("paranaStartTime") ?: ""
                        val texts = call.argument<Map<String, String>>("texts") ?: emptyMap()

                        val count = notificationScheduler.scheduleEkadashiNotifications(
                            ekadashiId, ekadashiName, fastingStartTime, paranaStartTime, texts
                        )
                        result.success(count)
                    } catch (e: Exception) {
                        Log.e(TAG, "scheduleNotification error: ${e.message}")
                        result.error("SCHEDULE_ERROR", e.message, null)
                    }
                }

                "scheduleAllNotifications" -> {
                    try {
                        @Suppress("UNCHECKED_CAST")
                        val ekadashiList = call.argument<List<Map<String, Any>>>("ekadashis") ?: emptyList()
                        val texts = call.argument<Map<String, String>>("texts") ?: emptyMap()

                        var totalScheduled = 0
                        for (ekadashi in ekadashiList) {
                            val id = (ekadashi["id"] as? Number)?.toInt() ?: continue
                            val name = ekadashi["name"] as? String ?: continue
                            val fastingStart = ekadashi["fastingStart"] as? String ?: continue
                            val paranaStart = ekadashi["paranaStart"] as? String ?: continue

                            totalScheduled += notificationScheduler.scheduleEkadashiNotifications(
                                id, name, fastingStart, paranaStart, texts
                            )
                        }

                        Log.d(TAG, "Scheduled $totalScheduled notifications for ${ekadashiList.size} Ekadashis")
                        result.success(totalScheduled)
                    } catch (e: Exception) {
                        Log.e(TAG, "scheduleAllNotifications error: ${e.message}")
                        result.error("SCHEDULE_ERROR", e.message, null)
                    }
                }

                "cancelAllNotifications" -> {
                    notificationScheduler.cancelAllNotifications()
                    result.success(true)
                }

                "cancelEkadashiNotifications" -> {
                    val ekadashiId = call.argument<Int>("ekadashiId") ?: 0
                    notificationScheduler.cancelEkadashiNotifications(ekadashiId)
                    result.success(true)
                }

                "showTestNotification" -> {
                    val title = call.argument<String>("title") ?: "Test"
                    val body = call.argument<String>("body") ?: "Test notification"
                    notificationScheduler.showTestNotification(title, body)
                    result.success(true)
                }

                "getPendingCount" -> {
                    mainScope.launch {
                        val count = notificationScheduler.getPendingNotificationCount()
                        result.success(count)
                    }
                }

                "getSettings" -> {
                    result.success(notificationScheduler.getSettings())
                }

                "updateSettings" -> {
                    @Suppress("UNCHECKED_CAST")
                    val settings = call.argument<Map<String, Boolean>>("settings") ?: emptyMap()
                    notificationScheduler.updateSettings(settings)
                    result.success(true)
                }

                "isNotificationsEnabled" -> {
                    result.success(notificationScheduler.isNotificationsEnabled())
                }

                "setNotificationsEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    notificationScheduler.setNotificationsEnabled(enabled)
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // ==================== PERMISSION HELPERS (existing) ====================

    // ==================== SETTINGS CHANNEL (NEW) ====================

    private fun setupSettingsChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // Permission checks - all run on IO thread
                "checkAllPermissions" -> {
                    mainScope.launch {
                        try {
                            val permissions = settingsService.checkAllPermissions()
                            result.success(permissions)
                        } catch (e: Exception) {
                            Log.e(TAG, "checkAllPermissions error: ${e.message}")
                            result.error("PERMISSION_ERROR", e.message, null)
                        }
                    }
                }

                "hasNotificationPermission" -> {
                    mainScope.launch {
                        try {
                            result.success(settingsService.hasNotificationPermission())
                        } catch (e: Exception) {
                            result.error("PERMISSION_ERROR", e.message, null)
                        }
                    }
                }

                "hasExactAlarmPermission" -> {
                    mainScope.launch {
                        try {
                            result.success(settingsService.hasExactAlarmPermission())
                        } catch (e: Exception) {
                            result.error("PERMISSION_ERROR", e.message, null)
                        }
                    }
                }

                "hasLocationPermission" -> {
                    mainScope.launch {
                        try {
                            result.success(settingsService.hasLocationPermission())
                        } catch (e: Exception) {
                            result.error("PERMISSION_ERROR", e.message, null)
                        }
                    }
                }

                "isBatteryOptimizationDisabled" -> {
                    mainScope.launch {
                        try {
                            result.success(settingsService.isBatteryOptimizationDisabled())
                        } catch (e: Exception) {
                            result.error("PERMISSION_ERROR", e.message, null)
                        }
                    }
                }

                // Open settings intents
                "openNotificationSettings" -> {
                    result.success(settingsService.openNotificationSettings())
                }

                "openExactAlarmSettings" -> {
                    result.success(settingsService.openExactAlarmSettings())
                }

                "openBatteryOptimizationSettings" -> {
                    result.success(settingsService.openBatteryOptimizationSettings())
                }

                "openAppSettings" -> {
                    result.success(settingsService.openAppSettings())
                }

                "openLocationSettings" -> {
                    result.success(settingsService.openLocationSettings())
                }

                // Notification settings
                "getNotificationSettings" -> {
                    result.success(settingsService.getNotificationSettings())
                }

                "updateNotificationSettings" -> {
                    @Suppress("UNCHECKED_CAST")
                    val settings = call.argument<Map<String, Boolean>>("settings") ?: emptyMap()
                    result.success(settingsService.updateNotificationSettings(settings))
                }

                "setNotificationSetting" -> {
                    val key = call.argument<String>("key") ?: ""
                    val value = call.argument<Boolean>("value") ?: false
                    result.success(settingsService.setNotificationSetting(key, value))
                }

                // Location settings
                "getLocationSettings" -> {
                    result.success(settingsService.getLocationSettings())
                }

                "updateLocationSettings" -> {
                    val autoDetect = call.argument<Boolean>("autoDetect") ?: true
                    val cityId = call.argument<String?>("cityId")
                    val timezone = call.argument<String>("timezone") ?: "IST"
                    result.success(settingsService.updateLocationSettings(autoDetect, cityId, timezone))
                }

                // Theme settings
                "isDarkMode" -> {
                    result.success(settingsService.isDarkMode())
                }

                "setDarkMode" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    result.success(settingsService.setDarkMode(enabled))
                }

                // Language settings
                "getLanguageCode" -> {
                    result.success(settingsService.getLanguageCode())
                }

                "setLanguageCode" -> {
                    val code = call.argument<String>("code") ?: "en"
                    result.success(settingsService.setLanguageCode(code))
                }

                // All settings
                "getAllSettings" -> {
                    mainScope.launch {
                        try {
                            val settings = settingsService.getAllSettings()
                            result.success(settings)
                        } catch (e: Exception) {
                            Log.e(TAG, "getAllSettings error: ${e.message}")
                            result.error("SETTINGS_ERROR", e.message, null)
                        }
                    }
                }

                "resetToDefaults" -> {
                    result.success(settingsService.resetToDefaults())
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun openAlarmSettings(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                Log.d(TAG, "Opened alarm settings via ACTION_REQUEST_SCHEDULE_EXACT_ALARM")
                return true
            } catch (e: Exception) {
                Log.w(TAG, "ACTION_REQUEST_SCHEDULE_EXACT_ALARM failed: ${e.message}")

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

    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val appOpsResult = checkViaAppOps()
            Log.d(TAG, "AppOpsManager check: $appOpsResult")

            val alarmManagerResult = checkViaAlarmManager()
            Log.d(TAG, "AlarmManager check: $alarmManagerResult")

            if (appOpsResult != null) {
                return appOpsResult
            }

            return alarmManagerResult
        }
        return true
    }

    private fun checkViaAppOps(): Boolean? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
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
                    AppOpsManager.MODE_DEFAULT -> null
                    else -> null
                }
            } catch (e: Exception) {
                Log.e(TAG, "AppOpsManager check failed", e)
                return null
            }
        }
        return null
    }

    private fun checkViaAlarmManager(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
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