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
        private val nameIds = intArrayOf(R.id.cal_n0, R.id.cal_n1, R.id.cal_n2, R.id.cal_n3, R.id.cal_n4, R.id.cal_n5, R.id.cal_n6, R.id.cal_n7, R.id.cal_n8, R.id.cal_n9, R.id.cal_n10, R.id.cal_n11, R.id.cal_n12, R.id.cal_n13, R.id.cal_n14, R.id.cal_n15, R.id.cal_n16, R.id.cal_n17, R.id.cal_n18, R.id.cal_n19, R.id.cal_n20, R.id.cal_n21, R.id.cal_n22, R.id.cal_n23, R.id.cal_n24, R.id.cal_n25, R.id.cal_n26, R.id.cal_n27, R.id.cal_n28, R.id.cal_n29, R.id.cal_n30, R.id.cal_n31, R.id.cal_n32, R.id.cal_n33, R.id.cal_n34, R.id.cal_n35, R.id.cal_n36, R.id.cal_n37, R.id.cal_n38, R.id.cal_n39, R.id.cal_n40, R.id.cal_n41)
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

        /** "Rebekah and Joshua" -> "Rebekah", "Mom and Dad Gann" -> "Mom". */
        private fun firstName(name: String): String = name.trim().substringBefore(' ').ifEmpty { name }

        fun render(context: Context, manager: AppWidgetManager, id: Int) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_calendar)
                val prefs = context.getSharedPreferences(WidgetData.PREFS, Context.MODE_PRIVATE)
                val today = LocalDate.now()
                val month = YearMonth.from(today).plusMonths(prefs.getInt(offsetKey(id), 0).toLong())
                val locale = Locale.getDefault()
                val p = WidgetPalette.resolve(context)
                views.setInt(R.id.widget_root, "setBackgroundResource", p.background)
                views.setTextColor(R.id.cal_title, p.text)
                views.setTextColor(R.id.cal_prev, p.sub)
                views.setTextColor(R.id.cal_next, p.sub)
                views.setTextColor(R.id.cal_footer, p.sub)
                views.setInt(R.id.cal_rule, "setBackgroundColor", p.divider)
                weekdayIds.forEach { views.setTextColor(it, p.sub) }

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
                val byDay = HashMap<Int, MutableList<WidgetData.Item>>()
                for (item in items) {
                    val date = WidgetData.observedIn(item, month.year) ?: continue
                    if (date.monthValue != month.monthValue) continue
                    if (item.birthday) birthdays.add(date.dayOfMonth) else anniversaries.add(date.dayOfMonth)
                    byDay.getOrPut(date.dayOfMonth) { ArrayList() }.add(item)
                }

                val text = p.text
                val sub = p.sub
                val accent = p.accent
                val onAccent = p.onAccent
                val bday = p.bday
                val anniv = p.anniv
                val first = month.atDay(1)
                val lead = ((first.dayOfWeek.value - firstDay.value) + 7) % 7
                val weeks = (lead + month.lengthOfMonth() + 6) / 7

                for (i in 0 until 42) {
                    val dayNum = i - lead + 1
                    val cell = cellIds[i]
                    if (dayNum < 1 || dayNum > month.lengthOfMonth()) {
                        views.setTextViewText(cell, "")
                        views.setTextViewText(nameIds[i], "")
                        views.setInt(cell, "setBackgroundResource", 0)
                        continue
                    }
                    val isToday = month.year == today.year && month.monthValue == today.monthValue && dayNum == today.dayOfMonth
                    val b = dayNum in birthdays
                    val a = dayNum in anniversaries
                    views.setTextViewText(cell, dayNum.toString())
                    val background = when {
                        isToday && (a || b) -> p.dayTodayEvent
                        isToday -> p.dayToday
                        a && b -> p.dayBoth
                        b -> p.dayBday
                        a -> p.dayAnniv
                        else -> 0
                    }
                    views.setInt(cell, "setBackgroundResource", background)
                    val past = month.year == today.year && month.monthValue == today.monthValue && dayNum < today.dayOfMonth
                    val color = when {
                        isToday && (a || b) -> onAccent
                        isToday -> accent
                        a && b -> accent
                        b -> bday
                        a -> anniv
                        past -> sub
                        else -> text
                    }
                    views.setTextColor(cell, color)

                    // First name under the date; "+1" when several share the day.
                    val people = byDay[dayNum].orEmpty().sortedBy { it.name.lowercase(locale) }
                    val label = when (people.size) {
                        0 -> ""
                        1 -> firstName(people[0].name)
                        else -> "${firstName(people[0].name)} +${people.size - 1}"
                    }
                    views.setTextViewText(nameIds[i], label)
                    views.setTextColor(
                        nameIds[i],
                        when {
                            past -> sub
                            a && b -> accent
                            b -> bday
                            else -> anniv
                        },
                    )
                }
                for (r in 0 until 6) {
                    views.setViewVisibility(weekRowIds[r], if (r < weeks) View.VISIBLE else View.GONE)
                }

                // Footer: what's next (this month) or a count (other months).
                val isThisMonth = month.year == today.year && month.monthValue == today.monthValue
                val footer = if (isThisMonth) {
                    WidgetData.upcoming(items, today).firstOrNull()?.let { u ->
                        val whenText = when (u.days) {
                            0L -> "today"
                            1L -> "tomorrow"
                            else -> "in ${u.days} days"
                        }
                        "Next: ${u.item.name}, ${WidgetData.weekdayShort(u.date)} ${u.date.dayOfMonth} · $whenText"
                    } ?: "No events yet"
                } else {
                    val count = byDay.values.sumOf { it.size }
                    when (count) {
                        0 -> "Nothing in ${month.month.getDisplayName(TextStyle.FULL, locale)}"
                        1 -> "1 event"
                        else -> "$count events"
                    }
                }
                views.setTextViewText(R.id.cal_footer, footer)

                manager.updateAppWidget(id, views)
            } catch (e: Exception) {
                android.util.Log.e("HapparooWidget", "Calendar widget $id failed: ${e.message}", e)
            }
        }
    }
}