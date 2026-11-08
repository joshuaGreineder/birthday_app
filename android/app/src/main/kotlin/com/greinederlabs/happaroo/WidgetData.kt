package com.greinederlabs.happaroo

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import org.json.JSONArray
import java.time.LocalDate
import java.time.format.TextStyle
import java.time.temporal.ChronoUnit
import java.util.Locale

/**
 * Shared data and rules for Happaroo's home-screen widgets.
 *
 * The app writes every event once (name, type, month, day, year) and the widgets
 * work out "next occurrence" and "days until" themselves each time they refresh,
 * so they stay right after midnight even if the app has not been opened.
 * Rules match the app: February 29 is observed on February 28 in other years.
 */
object WidgetData {
    const val PREFS = "widget_data"
    const val KEY_EVENTS = "events_json"

    data class Item(
        val name: String,
        val birthday: Boolean,
        val label: String,
        val month: Int,
        val day: Int,
        /** 0 when only the month and day are known. */
        val year: Int,
    )

    data class Upcoming(val item: Item, val date: LocalDate, val days: Long)

    fun load(context: Context): List<Item> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_EVENTS, null)
            ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { i ->
                val o = array.optJSONObject(i) ?: return@mapNotNull null
                val month = o.optInt("m")
                val day = o.optInt("d")
                if (month !in 1..12 || day !in 1..31) return@mapNotNull null
                Item(
                    name = o.optString("n"),
                    birthday = o.optString("t") != "a",
                    label = o.optString("l"),
                    month = month,
                    day = day,
                    year = o.optInt("y"),
                )
            }
        } catch (e: Exception) {
            android.util.Log.e("HapparooWidget", "Bad widget data: ${e.message}")
            emptyList()
        }
    }

    /** The date an event is observed in [year]; null if it had not happened yet (born later). */
    fun observedIn(item: Item, year: Int): LocalDate? {
        if (item.year > 0 && year < item.year) return null
        val leap = java.time.Year.isLeap(year.toLong())
        val day = if (item.month == 2 && item.day == 29 && !leap) 28 else item.day
        return try {
            LocalDate.of(year, item.month, day)
        } catch (e: Exception) {
            null
        }
    }

    fun upcoming(items: List<Item>, today: LocalDate = LocalDate.now()): List<Upcoming> {
        return items.mapNotNull { item ->
            val thisYear = observedIn(item, today.year)
            val date = if (thisYear != null && !thisYear.isBefore(today)) thisYear else observedIn(item, today.year + 1)
            date?.let { Upcoming(item, it, ChronoUnit.DAYS.between(today, it)) }
        }.sortedWith(compareBy({ it.date }, { it.item.name.lowercase(Locale.getDefault()) }))
    }

    /** "Turns 59", "3rd anniversary", "Birthday", or a custom type label. */
    fun detail(u: Upcoming): String {
        val years = if (u.item.year > 0) u.date.year - u.item.year else -1
        if (u.item.label.isNotBlank()) {
            return if (years > 0) "${u.item.label} · $years yrs" else u.item.label
        }
        return if (u.item.birthday) {
            when {
                years > 0 -> "Turns $years"
                years == 0 -> "Born"
                else -> "Birthday"
            }
        } else {
            when {
                years > 0 -> "${ordinal(years)} anniversary"
                years == 0 -> "Wedding day"
                else -> "Anniversary"
            }
        }
    }

    fun countdown(days: Long): String = when (days) {
        0L -> "Today"
        1L -> "Tomorrow"
        else -> "$days days"
    }

    fun ordinal(n: Int): String {
        val suffix = if (n % 100 in 11..13) "th" else when (n % 10) {
            1 -> "st"
            2 -> "nd"
            3 -> "rd"
            else -> "th"
        }
        return "$n$suffix"
    }

    fun weekdayShort(date: LocalDate): String =
        date.dayOfWeek.getDisplayName(TextStyle.SHORT, Locale.getDefault())

    fun monthShort(date: LocalDate): String =
        date.month.getDisplayName(TextStyle.SHORT, Locale.getDefault())

    fun color(context: Context, id: Int): Int = ContextCompat.getColor(context, id)

    fun openAppIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    /** Redraws every placed Happaroo widget. */
    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        fun ids(cls: Class<*>) = manager.getAppWidgetIds(ComponentName(context, cls))
        ids(SingleEventWidgetProvider::class.java).forEach { SingleEventWidgetProvider.render(context, manager, it) }
        ids(UpcomingWidgetProvider::class.java).forEach { UpcomingWidgetProvider.render(context, manager, it) }
        ids(CalendarWidgetProvider::class.java).forEach { CalendarWidgetProvider.render(context, manager, it) }
    }
}
