package com.example.emergence

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootCompletedReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootCompletedReceiver"
    }

    override fun onReceive(
        context: Context,
        intent: Intent?
    ) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d(TAG, "onReceive() — BOOT_COMPLETED received")

            val preferences = context.getSharedPreferences(
                "device_preferences",
                Context.MODE_PRIVATE
            )

            val uid = preferences.getString("device_user_id", null)

            if (uid != null) {
                Log.d(TAG, "onReceive() — device_user_id found, restarting foreground service")
                try {
                    LocationForegroundService.start(context)
                } catch (e: Exception) {
                    Log.e(TAG, "onReceive() — failed to start service", e)
                }
            } else {
                Log.d(TAG, "onReceive() — no device_user_id found, not starting service")
            }
        }
    }
}
