package com.example.jieddev_money_manager

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class MoneyManagerWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)

        for (appWidgetId in appWidgetIds) {
            val balance = widgetData.getInt("balance", 0)
            val transactionHistory = widgetData.getString("transaction_history", "No transactions yet.")
                ?: "No transactions yet."

            val views = RemoteViews(context.packageName, R.layout.money_manager_widget).apply {
                setTextViewText(R.id.widget_balance, formatCurrency(balance))
                setTextViewText(R.id.widget_history, transactionHistory)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun formatCurrency(amount: Int): String {
        return String.format("₱%.2f", amount.toDouble())
    }
}