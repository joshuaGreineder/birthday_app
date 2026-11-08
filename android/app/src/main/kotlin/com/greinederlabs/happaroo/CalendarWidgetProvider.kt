package com.greinederlabs.happaroo

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.TextStyle
import java.time.temporal.WeekFields
import java.util.Locale

/**
 * Month calendar widget (4x4). Birthday days get an orange dot, anniversaries a
 * pink one, days with both a coral one; today is ringed. Arrows page through
 * months; tapping the month name jumps back to this month.
 */
class CalendarWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { render(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        render(context, manager, id)
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        val prefs = context.getSharedPreferences(WidgetData.PREFS, Context.MODE_PRIVATE).edit()
        ids.forEach { prefs.remove(offsetKey(it)) }
        prefs.apply()
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
        val prefs = context.getSharedPreferences(WidgetData.PREFS, Context.MODE_PRIVATE)
        val offset = prefs.getInt(offsetKey(id), 0)
        val next = when (intent.action) {
            ACTION_PREV -> offset - 1
            ACTION_NEXT -> offset + 1
            ACTION_TODAY -> 0
            else -> return
        }
        prefs.edit().putInt(offsetKey(id), next.coerceIn(-120, 120)).apply()
        render(context, AppWidgetManager.getInstance(context), id)
    }

    companion object {
        private const val ACTION_PREV = "com.greinederlabs.happaroo.CALENDAR_PREV"
        private const val ACTION_NEXT = "com.greinederlabs.happaroo.CALENDAR_NEXT"
        private const val ACTION_TODAY = "com.greinederlabs.happaroo.CALENDAR_TODAY"

        private fun offsetKey(id: Int) = "calendar_offset_$id"

        private val cellIds = intArrayOf(
            R.id.cal_c0, R.id.cal_c1, R.id.cal_c2, R.id.cal_c3, R.id.cal_c4, R.id.cal_c5, R.id.cal_c6,
            R.id.cal_c7, R.id.cal_c8, R.id.cal_c9, R.id.cal_c10, R.id.cal_c11, R.id.cal_c12, R.id.cal_c13,
            R.id.cal_c14, R.id.cal_c15, R.id.cal_c16, R.id.cal_c17, R.id.cal_c18, R.id.cal_c19, R.id.cal_c20,
            R.id.cal_c21, R.id.cal_c22, R.id.cal_c23, R.id.cal_c24, R.id.cal_c25, R.id.cal_c26, R.id.cal_c27,
            R.id.cal_c28, R.id.cal_c29, R.id.cal_c30, R.id.cal_c31, R.id.cal_c32, R.id.cal_c33, R.id.cal_c34,
            R.id.cal_c35, R.id.cal_c36, R.id.cal_c37, R.id.cal_c38, R.id.cal_c39, R.id.cal_c40, R.id.cal_c41,
        )
        private val weekRowIds = intArrayOf(R.id.cal_week0, R.id.cal_week1, R.id.cal_week2, R.id.cal_week3, R.id.cal_week4, R.id.cal_week5)
        private val weekdayIds = intArrayOf(R.id.cal_wd0, R.id.cal_wd1, R.id.cal_wd2, R.id.cal_wd3, R.id.cal_wd4, R.id.cal_wd5, R.id.cal_wd6)

        private fun actionIntent(context: Context, id: Int, action: String, code: Int): PendingIntent {
            val intent = Intent(context, CalendarWidgetProvider::class.java).apply {
                this.action = action
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            }
            return PendingIntent.getBroadcast(
                context, id * 10 + code, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        fun render(context: Context, manager: AppWidgetManager, id: Int) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_calendar)
                val prefs = context.getSharedPreferences(WidgetData.PREFS, Context.MODE_PRIVATE)
                val today = LocalDate.now()
                val month = YearMonth.from(today).plusMonths(prefs.getInt(offsetKey(id), 0).toLong())
                val locale = Locale.getDefault()

                views.setOnClickPendingIntent(R.id.cal_prev, actionIntent(context, id, ACTION_PREV, 1))
                views.setOnClickPendingIntent(R.id.cal_next, actionIntent(context, id, ACTION_NEXT, 2))
                views.setOnClickPendingIntent(R.id.cal_title, actionIntent(context, id, ACTION_TODAY, 3))
                views.setOnClickPendingIntent(R.id.cal_grid, WidgetData.openAppIntent(context))
                views.setOnClickPendingIntent(R.id.cal_footer, WidgetData.openAppIntent(context))

                val title = month.month.getDisplayName(TextStyle.FULL, locale) +
                    if (month.year != today.year) " ${month.year}" else ""
                views.setTextViewText(R.id.cal_title, title)

                // Weekday header in the user's locale order (Sunday first in the US).
                val firstDay: DayOfWeek = WeekFields.of(locale).firstDayOfWeek
                for (c in 0 until 7) {
                    val dow = firstDay.plus(c.toLong())
                    views.setTextViewText(weekdayIds[c], dow.getDisplayName(TextStyle.NARROW, locale))
                }

                // Which days this month have which kinds of event.
                val items = WidgetData.load(context)
                val birthdays = HashSet<Int>()
                val anniversaries = HashSet<Int>()
                val names = ArrayList<Pair<Int, String>>()
                for (item in items) {
                    val date = WidgetData.observedIn(item, month.year) ?: continue
                    if (date.monthValue != month.monthValue) continue
                    if (item.birthday) birthdays.add(date.dayOfMonth) else anniversaries.add(date.dayOfMonth)
                    names.add(date.dayOfMonth to item.name)
                }

                val text = WidgetData.color(context, R.color.widget_text)
                val onAccent = WidgetData.color(context, R.color.widget_on_accent)
                val first = month.atDay(1)
                val lead = ((first.dayOfWeek.value - firstDay.value) + 7) % 7
                val weeks = (lead + month.lengthOfMonth() + 6) / 7

                for (i in 0 until 42) {
                    val dayNum = i - lead + 1
                    val cell = cellIds[i]
                    if (dayNum < 1 || dayNum > month.lengthOfMonth()) {
                        views.setTextViewText(cell, "")
                        views.setInt(cell, "setBackgroundResource", 0)
                        continue
                    }
                    val isToday = month.year == today.year && month.monthValue == today.monthValue && dayNum == today.dayOfMonth
                    val b = dayNum in birthdays
                    val a = dayNum in anniversaries
                    views.setTextViewText(cell, dayNum.toString())
                    val background = when {
                        isToday && (a || b) -> R.drawable.widget_day_today_event
                        isToday -> R.drawable.widget_day_today
                        a && b -> R.drawable.widget_day_both
                        b -> R.drawable.widget_day_bday
                        a -> R.drawable.widget_day_anniv
                        else -> 0
                    }
                    views.setInt(cell, "setBackgroundResource", background)
                    views.setTextColor(cell, if (isToday && (a || b)) onAccent else text)
                }
                for (r in 0 until 6) {
                    views.setViewVisibility(weekRowIds[r], if (r < weeks) View.VISIBLE else View.GONE)
                }

                val footer = names.sortedBy { it.first }
                    .joinToString("  ·  ") { "${it.first} ${it.second.substringBefore(' ')}" }
                views.setTextViewText(R.id.cal_footer, if (footer.isEmpty()) "Nothing this month" else footer)

                manager.updateAppWidget(id, views)
            } catch (e: Exception) {
                android.util.Log.e("HapparooWidget", "Calendar widget $id failed: ${e.message}", e)
            }
        }
    }
}
