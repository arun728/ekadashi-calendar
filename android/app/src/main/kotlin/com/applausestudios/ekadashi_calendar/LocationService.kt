package com.applausestudios.ekadashi_calendar

import android.app.Activity
import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.*
import kotlinx.coroutines.*
import kotlinx.coroutines.tasks.await
import java.util.Locale
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Native Kotlin location service to replace Flutter Geolocator plugin.
 *
 * Key improvements over Geolocator:
 * 1. Runs on background thread (Dispatchers.IO) - never blocks main thread
 * 2. Proper lifecycle management - no service binding issues
 * 3. Configurable timeouts and fallbacks
 * 4. Built-in caching for instant responses
 */
class LocationService(private val context: Context) {

    companion object {
        private const val TAG = "LocationService"
        private const val LOCATION_TIMEOUT_MS = 30000L // 30 seconds
        private const val CACHE_VALIDITY_MS = 5 * 60 * 1000L // 5 minutes

        // SharedPreferences keys
        private const val PREFS_NAME = "location_cache"
        private const val KEY_LATITUDE = "cached_latitude"
        private const val KEY_LONGITUDE = "cached_longitude"
        private const val KEY_CITY = "cached_city"
        private const val KEY_TIMESTAMP = "cached_timestamp"
        private const val KEY_TIMEZONE = "cached_timezone"
        private const val KEY_SELECTED_CITY_ID = "selected_city_id"
        private const val KEY_AUTO_DETECT = "auto_detect_location"
    }

    private val fusedLocationClient: FusedLocationProviderClient by lazy {
        LocationServices.getFusedLocationProviderClient(context)
    }

