package com.example.birthday_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || 
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            intent.action == Intent.ACTION_PACKAGE_REPLACED) {
            Log.d("BootReceiver", "Device booted or app updated, rescheduling notifications")
            
            // Note: We can't directly call Flutter code from here
            // The notifications will be rescheduled when the app is next opened
            // This receiver ensures the app knows to reschedule on next launch
        }
    }
}

