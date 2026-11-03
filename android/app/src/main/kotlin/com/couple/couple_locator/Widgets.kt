package com.couple.couple_locator

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

private fun launchIntent(context: Context): PendingIntent {
    val i = Intent(context, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }
    return PendingIntent.getActivity(context, 0, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
}

/** 小号小组件：对方距离 + 最后更新时间。数据由 Dart 端通过 home_widget 写入。 */
class SmallWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.widget_small)
            v.setTextViewText(R.id.w_emoji, widgetData.getString("emoji", "💗"))
            v.setTextViewText(R.id.w_distance, widgetData.getString("distance", "--"))
            v.setTextViewText(R.id.w_updated, widgetData.getString("updated", "等待更新"))
            v.setOnClickPendingIntent(R.id.widget_root, launchIntent(context))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

/** 中号小组件：距离、电量、最后更新、移动状态。 */
class MediumWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.widget_medium)
            v.setTextViewText(R.id.w_emoji, widgetData.getString("emoji", "💗"))
            v.setTextViewText(R.id.w_name, widgetData.getString("name", "TA"))
            v.setTextViewText(R.id.w_distance, widgetData.getString("distance", "--"))
            v.setTextViewText(R.id.w_battery, widgetData.getString("battery", "电量 --"))
            v.setTextViewText(R.id.w_updated, widgetData.getString("updated", "等待更新"))
            v.setOnClickPendingIntent(R.id.widget_root, launchIntent(context))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