    private val prefs by lazy {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    /**
     * Check if location permission is granted
     */
    fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Check if we should show permission rationale.
     * Returns false if user has permanently denied ("Don't ask again").
     * This requires an Activity reference to check.
     */
    fun shouldShowRequestPermissionRationale(activity: Activity): Boolean {
        return androidx.core.app.ActivityCompat.shouldShowRequestPermissionRationale(
            activity,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) || androidx.core.app.ActivityCompat.shouldShowRequestPermissionRationale(
            activity,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
    }

    /**
     * Check if location services are enabled
     */
    suspend fun isLocationEnabled(): Boolean = withContext(Dispatchers.IO) {
        try {
            val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
            locationManager.isProviderEnabled(android.location.LocationManager.GPS_PROVIDER) ||
                    locationManager.isProviderEnabled(android.location.LocationManager.NETWORK_PROVIDER)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking location enabled: ${e.message}")
            false
        }
    }

    /**
     * Get current location with timeout and fallback to cache
     * Runs entirely on background thread
     */
    suspend fun getCurrentLocation(): LocationServiceResult = withContext(Dispatchers.IO) {
        Log.d(TAG, "getCurrentLocation called")

        // Check permission first
        if (!hasLocationPermission()) {
            Log.w(TAG, "Location permission not granted")
            return@withContext LocationServiceResult.Error("PERMISSION_DENIED", "Location permission not granted")
        }

        // Check if location services enabled
        if (!isLocationEnabled()) {
            Log.w(TAG, "Location services disabled")
            // Try to return cached location
            getCachedLocation()?.let { cached ->
                Log.d(TAG, "Returning cached location (services disabled)")
                return@withContext cached
            }
            return@withContext LocationServiceResult.Error("LOCATION_DISABLED", "Location services are disabled")
        }

        try {
            // 1. Try to get fresh location with timeout (Fused)
            val location = withTimeoutOrNull(LOCATION_TIMEOUT_MS) {
                getFreshLocation()
            }

            if (location != null) {
                return@withContext processLocation(location)
            } 
            
            Log.w(TAG, "Fused location timeout, trying active legacy updates")
            
            // 2. Timeout - try ACTIVE Legacy Update (wakes up emulator)
            val activeLegacy = awaitLegacyLocationUpdate()
             if (activeLegacy != null) {
                Log.d(TAG, "Got location from active legacy provider")
                return@withContext processLocation(activeLegacy)
            }
            
            Log.w(TAG, "Active legacy failed, checking passive last known")

            // 3. Try passive legacy LocationManager (GPS/Network)
            // This is often more reliable on emulators if active failed
            val legacyLocation = getLegacyFallback()
            if (legacyLocation != null) {
                Log.d(TAG, "Got location from passive legacy provider")
                return@withContext processLocation(legacyLocation)
            }

            Log.w(TAG, "Legacy failed, trying last known Fused location")

            // 3. Try last known location (Fused)
            return@withContext getLastKnownOrCached()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error getting location: ${e.message}")
            // Try cached as fallback
            getCachedLocation()?.let { return@withContext it }
            return@withContext LocationServiceResult.Error("LOCATION_ERROR", e.message ?: "Unknown error")
        }
    }

    private fun processLocation(location: Location): LocationServiceResult.Success {
        Log.d(TAG, "Processing location: ${location.latitude}, ${location.longitude}")
        val cityName = getCityName(location.latitude, location.longitude)
        val timezone = detectTimezone(location.latitude, location.longitude)

        // Cache the result
        cacheLocation(location.latitude, location.longitude, cityName, timezone)

        return LocationServiceResult.Success(
            latitude = location.latitude,
            longitude = location.longitude,
            city = cityName,
            timezone = timezone
        )
    }

    /**
     * Actively wait for a legacy location update (useful for waking up emulators)
     */
    @Suppress("MissingPermission")
    private suspend fun awaitLegacyLocationUpdate(): Location? = suspendCancellableCoroutine { continuation ->
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
        
        val listener = object : android.location.LocationListener {
            override fun onLocationChanged(location: Location) {
                if (continuation.isActive) {
                    Log.d(TAG, "Legacy active update received: $location")
                    continuation.resume(location)
                    locationManager.removeUpdates(this)
                }
            }
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
            override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}
        }

        try {
            // Try GPS first, then Network
            val provider = when {
                locationManager.isProviderEnabled(android.location.LocationManager.GPS_PROVIDER) -> android.location.LocationManager.GPS_PROVIDER
                locationManager.isProviderEnabled(android.location.LocationManager.NETWORK_PROVIDER) -> android.location.LocationManager.NETWORK_PROVIDER
                else -> null
            }

            if (provider != null) {
                Log.d(TAG, "Requesting active legacy update from $provider")
                locationManager.requestLocationUpdates(
                    provider,
                    1000L,
                    0f,
                    listener,
                    Looper.getMainLooper()
                )

                // Short timeout for this fallback (5 seconds)
                // We don't want to delay the user too long if this also fails
                val handler = android.os.Handler(Looper.getMainLooper())
                handler.postDelayed({
                    if (continuation.isActive) {
                         Log.w(TAG, "Legacy active update timed out")
                         try { locationManager.removeUpdates(listener) } catch(e: Exception) {}
                         continuation.resume(null)
                    }
                }, 5000L)
                
                continuation.invokeOnCancellation {
                    try { locationManager.removeUpdates(listener) } catch(e: Exception) {}
                }
            } else {
                 Log.w(TAG, "No suitable legacy provider enabled")
                 continuation.resume(null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting legacy updates: ${e.message}")
            if (continuation.isActive) continuation.resume(null)
        }
    }

    /**
     * fallback using legacy LocationManager (useful for emulators)
     */
    @Suppress("MissingPermission")
    private fun getLegacyFallback(): Location? {
        try {
            val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
            val providers = locationManager.getProviders(true)
            
            var bestLocation: Location? = null
            
            for (provider in providers) {
                val l = locationManager.getLastKnownLocation(provider) ?: continue
                if (bestLocation == null || l.time > bestLocation.time) {
                    bestLocation = l
                }
            }
            return bestLocation
        } catch (e: Exception) {
            Log.e(TAG, "Legacy fallback error: ${e.message}")
            return null
        }
    }

    /**
     * Get fresh location using FusedLocationProviderClient
     */
    @Suppress("MissingPermission")
    private suspend fun getFreshLocation(): Location? = suspendCancellableCoroutine { continuation ->
        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            1000L
        ).apply {
            setMaxUpdates(1)
            setMinUpdateIntervalMillis(500L)
            setWaitForAccurateLocation(false)
        }.build()

        val locationCallback = object : LocationCallback() {
            // Use fully qualified name to avoid conflict with our LocationServiceResult
            override fun onLocationResult(result: com.google.android.gms.location.LocationResult) {
                fusedLocationClient.removeLocationUpdates(this)
                // Use locations list and get the last one
                val location = result.locations.lastOrNull()
                if (continuation.isActive) {
                    continuation.resume(location)
                }
            }
        }

        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                Looper.getMainLooper()
            )

            continuation.invokeOnCancellation {
                fusedLocationClient.removeLocationUpdates(locationCallback)
            }
        } catch (e: Exception) {
            if (continuation.isActive) {
                continuation.resumeWithException(e)
            }
        }
    }

