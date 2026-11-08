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
                                .putString(WidgetPalette.KEY_THEME, call.argument<String>("theme") ?: "system")
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
                    "getAppIcon" -> result.success(currentAppIcon())
                    "setAppIcon" -> {
                        val name = call.argument<String>("name")
                        if (name == null || name !in appIcons) {
                            result.error("INVALID_ARGUMENT", "Unknown icon: $name", null)
                        } else {
                            setAppIcon(name)
                            result.success(true)
                        }
                    }
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

    /** Launcher aliases in AndroidManifest.xml, keyed by the name the app uses. */
    private val appIcons = mapOf(
        "calendar" to ".LauncherCalendar",
        "classic" to ".LauncherClassic",
        "light" to ".LauncherLight",
    )

    private fun aliasComponent(alias: String) =
        android.content.ComponentName(packageName, packageName + alias)

    private fun currentAppIcon(): String {
        for ((name, alias) in appIcons) {
            val state = packageManager.getComponentEnabledSetting(aliasComponent(alias))
            val enabled = when (state) {
                android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> name == "calendar"
                else -> false
            }
            if (enabled) return name
        }
        return "calendar"
    }

    /** Turns on the chosen launcher alias first, then the others off, so there is always one icon. */
    private fun setAppIcon(name: String) {
        val pm = packageManager
        pm.setComponentEnabledSetting(
            aliasComponent(appIcons.getValue(name)),
            android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            android.content.pm.PackageManager.DONT_KILL_APP,
        )
        for ((other, alias) in appIcons) {
            if (other == name) continue
            pm.setComponentEnabledSetting(
                aliasComponent(alias),
                android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                android.content.pm.PackageManager.DONT_KILL_APP,
            )
        }
    }
}
