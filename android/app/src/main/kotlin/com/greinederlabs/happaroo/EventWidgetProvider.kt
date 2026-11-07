package com.greinederlabs.happaroo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews

class EventWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Enter relevant functionality for when the first widget is created
    }

    override fun onDisabled(context: Context) {
        // Enter relevant functionality for when the last widget is disabled
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                // Read from widget_data SharedPreferences (set by MainActivity via method channel)
                val widgetDataPrefs = context.getSharedPreferences("widget_data", Context.MODE_PRIVATE)
                
                android.util.Log.d("EventWidget", "Creating RemoteViews for single event widget, widgetId: $appWidgetId")
                val views = RemoteViews(context.packageName, R.layout.widget_single_event)
            
                // Get widget data from widget_data SharedPreferences
                val hasNextEvent = widgetDataPrefs.getBoolean("hasNextEvent", false)
                
                android.util.Log.d("EventWidget", "hasNextEvent: $hasNextEvent")
                android.util.Log.d("EventWidget", "All widget_data keys: ${widgetDataPrefs.all.keys.joinToString(", ")}")
                android.util.Log.d("EventWidget", "All widget_data values: ${widgetDataPrefs.all}")
                
                if (hasNextEvent) {
                    // Read from widget_data SharedPreferences
                    val eventName = widgetDataPrefs.getString("nextEventName", "") ?: ""
                    val eventAgeText = widgetDataPrefs.getString("nextEventAgeText", "") ?: ""
                    val eventDaysUntil = widgetDataPrefs.getInt("nextEventDaysUntil", -1)
                    val eventDate = widgetDataPrefs.getString("nextEventDate", "") ?: ""
                    
                    android.util.Log.d("EventWidget", "Event data - Name: '$eventName', Days: $eventDaysUntil, Date: '$eventDate'")
                    
                    // Update single event widget
                    views.setTextViewText(R.id.widget_event_name, eventName)
                    views.setTextViewText(R.id.widget_event_info, eventAgeText)
                    views.setTextViewText(R.id.widget_event_date, eventDate)
                    
                    if (eventDaysUntil == 0) {
                        views.setTextViewText(R.id.widget_days_text, "Today!")
                    } else if (eventDaysUntil == 1) {
                        views.setTextViewText(R.id.widget_days_text, "Tomorrow")
                    } else {
                        views.setTextViewText(R.id.widget_days_text, "$eventDaysUntil days")
                    }
                } else {
                    // No events - show empty state
                    views.setTextViewText(R.id.widget_event_name, "No upcoming events")
                    views.setTextViewText(R.id.widget_event_info, "Add events to see them here")
                    views.setTextViewText(R.id.widget_days_text, "")
                }
            
                android.util.Log.d("EventWidget", "Calling updateAppWidget for widgetId: $appWidgetId")
                appWidgetManager.updateAppWidget(appWidgetId, views)
                android.util.Log.d("EventWidget", "Widget update completed successfully for widgetId: $appWidgetId")
            } catch (e: Exception) {
                android.util.Log.e("EventWidget", "Error updating widget $appWidgetId: ${e.message}", e)
            }
        }
    }
}
