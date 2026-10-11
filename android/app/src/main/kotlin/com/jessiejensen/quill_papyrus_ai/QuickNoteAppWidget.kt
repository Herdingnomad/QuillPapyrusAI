package com.jessiejensen.quill_papyrus_ai

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

class QuickNoteAppWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_UPDATE_WIDGET) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, QuickNoteAppWidget::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (id in allWidgetIds) {
                updateAppWidget(context, appWidgetManager, id)
            }
        }
    }

    companion object {
        const val PREFS_NAME = "quill_papyrus_widget_prefs"
        const val KEY_RECENT_TITLE = "recent_title"
        const val KEY_RECENT_SNIPPET = "recent_snippet"
        const val ACTION_UPDATE_WIDGET = "com.jessiejensen.quill_papyrus_ai.UPDATE_WIDGET"

        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val recentTitle = prefs.getString(KEY_RECENT_TITLE, "Tap + Note to capture your thoughts") ?: "Tap + Note to capture your thoughts"
            val recentSnippet = prefs.getString(KEY_RECENT_SNIPPET, "On-device Markdown IDE with local Gemma AI") ?: "On-device Markdown IDE with local Gemma AI"

            val views = RemoteViews(context.packageName, R.layout.widget_quick_note)
            views.setTextViewText(R.id.tv_widget_recent_title, recentTitle)
            views.setTextViewText(R.id.tv_widget_recent_snippet, recentSnippet)

            // PendingIntent for Quick Capture dialog (Floating card without opening full app)
            val quickCaptureIntent = Intent(context, QuickCaptureActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val quickCapturePendingIntent = PendingIntent.getActivity(
                context,
                1001,
                quickCaptureIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_widget_quick_note, quickCapturePendingIntent)
            views.setOnClickPendingIntent(R.id.widget_tap_to_type_bar, quickCapturePendingIntent)

            // PendingIntent for "Daily" button -> quillpapyrus://daily-note
            val dailyNoteIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("quillpapyrus://daily-note")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val dailyNotePendingIntent = PendingIntent.getActivity(
                context,
                1002,
                dailyNoteIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_widget_daily_note, dailyNotePendingIntent)

            // PendingIntent for entire card / icon -> open app
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("quillpapyrus://open")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                1003,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_recent_card, openAppPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_app_icon, openAppPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_header_title, openAppPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAllWidgets(context: Context) {
            val intent = Intent(context, QuickNoteAppWidget::class.java).apply {
                action = ACTION_UPDATE_WIDGET
            }
            context.sendBroadcast(intent)
        }
    }
}
