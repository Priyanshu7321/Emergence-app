package com.example.emergence

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.atan2

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL =
            "com.example.emergence/device"
        private const val COMPASS_CHANNEL =
            "com.example.emergence/compass"
        private const val TAG = "MainActivity"
        private const val NOTIF_PERM_REQ_CODE = 5001
    }

    private var notificationPermissionResult:
            MethodChannel.Result? = null

    private var sensorManager: SensorManager? = null
    private var compassStreamHandler: CompassStreamHandler? = null

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "saveDeviceId" -> {

                    val deviceId =
                        call.argument<String>("deviceId")

                    if (deviceId == null) {
                        result.error(
                            "INVALID_ID",
                            "Device ID is null",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    getSharedPreferences(
                        "device_preferences",
                        Context.MODE_PRIVATE
                    )
                        .edit()
                        .putString(
                            "device_user_id",
                            deviceId
                        )
                        .apply()

                    result.success(true)
                }

                "saveUserName" -> {

                    val userName =
                        call.argument<String>("userName")

                    getSharedPreferences(
                        "device_preferences",
                        Context.MODE_PRIVATE
                    )
                        .edit()
                        .putString(
                            "user_name",
                            userName
                        )
                        .apply()

                    result.success(true)
                }

                "startLocationService" -> {
                    android.util.Log.d(
                        "MainActivity",
                        "startLocationService received"
                    )
                    LocationForegroundService.start(
                        this
                    )

                    result.success(true)
                }

                "stopLocationService" -> {

                    LocationForegroundService.stop(
                        this
                    )

                    result.success(true)
                }

                "ensureNotificationPermission" -> {
                    ensureNotificationPermission(result)
                }

                "openAppSettings" -> {
                    openAppSettingsScreen()
                    result.success(true)
                }

                "openLocationSettings" -> {
                    openLocationSettingsScreen()
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager

        compassStreamHandler = CompassStreamHandler(sensorManager!!)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            COMPASS_CHANNEL
        ).setStreamHandler(compassStreamHandler)
    }

    override fun onDestroy() {
        compassStreamHandler?.cancel()
        super.onDestroy()
    }

    private class CompassStreamHandler(
        private val sensorManager: SensorManager
    ) : EventChannel.StreamHandler, SensorEventListener {

        private var eventSink: EventChannel.EventSink? = null

        private val rotationMatrix = FloatArray(9)
        private val orientationAngles = FloatArray(3)
        private val lastAccelerometer = FloatArray(3)
        private val lastMagnetometer = FloatArray(3)
        private var hasAccelerometer = false
        private var hasMagnetometer = false

        private var accelerometerSensor: Sensor? = null
        private var magnetometerSensor: Sensor? = null
        private var rotationVectorSensor: Sensor? = null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events

            rotationVectorSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            if (rotationVectorSensor != null) {
                sensorManager.registerListener(
                    this,
                    rotationVectorSensor,
                    SensorManager.SENSOR_DELAY_UI
                )
            } else {
                accelerometerSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                magnetometerSensor = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)

                if (accelerometerSensor != null) {
                    sensorManager.registerListener(
                        this,
                        accelerometerSensor,
                        SensorManager.SENSOR_DELAY_UI
                    )
                }
                if (magnetometerSensor != null) {
                    sensorManager.registerListener(
                        this,
                        magnetometerSensor,
                        SensorManager.SENSOR_DELAY_UI
                    )
                }
            }
        }

        override fun onCancel(arguments: Any?) {
            cancel()
        }

        fun cancel() {
            try {
                sensorManager.unregisterListener(this)
            } catch (_: Exception) {}
            eventSink = null
            hasAccelerometer = false
            hasMagnetometer = false
        }

        override fun onSensorChanged(event: SensorEvent?) {
            if (event == null || eventSink == null) return

            try {
                var azimuthDegrees: Double? = null

                if (event.sensor.type == Sensor.TYPE_ROTATION_VECTOR) {
                    SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
                    SensorManager.getOrientation(rotationMatrix, orientationAngles)
                    val azimuth = orientationAngles[0]
                    azimuthDegrees = Math.toDegrees(azimuth.toDouble()).let {
                        if (it < 0) it + 360.0 else it
                    }
                } else if (event.sensor.type == Sensor.TYPE_ACCELEROMETER) {
                    System.arraycopy(event.values, 0, lastAccelerometer, 0, 3)
                    hasAccelerometer = true
                } else if (event.sensor.type == Sensor.TYPE_MAGNETIC_FIELD) {
                    System.arraycopy(event.values, 0, lastMagnetometer, 0, 3)
                    hasMagnetometer = true
                }

                if (azimuthDegrees == null && hasAccelerometer && hasMagnetometer) {
                    val success = SensorManager.getRotationMatrix(
                        rotationMatrix,
                        null,
                        lastAccelerometer,
                        lastMagnetometer
                    )
                    if (success) {
                        SensorManager.getOrientation(rotationMatrix, orientationAngles)
                        val azimuth = orientationAngles[0]
                        azimuthDegrees = Math.toDegrees(azimuth.toDouble()).let {
                            if (it < 0) it + 360.0 else it
                        }
                    }
                }

                if (azimuthDegrees != null) {
                    eventSink?.success(azimuthDegrees)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Compass sensor error", e)
            }
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    }

    private fun ensureNotificationPermission(
        result: MethodChannel.Result
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }

        val hasPermission =
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED

        if (hasPermission) {
            result.success(true)
            return
        }

        notificationPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIF_PERM_REQ_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults
        )

        if (requestCode == NOTIF_PERM_REQ_CODE) {
            val result = notificationPermissionResult
            notificationPermissionResult = null
            val granted =
                grantResults.isNotEmpty() &&
                        grantResults[0] == PackageManager.PERMISSION_GRANTED
            try {
                result?.success(granted)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to deliver notification permission result", e)
            }
        }
    }

    private fun openAppSettingsScreen() {
        try {
            val intent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", packageName, null)
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open app settings", e)
            val fallback = Intent(
                Settings.ACTION_SETTINGS
            )
            fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(fallback)
        }
    }

    private fun openLocationSettingsScreen() {
        try {
            val intent = Intent(
                Settings.ACTION_LOCATION_SOURCE_SETTINGS
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open location settings", e)
            openAppSettingsScreen()
        }
    }
}
