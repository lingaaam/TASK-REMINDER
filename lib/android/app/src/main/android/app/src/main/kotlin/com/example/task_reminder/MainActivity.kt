package com.example.task_reminder

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.example.task_reminder/alarm"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> {
                        val taskId    = call.argument<Int>("taskId") ?: 0
                        val taskTitle = call.argument<String>("taskTitle") ?: ""
                        val timeMs    = call.argument<Long>("timeMillis") ?: 0L
                        scheduleAlarm(taskId, taskTitle, timeMs)
                        result.success(null)
                    }
                    "cancelAlarm" -> {
                        val taskId = call.argument<Int>("taskId") ?: 0
                        cancelAlarm(taskId)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun scheduleAlarm(taskId: Int, taskTitle: String, timeMs: Long) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("taskId", taskId)
            putExtra("taskTitle", taskTitle)
        }
        val pending = PendingIntent.getBroadcast(
            this, taskId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                if (alarmManager.canScheduleExactAlarms())
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pending)
                else
                    alarmManager.set(AlarmManager.RTC_WAKEUP, timeMs, pending)
            }
            else -> alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pending)
        }
    }

    private fun cancelAlarm(taskId: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            this, taskId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pending)
    }
}
