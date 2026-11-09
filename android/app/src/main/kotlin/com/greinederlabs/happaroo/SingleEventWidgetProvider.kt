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
                val p = WidgetPalette.resolve(context)
                views.setInt(R.id.widget_root, "setBackgroundResource", p.background)
                views.setTextColor(R.id.next_when, p.accent)
                views.setTextColor(R.id.next_name, p.text)
                views.setTextColor(R.id.next_detail, p.sub)
                views.setTextColor(R.id.next_more, p.sub)
                views.setInt(R.id.next_rule, "setBackgroundColor", p.divider)

                val upcoming = WidgetData.upcoming(WidgetData.load(context))
                if (upcoming.isEmpty()) {
                    views.setImageViewResource(R.id.next_icon, R.drawable.ic_widget_cake)
                    views.setInt(R.id.next_icon, "setColorFilter", p.bday)
                    views.setTextViewText(R.id.next_when, "HAPPAROO")
                    views.setTextViewText(R.id.next_name, "No events yet")
                    views.setTextViewText(R.id.next_detail, "Add a birthday in the app")
                    views.setViewVisibility(R.id.next_rule, View.GONE)
                    views.setViewVisibility(R.id.next_more, View.GONE)
                } else {
                    val first = upcoming.first()
                    val sameDay = upcoming.count { it.date == first.date }
                    views.setImageViewResource(
                        R.id.next_icon,
                        if (first.item.birthday) R.drawable.ic_widget_cake else R.drawable.ic_widget_heart,
                    )
                    views.setInt(R.id.next_icon, "setColorFilter", if (first.item.birthday) p.bday else p.anniv)
                    views.setTextViewText(
                        R.id.next_when,
                        when (first.days) {
                            0L -> "TODAY"
                            1L -> "TOMORROW"
                            else -> "IN ${first.days} DAYS"
                        },
                    )
                    views.setTextViewText(R.id.next_name, first.item.name)
                    val date = "${WidgetData.weekdayShort(first.date)} ${first.date.dayOfMonth}"
                    views.setTextViewText(R.id.next_detail, "${WidgetData.detail(first)} · $date")

                    val more = when {
                        sameDay > 1 -> "+${sameDay - 1} more that day"
                        upcoming.size > 1 -> {
                            val second = upcoming[1]
                            "Then ${second.item.name} · ${WidgetData.weekdayShort(second.date)} ${second.date.dayOfMonth}"
                        }
                        else -> null
                    }
                    val visible = if (more != null) View.VISIBLE else View.GONE
                    views.setViewVisibility(R.id.next_rule, visible)
                    views.setViewVisibility(R.id.next_more, visible)
                    if (more != null) views.setTextViewText(R.id.next_more, more)
                }
                manager.updateAppWidget(id, views)
            } catch (e: Exception) {
                android.util.Log.e("HapparooWidget", "Next up widget $id failed: ${e.message}", e)
            }
        }
    }
}
