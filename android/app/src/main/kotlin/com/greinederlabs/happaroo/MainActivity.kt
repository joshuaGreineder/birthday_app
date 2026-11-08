package com.greinederlabs.happaroo

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
                        WidgetData.updateAll(this)
                        result.success(true)
                    }
                    "setWidgetEvents" -> {
                        val json = call.argument<String>("json")
                        if (json != null) {
                            getSharedPreferences(WidgetData.PREFS, MODE_PRIVATE).edit()
                                .putString(WidgetData.KEY_EVENTS, json)
                                .commit()
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "json is required", null)
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
}
