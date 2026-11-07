package com.greinederlabs.happaroo

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val widgetChannel = "com.greinederlabs.happaroo/widget"
    private val timezoneChannel = "com.greinederlabs.happaroo/timezone"
    private val platformChannel = "com.greinederlabs.happaroo/platform"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TimezoneChangeReceiver.attach(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, timezoneChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLocalTimezone" -> {
                        result.success(java.util.TimeZone.getDefault().id)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetChannel)
            .setMethodCallHandler { call, result ->
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
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, platformChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "url is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        TimezoneChangeReceiver.detach()
        super.onDestroy()
    }

    private fun setWidgetData(data: Map<*, *>) {
        val prefs = getSharedPreferences("widget_data", MODE_PRIVATE)
        val editor = prefs.edit()

        editor.putBoolean("hasNextEvent", data["hasNextEvent"] as? Boolean ?: false)
        editor.putString("nextEventName", data["nextEventName"] as? String ?: "")
        editor.putString("nextEventAgeText", data["nextEventAgeText"] as? String ?: "")
        editor.putInt("nextEventDaysUntil", (data["nextEventDaysUntil"] as? Number)?.toInt() ?: 0)
        editor.putString("nextEventDate", data["nextEventDate"] as? String ?: "")

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
                    editor.remove("event${i}_name")
                    editor.remove("event${i}_ageText")
                    editor.remove("event${i}_daysUntil")
                    editor.remove("event${i}_date")
                }
            }
        }

        editor.commit()
    }

    private fun updateAllWidgets() {
        val appWidgetManager = android.appwidget.AppWidgetManager.getInstance(this)
        val singleEventComponent = ComponentName(this, SingleEventWidgetProvider::class.java)
        val singleEventIds = appWidgetManager.getAppWidgetIds(singleEventComponent)
        if (singleEventIds.isNotEmpty()) {
            for (widgetId in singleEventIds) {
                EventWidgetProvider.updateAppWidget(this, appWidgetManager, widgetId)
            }
        }
    }
}
