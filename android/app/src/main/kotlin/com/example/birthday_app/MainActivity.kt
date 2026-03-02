package com.example.birthday_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.birthday_app/widget"
    private val NOTIFICATION_CHANNEL = "com.example.birthday_app/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Timezone channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.birthday_app/timezone")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLocalTimezone" -> {
                        val timezone = java.util.TimeZone.getDefault().id
                        result.success(timezone)
                    }
                    else -> result.notImplemented()
                }
            }
        
        // Widget channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgets" -> {
                    updateAllWidgets()
                    result.success(true)
                }
                "setWidgetData" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        setWidgetData(args)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Arguments cannot be null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Notification channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canScheduleExactAlarms" -> {
                    result.success(canScheduleExactAlarms())
                }
                "openExactAlarmSettings" -> {
                    openExactAlarmSettings()
                    result.success(true)
                }
                "isBatteryOptimizationDisabled" -> {
                    result.success(isBatteryOptimizationDisabled())
                }
                "requestDisableBatteryOptimization" -> {
                    requestDisableBatteryOptimization()
                    result.success(null)
                }
                "scheduleNotificationAlarm" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        val notificationId = (args["notificationId"] as? Number)?.toInt() ?: 0
                        val title = args["title"] as? String ?: ""
                        val body = args["body"] as? String ?: ""
                        val channelId = args["channelId"] as? String ?: "event_reminder"
                        val triggerTime = (args["triggerTime"] as? Number)?.toLong() ?: 0L
                        scheduleNotificationAlarm(notificationId, title, body, channelId, triggerTime)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Arguments cannot be null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(android.app.AlarmManager::class.java)
            alarmManager.canScheduleExactAlarms()
        } else {
            true // On Android 11 and below, exact alarms are always allowed
        }
    }
    
    private fun openExactAlarmSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = android.net.Uri.parse("package:$packageName")
            }
            startActivity(intent)
        }
    }
    
    private fun isBatteryOptimizationDisabled(): Boolean {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }
    
    private fun requestDisableBatteryOptimization() {
        val intent = Intent().apply {
            action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
            data = Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }
    
    private fun scheduleNotificationAlarm(
        notificationId: Int,
        title: String,
        body: String,
        channelId: String,
        triggerTime: Long
    ) {
        Log.d("MainActivity", "📅 Scheduling notification alarm: ID=$notificationId, Time=${java.util.Date(triggerTime)}")
        
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        // Create intent for the receiver
        val intent = Intent(this, NotificationReceiver::class.java).apply {
            putExtra("notification_id", notificationId)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("channel_id", channelId)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        pendingIntent
                    )
                    Log.d("MainActivity", "✓ Scheduled exact notification alarm (Android 12+)")
                } else {
                    Log.e("MainActivity", "❌ Cannot schedule exact alarms - permission not granted")
                }
            } else {
                // Android 11 and below
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
                Log.d("MainActivity", "✓ Scheduled exact notification alarm (Android 11 and below)")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Error scheduling notification alarm: ${e.message}")
        }
    }
    
    private fun cancelNotificationAlarm(notificationId: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, NotificationReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        Log.d("MainActivity", "Cancelled alarm for notification ID: $notificationId")
    }
    
    private fun cancelAllNotificationAlarms() {
        // Cancel alarms for common notification ID ranges
        // Event notifications use IDs 100-999
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (id in 100..999) {
            try {
                val intent = Intent(this, NotificationReceiver::class.java)
                val pendingIntent = PendingIntent.getBroadcast(
                    this,
                    id,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pendingIntent)
            } catch (e: Exception) {
                // Ignore errors for non-existent alarms
            }
        }
        // Cancel test notification (ID 9998)
        cancelNotificationAlarm(9998)
        Log.d("MainActivity", "Cancelled all notification alarms")
    }
    
    private fun setWidgetData(data: Map<*, *>) {
        val prefs = getSharedPreferences("widget_data", MODE_PRIVATE)
        val editor = prefs.edit()
        
        // Single event data
        editor.putBoolean("hasNextEvent", data["hasNextEvent"] as? Boolean ?: false)
        editor.putString("nextEventName", data["nextEventName"] as? String ?: "")
        editor.putString("nextEventAgeText", data["nextEventAgeText"] as? String ?: "")
        editor.putInt("nextEventDaysUntil", (data["nextEventDaysUntil"] as? Number)?.toInt() ?: 0)
        editor.putString("nextEventDate", data["nextEventDate"] as? String ?: "")
        
        // Three events data
        val eventCount = (data["eventCount"] as? Number)?.toInt() ?: 0
        editor.putInt("eventCount", eventCount)
        
        val events = data["events"] as? List<*>
        if (events != null) {
            for (i in 0 until 3) {
                if (i < events.size) {
                    val event = events[i] as? Map<*, *>
                    if (event != null) {
                        editor.putString("event${i}_name", event["name"] as? String ?: "")
                        editor.putString("event${i}_ageText", event["ageText"] as? String ?: "")
                        editor.putInt("event${i}_daysUntil", (event["daysUntil"] as? Number)?.toInt() ?: -1)
                        editor.putString("event${i}_date", event["date"] as? String ?: "")
                    }
                } else {
                    // Clear unused slots
                    editor.remove("event${i}_name")
                    editor.remove("event${i}_ageText")
                    editor.remove("event${i}_daysUntil")
                    editor.remove("event${i}_date")
                }
            }
        }
        
        editor.commit() // Use commit() to ensure data is saved synchronously before widget update
        android.util.Log.d("MainActivity", "Widget data saved to widget_data SharedPreferences")
    }

    private fun updateAllWidgets() {
        val appWidgetManager = AppWidgetManager.getInstance(this)
        
        // Update single event widgets
        val singleEventComponent = ComponentName(this, SingleEventWidgetProvider::class.java)
        val singleEventIds = appWidgetManager.getAppWidgetIds(singleEventComponent)
        if (singleEventIds.isNotEmpty()) {
            for (widgetId in singleEventIds) {
                EventWidgetProvider.updateAppWidget(this, appWidgetManager, widgetId)
            }
        }
    }
}