    /**
     * Get last known location or fall back to cache
     */
    @Suppress("MissingPermission")
    private suspend fun getLastKnownOrCached(): LocationServiceResult {
        if (!hasLocationPermission()) {
            return getCachedLocation() ?: LocationServiceResult.Error("PERMISSION_DENIED", "No permission")
        }

        try {
            val lastLocation = fusedLocationClient.lastLocation.await()
            if (lastLocation != null) {
                Log.d(TAG, "Got last known location")
                val cityName = getCityName(lastLocation.latitude, lastLocation.longitude)
                val timezone = detectTimezone(lastLocation.latitude, lastLocation.longitude)
                cacheLocation(lastLocation.latitude, lastLocation.longitude, cityName, timezone)
                return LocationServiceResult.Success(
                    latitude = lastLocation.latitude,
                    longitude = lastLocation.longitude,
                    city = cityName,
                    timezone = timezone
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting last location: ${e.message}")
        }

        // Fall back to cache
        val cached = getCachedLocation()
        if (cached != null) return cached

        // Last Resort for Emulators
        if (isEmulator()) {
             Log.w(TAG, "Emulator detected with no location - returning Last Resort (India/IST)")
             return LocationServiceResult.Success(
                latitude = 28.6139,
                longitude = 77.2090,
                city = "New Delhi",
                timezone = "IST"
             )
        }

        return LocationServiceResult.Error("NO_LOCATION", "Could not get location")
    }

    /**
     * Check if running on emulator
     */
    private fun isEmulator(): Boolean {
        return (android.os.Build.FINGERPRINT.startsWith("generic")
                || android.os.Build.FINGERPRINT.startsWith("unknown")
                || android.os.Build.MODEL.contains("google_sdk")
                || android.os.Build.MODEL.contains("Emulator")
                || android.os.Build.MODEL.contains("Android SDK built for x86")
                || android.os.Build.MANUFACTURER.contains("Genymotion")
                || (android.os.Build.BRAND.startsWith("generic") && android.os.Build.DEVICE.startsWith("generic"))
                || "google_sdk" == android.os.Build.PRODUCT)
    }

    /**
     * Get cached location instantly (for fast UI response)
     */
    fun getCachedLocation(): LocationServiceResult.Success? {
        val lat = prefs.getFloat(KEY_LATITUDE, Float.MIN_VALUE)
        val lng = prefs.getFloat(KEY_LONGITUDE, Float.MIN_VALUE)
        val city = prefs.getString(KEY_CITY, null)
        val timezone = prefs.getString(KEY_TIMEZONE, null)
        val timestamp = prefs.getLong(KEY_TIMESTAMP, 0)

        if (lat == Float.MIN_VALUE || lng == Float.MIN_VALUE) {
            return null
        }

        // Check if cache is still valid (within 5 minutes)
        val cacheAge = System.currentTimeMillis() - timestamp
        if (cacheAge > CACHE_VALIDITY_MS) {
            Log.d(TAG, "Cache expired (age: ${cacheAge}ms)")
            // Still return it but log that it's old
        }

        Log.d(TAG, "Returning cached location: $lat, $lng, $city")
        return LocationServiceResult.Success(
            latitude = lat.toDouble(),
            longitude = lng.toDouble(),
            city = city ?: "Unknown",
            timezone = timezone ?: "IST"
        )
    }

    /**
     * Cache location for fast retrieval
     */
    private fun cacheLocation(lat: Double, lng: Double, city: String, timezone: String) {
        prefs.edit().apply {
            putFloat(KEY_LATITUDE, lat.toFloat())
            putFloat(KEY_LONGITUDE, lng.toFloat())
            putString(KEY_CITY, city)
            putString(KEY_TIMEZONE, timezone)
            putLong(KEY_TIMESTAMP, System.currentTimeMillis())
            apply()
        }
        Log.d(TAG, "Cached location: $lat, $lng, $city, $timezone")
    }

    /**
     * Reverse geocode to get city name
     */
    @Suppress("DEPRECATION")
    private fun getCityName(lat: Double, lng: Double): String {
        try {
            // Use English locale to ensure consistent city names (e.g. "Mysuru" vs "Mysore" or non-English chars)
            val geocoder = Geocoder(context, Locale.US)
            val addresses = geocoder.getFromLocation(lat, lng, 1)
            if (!addresses.isNullOrEmpty()) {
                val address = addresses[0]
                // Try locality first, then subAdminArea, then adminArea
                val city = address.locality
                    ?: address.subAdminArea
                    ?: address.adminArea
                    ?: "Unknown"
                 Log.d(TAG, "Resolved city: $city ($lat, $lng)")
                 return city
            } else {
                Log.w(TAG, "Geocoder returned no addresses for $lat, $lng")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Geocoding error: ${e.message}")
        }

        // Fallback for emulators/offline
        return getOfflineFallbackCity(lat, lng)
    }

    /**
     * Offline fallback for common emulator locations when Geocoder fails
     */
    private fun getOfflineFallbackCity(lat: Double, lng: Double): String {
        // Simple distance check (approximate)
        // 1 degree ~ 111km. we check within ~0.5 degree (~50km)
        
        fun isNear(targetLat: Double, targetLng: Double): Boolean {
            return Math.abs(lat - targetLat) < 0.5 && Math.abs(lng - targetLng) < 0.5
        }

        return when {
            // US West
            isNear(37.338, -121.885) -> "San Jose" // Android Emulator Default
            isNear(37.422, -122.084) -> "Mountain View" // Googleplex
            isNear(37.774, -122.419) -> "San Francisco"
            isNear(34.052, -118.243) -> "Los Angeles"
            isNear(47.606, -122.332) -> "Seattle"

            // US East
            isNear(40.712, -74.006) -> "New York"
            isNear(39.952, -75.165) -> "Philadelphia"
            isNear(38.907, -77.036) -> "Washington DC"
            isNear(42.360, -71.058) -> "Boston"

            // EU
            isNear(51.507, -0.127) -> "London"
            isNear(48.856, 2.352) -> "Paris"
            isNear(52.520, 13.405) -> "Berlin"

            // India
            isNear(12.971, 77.594) -> "Bengaluru"
            isNear(19.076, 72.877) -> "Mumbai"
            isNear(28.613, 77.209) -> "Delhi"
            isNear(13.082, 80.270) -> "Chennai"
            isNear(17.385, 78.486) -> "Hyderabad"
            isNear(22.572, 88.363) -> "Kolkata"

            else -> "Unknown"
        }
    }

    /**
     * Detect timezone based on coordinates
     * Maps to our supported timezone groups: IST, EST, CST, MST, PST
     */
    private fun detectTimezone(lat: Double, lng: Double): String {
        // Simple longitude-based detection for supported regions
        return when {
            // India region (roughly 68°E to 97°E)
            lng >= 68.0 && lng <= 97.0 && lat >= 6.0 && lat <= 37.0 -> "IST"

            // US Eastern (roughly -85°W to -67°W)
            lng >= -85.0 && lng <= -67.0 && lat >= 24.0 && lat <= 50.0 -> "EST"

            // US Central (roughly -102°W to -85°W)
            lng >= -102.0 && lng < -85.0 && lat >= 24.0 && lat <= 50.0 -> "CST"

            // US Mountain (roughly -115°W to -102°W)
            lng >= -115.0 && lng < -102.0 && lat >= 24.0 && lat <= 50.0 -> "MST"

            // US Pacific (roughly -125°W to -115°W)
            lng >= -125.0 && lng < -115.0 && lat >= 24.0 && lat <= 50.0 -> "PST"

            // Default to IST for other regions
            else -> "IST"
        }
    }

    /**
     * Get selected city ID (for manual selection)
     */
    fun getSelectedCityId(): String? {
        return prefs.getString(KEY_SELECTED_CITY_ID, null)
    }

    /**
     * Set selected city ID (for manual selection)
     */
    fun setSelectedCityId(cityId: String?) {
        prefs.edit().putString(KEY_SELECTED_CITY_ID, cityId).apply()
    }

    /**
     * Check if auto-detect is enabled
     */
    fun isAutoDetectEnabled(): Boolean {
        return prefs.getBoolean(KEY_AUTO_DETECT, true)
    }

    /**
     * Set auto-detect enabled state
     */
    fun setAutoDetectEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_AUTO_DETECT, enabled).apply()
    }

    /**
     * Get current timezone (from cache or selected city)
     */
    fun getCurrentTimezone(): String {
        return prefs.getString(KEY_TIMEZONE, "IST") ?: "IST"
    }

    /**
     * Set timezone manually (when user selects a city)
     */
    fun setTimezone(timezone: String) {
        prefs.edit().putString(KEY_TIMEZONE, timezone).apply()
    }

    /**
     * Clear all cached location data
     */
    fun clearCache() {
        prefs.edit().clear().apply()
    }
}

/**
 * Sealed class representing location result.
 * Named LocationServiceResult to avoid conflict with com.google.android.gms.location.LocationResult
 */
sealed class LocationServiceResult {
    data class Success(
        val latitude: Double,
        val longitude: Double,
        val city: String,
        val timezone: String
    ) : LocationServiceResult() {
        fun toMap(): Map<String, Any> = mapOf(
            "latitude" to latitude,
            "longitude" to longitude,
            "city" to city,
            "timezone" to timezone,
            "success" to true
        )
    }

    data class Error(
        val code: String,
        val message: String
    ) : LocationServiceResult() {
        fun toMap(): Map<String, Any> = mapOf(
            "success" to false,
            "errorCode" to code,
            "errorMessage" to message
        )
    }
}