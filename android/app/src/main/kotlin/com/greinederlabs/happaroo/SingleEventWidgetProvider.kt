package com.greinederlabs.happaroo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews

/**
 * "Next up" widget (2x2): the next event, how far away it is, and what it is.
 * The class keeps its original name so widgets people already placed keep working.
 */
class SingleEventWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { render(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        render(context, manager, id)
    }

    companion object {
        fun render(context: Context, manager: AppWidgetManager, id: Int) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_next_up)
                views.setOnClickPendingIntent(R.id.widget_root, WidgetData.openAppIntent(context))

                val upcoming = WidgetData.upcoming(WidgetData.load(context))
                if (upcoming.isEmpty()) {
                    views.setTextViewText(R.id.next_when, "HAPPAROO")
                    views.setTextViewText(R.id.next_name, "No events yet")
                    views.setTextViewText(R.id.next_detail, "Add a birthday in the app")
                    views.setTextViewText(R.id.next_date, "")
                    views.setViewVisibility(R.id.next_more, View.GONE)
                } else {
                    val first = upcoming.first()
                    val sameDay = upcoming.count { it.date == first.date }
                    val whenText = when (first.days) {
                        0L -> "TODAY"
                        1L -> "TOMORROW"
                        else -> "IN ${first.days} DAYS"
                    }
                    views.setTextViewText(R.id.next_when, whenText)
                    views.setTextViewText(R.id.next_name, first.item.name)
                    views.setTextViewText(R.id.next_detail, WidgetData.detail(first))
                    views.setTextViewText(
                        R.id.next_date,
                        "${WidgetData.weekdayShort(first.date)}, ${WidgetData.monthShort(first.date)} ${first.date.dayOfMonth}",
                    )
                    if (sameDay > 1) {
                        views.setTextViewText(R.id.next_more, "+${sameDay - 1} more that day")
                        views.setViewVisibility(R.id.next_more, View.VISIBLE)
                    } else {
                        views.setViewVisibility(R.id.next_more, View.GONE)
                    }
                }
                manager.updateAppWidget(id, views)
            } catch (e: Exception) {
                android.util.Log.e("HapparooWidget", "Next up widget $id failed: ${e.message}", e)
            }
        }
    }
}
