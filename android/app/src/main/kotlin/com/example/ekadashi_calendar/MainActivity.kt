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
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
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
    private var mainScope: CoroutineScope? = null

    // Permission request code and pending result
    private val LOCATION_PERMISSION_REQUEST_CODE = 1001
    private var locationPermissionResult: MethodChannel.Result? = null

    // Services - lazy initialized to prevent issues during recreation
    private var locationService: LocationService? = null
    private var notificationScheduler: NotificationScheduler? = null
    private var settingsService: SettingsService? = null

    // Flag to prevent duplicate initialization
    private var servicesInitialized = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        // Handle the splash screen transition.
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize coroutine scope if not already created
        if (mainScope == null) {
            mainScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
        }

        // Initialize services only once (prevent duplicate init on recreation)
        if (!servicesInitialized) {
            locationService = LocationService(applicationContext)
            notificationScheduler = NotificationScheduler(applicationContext)
            settingsService = SettingsService(applicationContext)
            servicesInitialized = true
            Log.d(TAG, "Services initialized")
        } else {
            Log.d(TAG, "Services already initialized, skipping")
        }

        // Setup channels (these need to be re-setup on engine recreation)
        setupPermissionChannel(flutterEngine)
        setupLocationChannel(flutterEngine)
        setupNotificationChannel(flutterEngine)
        setupSettingsChannel(flutterEngine)
    }

    override fun onDestroy() {
        // Cancel coroutine scope to prevent leaks
        mainScope?.cancel()
        mainScope = null
        
        // Clear pending permission result to prevent memory leaks
        locationPermissionResult = null
        
        // Clear service references to prevent stale context during recreation
        locationService = null
        notificationScheduler = null
        settingsService = null
        servicesInitialized = false
        
        Log.d(TAG, "onDestroy: Cleaned up services")
        
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        when (requestCode) {
            LOCATION_PERMISSION_REQUEST_CODE -> {
                val granted = grantResults.isNotEmpty() &&
                        grantResults.any { it == PackageManager.PERMISSION_GRANTED }

                Log.d(TAG, "Location permission result: granted=$granted")

                locationPermissionResult?.success(granted)
                locationPermissionResult = null
            }
        }
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
            // Guard against null services during recreation
            val locService = locationService
            val scope = mainScope
            if (locService == null || scope == null) {
                Log.w(TAG, "Services not ready for ${call.method}")
                result.error("SERVICE_NOT_READY", "Services not initialized", null)
                return@setMethodCallHandler
            }

            when (call.method) {
                "getCurrentLocation" -> {
                    scope.launch {
                        try {
                            val locationResult = locService.getCurrentLocation()
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
                    val cached = locService.getCachedLocation()
                    if (cached != null) {
                        result.success(cached.toMap())
                    } else {
                        result.success(mapOf("success" to false, "errorCode" to "NO_CACHE", "errorMessage" to "No cached location"))
                    }
                }

                "hasLocationPermission" -> {
                    result.success(locService.hasLocationPermission())
                }

                "requestLocationPermission" -> {
                    // Check if already granted
                    if (locService.hasLocationPermission()) {
                        Log.d(TAG, "Location permission already granted")
                        result.success(true)
                        return@setMethodCallHandler
                    }

                    // Store the result for the callback
                    locationPermissionResult = result

                    // Request both permissions using traditional approach
                    try {
                        ActivityCompat.requestPermissions(
                            this@MainActivity,
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION
                            ),
                            LOCATION_PERMISSION_REQUEST_CODE
                        )
                        Log.d(TAG, "Location permission request launched")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error launching permission request: ${e.message}")
                        locationPermissionResult = null
                        result.success(false)
                    }
                }

                "isLocationEnabled" -> {
                    scope.launch {
                        result.success(locService.isLocationEnabled())
                    }
                }

                "getSelectedCityId" -> {
                    result.success(locService.getSelectedCityId())
                }

                "setSelectedCityId" -> {
                    val cityId = call.argument<String?>("cityId")
                    locService.setSelectedCityId(cityId)
                    result.success(true)
                }

                "isAutoDetectEnabled" -> {
                    result.success(locService.isAutoDetectEnabled())
                }

                "setAutoDetectEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    locService.setAutoDetectEnabled(enabled)
                    result.success(true)
                }

                "getCurrentTimezone" -> {
                    result.success(locService.getCurrentTimezone())
                }

                "setTimezone" -> {
                    val timezone = call.argument<String>("timezone") ?: "IST"
                    locService.setTimezone(timezone)
                    result.success(true)
                }

                "clearLocationCache" -> {
                    locService.clearCache()
                    result.success(true)
                }

                "shouldShowRequestRationale" -> {
                    // Check if we should show permission rationale
                    // Returns false if user has permanently denied ("Don't ask again")
                    result.success(locService.shouldShowRequestPermissionRationale(this@MainActivity))
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
            // Guard against null services during recreation
            val notifScheduler = notificationScheduler
            val scope = mainScope
            if (notifScheduler == null) {
                Log.w(TAG, "NotificationScheduler not ready for ${call.method}")
                result.error("SERVICE_NOT_READY", "Services not initialized", null)
                return@setMethodCallHandler
            }

            when (call.method) {
                "scheduleNotification" -> {
                    try {
                        val ekadashiId = call.argument<Int>("ekadashiId") ?: 0
                        val ekadashiName = call.argument<String>("ekadashiName") ?: ""
                        val fastingStartTime = call.argument<String>("fastingStartTime") ?: ""
                        val paranaStartTime = call.argument<String>("paranaStartTime") ?: ""
                        val texts = call.argument<Map<String, String>>("texts") ?: emptyMap()

                        val count = notifScheduler.scheduleEkadashiNotifications(
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

                            totalScheduled += notifScheduler.scheduleEkadashiNotifications(
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
                    notifScheduler.cancelAllNotifications()
                    result.success(true)
                }

                "cancelEkadashiNotifications" -> {
                    val ekadashiId = call.argument<Int>("ekadashiId") ?: 0
                    notifScheduler.cancelEkadashiNotifications(ekadashiId)
                    result.success(true)
                }

                "showTestNotification" -> {
                    val title = call.argument<String>("title") ?: "Test"
                    val body = call.argument<String>("body") ?: "Test notification"
                    notifScheduler.showTestNotification(title, body)
                    result.success(true)
                }

                "getPendingCount" -> {
                    if (scope != null) {
                        scope.launch {
                            val count = notifScheduler.getPendingNotificationCount()
                            result.success(count)
                        }
                    } else {
                        result.success(0)
                    }
                }

                "getSettings" -> {
                    result.success(notifScheduler.getSettings())
                }

                "updateSettings" -> {
                    @Suppress("UNCHECKED_CAST")
                    val settings = call.argument<Map<String, Boolean>>("settings") ?: emptyMap()
                    notifScheduler.updateSettings(settings)
                    result.success(true)
                }

                "isNotificationsEnabled" -> {
                    result.success(notifScheduler.isNotificationsEnabled())
                }

                "setNotificationsEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    notifScheduler.setNotificationsEnabled(enabled)
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
            // Guard against null services during recreation
            val settingsSvc = settingsService
            val scope = mainScope
            if (settingsSvc == null) {
                Log.w(TAG, "SettingsService not ready for ${call.method}")
                result.error("SERVICE_NOT_READY", "Services not initialized", null)
                return@setMethodCallHandler
            }

            when (call.method) {
                // Permission checks - all run on IO thread
                "checkAllPermissions" -> {
                    if (scope != null) {
                        scope.launch {
                            try {
                                val permissions = settingsSvc.checkAllPermissions()
                                result.success(permissions)
                            } catch (e: Exception) {
                                Log.e(TAG, "checkAllPermissions error: ${e.message}")
                                // Return safe defaults on error
                                result.success(mapOf(
                                    "hasNotificationPermission" to false,
                                    "hasExactAlarmPermission" to true,
                                    "hasLocationPermission" to false,
                                    "isBatteryOptimizationDisabled" to false,
                                    "androidVersion" to android.os.Build.VERSION.SDK_INT,
                                    "requiresExactAlarmPermission" to (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S),
                                    "requiresNotificationPermission" to (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU)
                                ))
                            }
                        }
                    } else {
                        result.success(emptyMap<String, Any>())
                    }
                }

                "hasNotificationPermission" -> {
                    if (scope != null) {
                        scope.launch {
                            try {
                                result.success(settingsSvc.hasNotificationPermission())
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        }
                    } else {
                        result.success(false)
                    }
                }

                "hasExactAlarmPermission" -> {
                    if (scope != null) {
                        scope.launch {
                            try {
                                result.success(settingsSvc.hasExactAlarmPermission())
                            } catch (e: Exception) {
                                result.success(true)
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }

                "hasLocationPermission" -> {
                    if (scope != null) {
                        scope.launch {
                            try {
                                result.success(settingsSvc.hasLocationPermission())
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        }
                    } else {
                        result.success(false)
                    }
                }

                "isBatteryOptimizationDisabled" -> {
                    if (scope != null) {
                        scope.launch {
                            try {
                                result.success(settingsSvc.isBatteryOptimizationDisabled())
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        }
                    } else {
                        result.success(false)
                    }
                }

                // Open settings intents
                "openNotificationSettings" -> {
                    result.success(settingsSvc.openNotificationSettings())
                }

                "openExactAlarmSettings" -> {
                    result.success(settingsSvc.openExactAlarmSettings())
                }

                "openBatteryOptimizationSettings" -> {
                    result.success(settingsSvc.openBatteryOptimizationSettings())
                }

                "openAppSettings" -> {
                    result.success(settingsSvc.openAppSettings())
                }

                "openLocationSettings" -> {
                    result.success(settingsSvc.openLocationSettings())
                }

                // Notification settings
                "getNotificationSettings" -> {
                    result.success(settingsSvc.getNotificationSettings())
                }

                "updateNotificationSettings" -> {
                    @Suppress("UNCHECKED_CAST")
                    val settings = call.argument<Map<String, Boolean>>("settings") ?: emptyMap()
                    result.success(settingsSvc.updateNotificationSettings(settings))
                }

                "setNotificationSetting" -> {
                    val key = call.argument<String>("key") ?: ""
                    val value = call.argument<Boolean>("value") ?: false
                    result.success(settingsSvc.setNotificationSetting(key, value))
                }

                // Location settings
                "getLocationSettings" -> {
                    result.success(settingsSvc.getLocationSettings())
                }

                "updateLocationSettings" -> {
                    val autoDetect = call.argument<Boolean>("autoDetect") ?: true
                    val cityId = call.argument<String?>("cityId")
                    val timezone = call.argument<String>("timezone") ?: "IST"
                    result.success(settingsSvc.updateLocationSettings(autoDetect, cityId, timezone))
                }

                // Theme settings
                "isDarkMode" -> {
                    result.success(settingsSvc.isDarkMode())
                }

                "setDarkMode" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    result.success(settingsSvc.setDarkMode(enabled))
                }

                // Language settings
                "getLanguageCode" -> {
                    result.success(settingsSvc.getLanguageCode())
                }

                "setLanguageCode" -> {
                    val code = call.argument<String>("code") ?: "en"
                    result.success(settingsSvc.setLanguageCode(code))
                }

                // All settings
                "getAllSettings" -> {
                    if (scope != null) {
                        scope.launch {
                            try {
                                val settings = settingsSvc.getAllSettings()
                                result.success(settings)
                            } catch (e: Exception) {
                                Log.e(TAG, "getAllSettings error: ${e.message}")
                                result.success(emptyMap<String, Any>())
                            }
                        }
                    } else {
                        result.success(emptyMap<String, Any>())
                    }
                }

                "resetToDefaults" -> {
                    result.success(settingsSvc.resetToDefaults())
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