package com.plotshot.app.widgets

import android.content.Context
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import com.plotshot.app.R
import org.json.JSONObject

/** A progress bar from the first weigh-in to the goal weight. */
class GoalWidget : PlotShotWidget() {

    override fun render(context: Context, data: JSONObject?, options: Bundle): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_goal)
        views.setOnClickPendingIntent(R.id.root, Widgets.launch(context, "plotshot://results"))

        val goal = data?.optJSONObject("goal")
        val message = when (goal?.optString("state")) {
            null -> "Open PlotShot to load your progress"
            "noGoal" -> "Set a goal weight in Settings"
            "noWeight" -> "Log your weight to track progress to ${goal.optString("goal")}"
            else -> null
        }
        val tracking = if (message == null) View.VISIBLE else View.GONE
        views.setViewVisibility(R.id.percent, tracking)
        views.setViewVisibility(R.id.progress, tracking)
        views.setViewVisibility(R.id.scale, tracking)
        views.setViewVisibility(R.id.message, if (message == null) View.GONE else View.VISIBLE)
        if (goal == null || message != null) {
            views.setTextViewText(R.id.title, "Goal")
            views.setTextViewText(R.id.message, message)
            return views
        }

        val percent = goal.optInt("percent").coerceIn(0, 100)
        val reached = goal.optBoolean("reached")
        views.setTextViewText(
            R.id.title,
            if (reached) "Goal reached" else "${goal.optString("toGo")} to go",
        )
        views.setTextViewText(R.id.percent, "$percent%")
        views.setTextColor(
            R.id.percent,
            context.getColor(if (reached) R.color.widget_success else R.color.widget_accent),
        )
        views.setProgressBar(R.id.progress, 100, percent, false)
        views.setContentDescription(R.id.progress, "$percent% of the way to your goal")
        views.setTextViewText(R.id.start, goal.optString("start"))
        views.setTextViewText(R.id.current, "${goal.optString("current")} now")
        views.setTextViewText(R.id.goal, goal.optString("goal"))
        return views
    }
}
