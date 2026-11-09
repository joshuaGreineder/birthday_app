package com.greinederlabs.happaroo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import java.time.LocalDate

/** "Upcoming" widget: a dated list of the next events. Shows as many rows as fit (2 to 6). */
class UpcomingWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { render(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        render(context, manager, id)
    }

    companion object {
        private const val MAX_ROWS = 6

        private val rowIds = intArrayOf(R.id.up_row0, R.id.up_row1, R.id.up_row2, R.id.up_row3, R.id.up_row4, R.id.up_row5)
        private val dateIds = intArrayOf(R.id.up_date0, R.id.up_date1, R.id.up_date2, R.id.up_date3, R.id.up_date4, R.id.up_date5)
        private val weekdayIds = intArrayOf(R.id.up_wd0, R.id.up_wd1, R.id.up_wd2, R.id.up_wd3, R.id.up_wd4, R.id.up_wd5)
        private val dayIds = intArrayOf(R.id.up_day0, R.id.up_day1, R.id.up_day2, R.id.up_day3, R.id.up_day4, R.id.up_day5)
        private val nameIds = intArrayOf(R.id.up_name0, R.id.up_name1, R.id.up_name2, R.id.up_name3, R.id.up_name4, R.id.up_name5)
        private val detailIds = intArrayOf(R.id.up_detail0, R.id.up_detail1, R.id.up_detail2, R.id.up_detail3, R.id.up_detail4, R.id.up_detail5)
        private val whenIds = intArrayOf(R.id.up_when0, R.id.up_when1, R.id.up_when2, R.id.up_when3, R.id.up_when4, R.id.up_when5)

        /** Rows that fit the widget's current height (header ~40dp, each row ~50dp). */
        private fun rowsThatFit(manager: AppWidgetManager, id: Int): Int {
            val options = manager.getAppWidgetOptions(id)
            val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
                .takeIf { it > 0 } ?: options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            if (height <= 0) return 4
            return ((height - 44) / 50).coerceIn(2, MAX_ROWS)
        }

        fun render(context: Context, manager: AppWidgetManager, id: Int) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_upcoming)
                views.setOnClickPendingIntent(R.id.widget_root, WidgetData.openAppIntent(context))

                val today = LocalDate.now()
                views.setTextViewText(
                    R.id.up_today,
                    "${WidgetData.weekdayShort(today)}, ${WidgetData.monthShort(today)} ${today.dayOfMonth}",
                )

                val events = WidgetData.upcoming(WidgetData.load(context), today)
                val shown = events.take(rowsThatFit(manager, id))
                views.setViewVisibility(R.id.up_empty, if (events.isEmpty()) View.VISIBLE else View.GONE)

                val p = WidgetPalette.resolve(context)
                val text = p.text
                val sub = p.sub
                val accent = p.accent
                val onAccent = p.onAccent
                val bday = p.bday
                val anniv = p.anniv
                views.setInt(R.id.widget_root, "setBackgroundResource", p.background)
                views.setTextColor(R.id.up_title, text)
                views.setTextColor(R.id.up_today, sub)
                views.setTextColor(R.id.up_empty, sub)

                for (i in 0 until MAX_ROWS) {
                    if (i >= shown.size) {
                        views.setViewVisibility(rowIds[i], View.GONE)
                        continue
                    }
                    val u = shown[i]
                    views.setViewVisibility(rowIds[i], View.VISIBLE)
                    views.setInt(
                        dateIds[i], "setBackgroundResource",
                        if (u.item.birthday) p.dateBday else p.dateAnniv,
                    )
                    views.setTextViewText(weekdayIds[i], WidgetData.weekdayShort(u.date).uppercase())
                    views.setTextColor(weekdayIds[i], if (u.item.birthday) bday else anniv)
                    views.setTextViewText(dayIds[i], u.date.dayOfMonth.toString())
                    views.setTextColor(dayIds[i], text)
                    views.setTextViewText(nameIds[i], u.item.name)
                    views.setTextColor(nameIds[i], text)
                    views.setTextViewText(detailIds[i], WidgetData.detail(u))
                    views.setTextColor(detailIds[i], sub)

                    views.setTextViewText(whenIds[i], WidgetData.countdown(u.days))
                    when {
                        u.days == 0L -> {
                            views.setInt(whenIds[i], "setBackgroundResource", p.pillToday)
                            views.setTextColor(whenIds[i], onAccent)
                        }
                        u.days <= 7L -> {
                            views.setInt(whenIds[i], "setBackgroundResource", p.pillSoon)
                            views.setTextColor(whenIds[i], accent)
                        }
                        else -> {
                            views.setInt(whenIds[i], "setBackgroundResource", 0)
                            views.setTextColor(whenIds[i], sub)
                        }
                    }
                }
                manager.updateAppWidget(id, views)
            } catch (e: Exception) {
                android.util.Log.e("HapparooWidget", "Upcoming widget $id failed: ${e.message}", e)
            }
        }
    }
}
