package com.greinederlabs.happaroo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.dexterous.flutterlocalnotifications.HapparooScheduleRestorer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

/**
 * Day-based reminders are stored by flutter_local_notifications as a local
 * date-time plus a time zone id. After a zone change, point that id at the
 * device zone and restore the alarms so the reminder stays on the same local
 * calendar day. The plugin's own boot receiver does not listen for this.
 */
class TimezoneChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_TIMEZONE_CHANGED && action != Intent.ACTION_TIME_CHANGED) {
            return
        }
        try {
            if (action == Intent.ACTION_TIMEZONE_CHANGED) {
                rewriteStoredTimezone(context, TimeZone.getDefault().id)
            }
            HapparooScheduleRestorer.reschedule(context)
            val messenger = engineMessenger
            if (messenger != null) {
                MethodChannel(messenger, "com.greinederlabs.happaroo/timezone")
                    .invokeMethod("timezoneChanged", TimeZone.getDefault().id)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Could not reschedule reminders after $action", e)
        }
    }

    private fun rewriteStoredTimezone(context: Context, zoneId: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val json = prefs.getString(PREFS, null) ?: return
        // Keep the plugin's Gson payload intact and only swap the zone id,
        // so the stored wall-clock date is interpreted in the new local zone.
        val updated = Regex("\"timeZoneName\"\\s*:\\s*\"([^\"\\\\]*)\"")
            .replace(json) { "\"timeZoneName\":\"$zoneId\"" }
        if (updated == json) {
            return
        }
        prefs.edit().putString(PREFS, updated).commit()
    }

    companion object {
        private const val TAG = "TimezoneChangeReceiver"
        private const val PREFS = "scheduled_notifications"
        @Volatile
        private var engineMessenger: io.flutter.plugin.common.BinaryMessenger? = null

        fun attach(engine: FlutterEngine) {
            engineMessenger = engine.dartExecutor.binaryMessenger
        }

        fun detach() {
            engineMessenger = null
        }
    }
}
