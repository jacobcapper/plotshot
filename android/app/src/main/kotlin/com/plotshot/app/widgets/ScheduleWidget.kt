package com.plotshot.app.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import com.plotshot.app.R
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale

/** Upcoming jabs, soonest first, with an Add Jab button. Tapping a row adds a jab of it. */
class ScheduleWidget : PlotShotWidget() {

    override fun render(context: Context, data: JSONObject?, options: Bundle): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_schedule)
        views.setOnClickPendingIntent(R.id.root, Widgets.launch(context, "plotshot://jabs"))
        views.setOnClickPendingIntent(
            R.id.add_button,
            Widgets.launch(context, "plotshot://add-jab"),
        )
        views.removeAllViews(R.id.rows)

        val jabs = data?.optJSONArray("jabs")
        if (jabs == null || jabs.length() == 0) {
            views.setViewVisibility(R.id.empty, View.VISIBLE)
            views.setTextViewText(
                R.id.empty,
                if (data == null) "Open PlotShot to load your schedule"
                else "Log your first jab to start a schedule",
            )
            return views
        }
        views.setViewVisibility(R.id.empty, View.GONE)

        val today = LocalDate.now()
        val (compact, rows) = rowLayout(options, jabs.length())
        for (i in 0 until minOf(jabs.length(), rows)) {
            views.addView(R.id.rows, row(context, jabs.getJSONObject(i), today, compact))
        }
        return views
    }

    private fun row(
        context: Context,
        jab: JSONObject,
        today: LocalDate,
        compact: Boolean,
    ): RemoteViews {
        val row = RemoteViews(
            context.packageName,
            if (compact) R.layout.widget_schedule_row_compact else R.layout.widget_schedule_row,
        )
        val name = jab.getString("name")
        val dose = jab.optStringOrNull("dose")
        row.setTextViewText(R.id.name, if (dose == null) name else "$name · $dose")

        val due = if (jab.isNull("due")) null else {
            Instant.ofEpochMilli(jab.getLong("due")).atZone(ZoneId.systemDefault()).toLocalDate()
        }
        val days = due?.let { ChronoUnit.DAYS.between(today, it).toInt() }
        row.setTextViewText(R.id.status, dueLabel(days))
        val color = when {
            days == null || days > 0 -> R.color.widget_muted
            days == 0 -> R.color.widget_warning
            else -> R.color.widget_danger
        }
        row.setTextColor(R.id.status, context.getColor(color))
        // Compact rows have no site or date views.
        if (!compact) {
            val site = jab.optStringOrNull("site")
            row.setViewVisibility(R.id.site, if (site == null) View.GONE else View.VISIBLE)
            row.setTextViewText(R.id.site, site ?: "")
            row.setViewVisibility(R.id.date, if (due == null) View.GONE else View.VISIBLE)
            row.setTextViewText(R.id.date, due?.format(dateFormat) ?: "")
        }

        val med = jab.optInt("medicationId", -1)
        row.setOnClickPendingIntent(
            R.id.row,
            Widgets.launch(context, "plotshot://add-jab?med=$med"),
        )
        return row
    }

    /**
     * Whether to use compact rows, and how many rows fit under the header at
     * the widget's current height. Full rows (46dp, with site and date) are
     * used when they show as many medications as compact rows (30dp) would.
     */
    private fun rowLayout(options: Bundle, count: Int): Pair<Boolean, Int> {
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
        if (height == 0) return Pair(false, 2)
        val space = height - 58 // padding, header and its margin
        val full = (space / 46).coerceIn(1, 4)
        val compact = (space / 30).coerceIn(1, 4)
        return if (full >= minOf(count, compact)) Pair(false, full) else Pair(true, compact)
    }

    companion object {
        private val dateFormat = DateTimeFormatter.ofPattern("EEE d MMM", Locale.getDefault())

        /** Mirrors NextJabInfo.label in lib/logic/schedule.dart. */
        fun dueLabel(days: Int?): String = when {
            days == null -> "Log your first jab"
            days == 0 -> "Due today"
            days == -1 -> "Due yesterday"
            days < 0 -> "Overdue by ${-days} days"
            days == 1 -> "Due tomorrow"
            else -> "Due in $days days"
        }
    }
}

internal fun JSONObject.optStringOrNull(key: String): String? =
    if (isNull(key)) null else optString(key)
