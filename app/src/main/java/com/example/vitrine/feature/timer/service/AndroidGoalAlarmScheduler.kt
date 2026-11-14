package com.example.vitrine.feature.timer.service

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.example.vitrine.domain.alarm.GoalAlarmScheduler
import com.example.vitrine.feature.timer.service.TimerNotifications.ACTION_GOAL_REACHED
import com.example.vitrine.feature.timer.service.TimerNotifications.EXTRA_TASK_ID
import com.example.vitrine.feature.timer.service.TimerNotifications.goalNotificationId

/**
 * Alarme « objectif atteint » avec AlarmManager : elle sonne même application fermée
 * et téléphone en veille, sans rien faire tourner en arrière-plan.
 *
 * Alarme exacte si l'utilisateur l'autorise (Android 12+ : « Alarmes et rappels ») ;
 * sinon alarme non exacte, qu'Android peut retarder de quelques minutes en veille profonde.
 */
class AndroidGoalAlarmScheduler(
    private val context: Context,
) : GoalAlarmScheduler {

    private val alarmManager = context.getSystemService(AlarmManager::class.java)

    override fun schedule(taskId: Long, triggerAtMillis: Long) {
        val intent = pendingIntent(taskId)
        if (canScheduleExact()) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, intent)
        } else {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, intent)
        }
    }

    override fun cancel(taskId: Long) {
        alarmManager.cancel(pendingIntent(taskId))
    }

    private fun canScheduleExact(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()

    /** Un PendingIntent par tâche : programmer de nouveau remplace l'alarme précédente. */
    private fun pendingIntent(taskId: Long): PendingIntent {
        val intent = Intent(context, GoalAlarmReceiver::class.java)
            .setAction(ACTION_GOAL_REACHED)
            .putExtra(EXTRA_TASK_ID, taskId)
        return PendingIntent.getBroadcast(
            context,
            goalNotificationId(taskId),
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
