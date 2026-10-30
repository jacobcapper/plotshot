package com.plotshot.app.widgets

import android.app.ActivityOptions
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.widget.RemoteViews
import com.plotshot.app.MainActivity
import org.json.JSONObject

/** Storage and launch links shared by the home screen widgets. */
object Widgets {
    const val CHANNEL = "com.plotshot.app/widgets"
    private const val LAUNCH_ACTION = "com.plotshot.app.action.WIDGET_LAUNCH"
    private const val PREFS = "plotshot_widgets"
    private const val KEY_DATA = "data"

    /** Stores the data pushed by the app (see lib/data/widget_data.dart) and redraws. */
    fun save(context: Context, json: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_DATA, json).apply()
        ScheduleWidget().updateAll(context)
        GoalWidget().updateAll(context)
    }

    /** The last data pushed by the app, or null if it hasn't run yet. */
    fun data(context: Context): JSONObject? {
        val json = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_DATA, null) ?: return null
        return runCatching { JSONObject(json) }.getOrNull()
    }

    /** Opens the app with a plotshot:// link, handled in lib/screens/home_shell.dart. */
    fun launch(context: Context, link: String): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(LAUNCH_ACTION)
            .setData(Uri.parse(link))
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        if (Build.VERSION.SDK_INT < 34) {
            return PendingIntent.getActivity(context, link.hashCode(), intent, flags)
        }
        // Lets the tap bring the app forward from the home screen on Android 14+.
        val options = ActivityOptions.makeBasic()
        if (Build.VERSION.SDK_INT >= 35) {
            options.setPendingIntentCreatorBackgroundActivityStartMode(
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
            )
        } else {
            @Suppress("DEPRECATION")
            options.pendingIntentBackgroundActivityStartMode =
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
        }
        return PendingIntent.getActivity(
            context, link.hashCode(), intent, flags, options.toBundle()
        )
    }

    /** The link a widget tap carried, or null for any other launch. */
    fun launchLink(intent: Intent?): String? =
        if (intent?.action == LAUNCH_ACTION) intent.dataString else null
}

/**
 * Draws every instance from the stored data. Android also calls onUpdate
 * periodically (updatePeriodMillis), which keeps "Due today" etc. current.
 */
abstract class PlotShotWidget : AppWidgetProvider() {
    abstract fun render(context: Context, data: JSONObject?, options: Bundle): RemoteViews

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, javaClass))
        onUpdate(context, manager, ids)
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val data = Widgets.data(context)
        for (id in ids) {
            manager.updateAppWidget(id, render(context, data, manager.getAppWidgetOptions(id)))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        options: Bundle,
    ) {
        manager.updateAppWidget(id, render(context, Widgets.data(context), options))
    }
}
