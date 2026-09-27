package com.example.emergence

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class StopLocationReceiver : BroadcastReceiver() {

    override fun onReceive(
        context: Context,
        intent: Intent?
    ) {
        LocationForegroundService.stop(context)
    }
}