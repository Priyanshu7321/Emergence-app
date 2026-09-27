package com.example.emergence

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.firebase.FirebaseApp
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ServerValue

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class LocationForegroundService : Service() {

    companion object {

        private const val TAG = "LocationFgService"

        private const val CHANNEL_ID =
            "location_sharing_channel"

        private const val NOTIFICATION_ID = 1001

        private const val LOCATION_INTERVAL = 5000L

        fun start(context: Context) {
            Log.d(TAG, "start() called — requesting foreground service start")

            val intent =
                Intent(
                    context,
                    LocationForegroundService::class.java
                )

            ContextCompat.startForegroundService(
                context,
                intent
            )
        }

        fun stop(context: Context) {
            Log.d(TAG, "stop() called — requesting service stop")

            val intent =
                Intent(
                    context,
                    LocationForegroundService::class.java
                )

            context.stopService(intent)
        }
    }

    private lateinit var fusedLocationClient:
            FusedLocationProviderClient

    private lateinit var locationCallback:
            LocationCallback

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate() — service instance created")

        try {
            if (FirebaseApp.getApps(this).isEmpty()) {
                FirebaseApp.initializeApp(this)
                Log.d(TAG, "onCreate() — FirebaseApp initialized in service")
            }
        } catch (e: Exception) {
            Log.e(TAG, "onCreate() — FirebaseApp init error", e)
        }

        fusedLocationClient =
            LocationServices.getFusedLocationProviderClient(
                this
            )

        createNotificationChannel()

        startForeground(
            NOTIFICATION_ID,
            createNotification()
        )
        Log.d(TAG, "onCreate() — startForeground() called with notification id=$NOTIFICATION_ID")

        locationCallback =
            object : LocationCallback() {

                override fun onLocationResult(
                    result: LocationResult
                ) {

                    val location =
                        result.lastLocation
                            ?: run {
                                Log.w(TAG, "onLocationResult() — result had no lastLocation")
                                return
                            }

                    Log.d(
                        TAG,
                        "onLocationResult() — lat=${location.latitude}, lng=${location.longitude}, acc=${location.accuracy}, bearing=${location.bearing}"
                    )

                    writeLocation(
                        location.latitude,
                        location.longitude,
                        location.accuracy,
                        location.bearing
                    )
                }
            }
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {
        Log.d(TAG, "onStartCommand() — startId=$startId, flags=$flags")

        startLocationUpdates()

        return START_STICKY
    }

    private val handler = android.os.Handler(android.os.Looper.getMainLooper())

    private val locationRunnable = object : Runnable {
        override fun run() {
            Log.d(TAG, "locationRunnable — tick, requesting current location")

            if (
                ActivityCompat.checkSelfPermission(
                    this@LocationForegroundService,
                    Manifest.permission.ACCESS_FINE_LOCATION
                ) != PackageManager.PERMISSION_GRANTED &&
                ActivityCompat.checkSelfPermission(
                    this@LocationForegroundService,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                Log.e(TAG, "Location permission not granted — stopping service")
                stopSelf()
                return
            }

            fusedLocationClient
                .getCurrentLocation(
                    Priority.PRIORITY_HIGH_ACCURACY,
                    null
                )
                .addOnSuccessListener { location ->

                    if (location != null) {

                        Log.d(
                            TAG,
                            "getCurrentLocation success — lat=${location.latitude}, lng=${location.longitude}, acc=${location.accuracy}, bearing=${location.bearing}"
                        )

                        writeLocation(
                            latitude = location.latitude,
                            longitude = location.longitude,
                            accuracy = location.accuracy,
                            bearing = location.bearing
                        )
                    } else {
                        Log.w(TAG, "getCurrentLocation success but location was null")
                        requestLastKnownLocationFallback()
                    }
                }
                .addOnFailureListener { error ->
                    Log.e(TAG, "getCurrentLocation failed", error)
                    requestLastKnownLocationFallback()
                }

            handler.postDelayed(
                this,
                LOCATION_INTERVAL
            )
            Log.d(TAG, "locationRunnable — rescheduled in ${LOCATION_INTERVAL}ms")
        }
    }

    private fun requestLastKnownLocationFallback() {
        try {
            if (
                ActivityCompat.checkSelfPermission(
                    this,
                    Manifest.permission.ACCESS_FINE_LOCATION
                ) != PackageManager.PERMISSION_GRANTED &&
                ActivityCompat.checkSelfPermission(
                    this,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                return
            }

            fusedLocationClient.lastLocation
                .addOnSuccessListener { location ->
                    if (location != null) {
                        Log.d(
                            TAG,
                            "lastLocation fallback — lat=${location.latitude}, lng=${location.longitude}, bearing=${location.bearing}"
                        )
                        writeLocation(
                            latitude = location.latitude,
                            longitude = location.longitude,
                            accuracy = location.accuracy,
                            bearing = location.bearing
                        )
                    }
                }
                .addOnFailureListener { error ->
                    Log.e(TAG, "lastLocation fallback failed", error)
                }
        } catch (e: Exception) {
            Log.e(TAG, "lastLocation fallback exception", e)
        }
    }

    private fun startLocationUpdates() {
        Log.d(TAG, "startLocationUpdates() — starting 5-second location loop")

        handler.removeCallbacks(locationRunnable)

        handler.post(locationRunnable)
    }

    private fun formatReadableDate(timestamp: Long): String {
        return try {
            val sdf = SimpleDateFormat(
                "yyyy-MM-dd HH:mm:ss z",
                Locale.getDefault()
            )
            sdf.format(Date(timestamp))
        } catch (e: Exception) {
            ""
        }
    }

    private fun writeLocation(
        latitude: Double,
        longitude: Double,
        accuracy: Float,
        bearing: Float
    ) {

        val preferences =
            getSharedPreferences(
                "device_preferences",
                MODE_PRIVATE
            )

        val uid =
            preferences.getString(
                "device_user_id",
                null
            ) ?: run {
                Log.e(TAG, "writeLocation() — no device_user_id in preferences, aborting write")
                return
            }

        val userName =
            preferences.getString(
                "user_name",
                null
            )

        val reference =
            FirebaseDatabase
                .getInstance()
                .getReference(
                    "locations/$uid"
                )

        val nowTimestamp = System.currentTimeMillis()
        val readableTime = formatReadableDate(nowTimestamp)

        val data =
            hashMapOf<String, Any>(
                "latitude" to latitude,
                "longitude" to longitude,
                "accuracy" to accuracy,
                "bearing" to bearing,
                "updatedAt" to nowTimestamp,
                "updatedAtReadable" to readableTime
            )

        if (userName != null && userName.isNotBlank()) {
            data["name"] = userName
        }

        Log.d(TAG, "writeLocation() — writing to locations/$uid, name=$userName, time=$readableTime, bearing=$bearing")

        reference.setValue(data)
            .addOnSuccessListener {
                Log.d(TAG, "writeLocation() — Firebase write succeeded for uid=$uid")
            }
            .addOnFailureListener { error ->
                Log.e(TAG, "writeLocation() — Firebase write failed for uid=$uid", error)
            }
    }

    private fun createNotificationChannel() {

        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.O
        ) {
            Log.d(TAG, "createNotificationChannel() — creating channel $CHANNEL_ID")

            val channel =
                NotificationChannel(
                    CHANNEL_ID,
                    "Location Sharing",
                    NotificationManager.IMPORTANCE_LOW
                )

            channel.enableLights(false)
            channel.enableVibration(false)
            channel.setShowBadge(false)

            getSystemService(
                NotificationManager::class.java
            ).createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {

        val stopIntent =
            Intent(
                this,
                StopLocationReceiver::class.java
            )

        val stopPendingIntent =
            PendingIntent.getBroadcast(
                this,
                100,
                stopIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                        PendingIntent.FLAG_IMMUTABLE
            )

        val launchIntent =
            packageManager.getLaunchIntentForPackage(packageName)
                ?.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)

        val contentPendingIntent =
            PendingIntent.getActivity(
                this,
                200,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                        PendingIntent.FLAG_IMMUTABLE
            )

        val notification = NotificationCompat
            .Builder(
                this,
                CHANNEL_ID
            )
            .setContentTitle(
                "Location sharing active"
            )
            .setContentText(
                "Your location is being shared"
            )
            .setSmallIcon(
                android.R.drawable.ic_menu_mylocation
            )
            .setOngoing(true)
            .setShowWhen(true)
            .setWhen(System.currentTimeMillis())
            .setUsesChronometer(true)
            .setContentIntent(contentPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setLocalOnly(true)
            .setAutoCancel(false)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "STOP",
                stopPendingIntent
            )
            .build()

        notification.flags = notification.flags or
                Notification.FLAG_ONGOING_EVENT or
                Notification.FLAG_NO_CLEAR or
                Notification.FLAG_FOREGROUND_SERVICE

        return notification
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy() — service being destroyed, cleaning up")

        handler.removeCallbacks(locationRunnable)
        try {
            fusedLocationClient.removeLocationUpdates(
                locationCallback
            )
        } catch (e: Exception) {
            Log.w(TAG, "onDestroy() — error removing location updates", e)
        }

        super.onDestroy()
    }

    override fun onBind(
        intent: Intent?
    ): IBinder? {
        Log.d(TAG, "onBind() — not a bound service, returning null")
        return null
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "onTaskRemoved() — app removed from recent apps, service continues as foreground")
    }
}