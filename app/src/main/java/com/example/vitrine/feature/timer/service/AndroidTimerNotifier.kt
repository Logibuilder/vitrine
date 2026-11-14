package com.example.vitrine.feature.timer.service

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.example.vitrine.MainActivity
import com.example.vitrine.R
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.core.navigation.EXTRA_DESTINATION
import com.example.vitrine.domain.model.Task
import com.example.vitrine.domain.model.TimerState
import com.example.vitrine.domain.notification.TimerNotifier
import com.example.vitrine.feature.timer.service.TimerNotifications.ACTION_PAUSE
import com.example.vitrine.feature.timer.service.TimerNotifications.ACTION_STOP
import com.example.vitrine.feature.timer.service.TimerNotifications.CHANNEL_ID
import com.example.vitrine.feature.timer.service.TimerNotifications.GOAL_CHANNEL_ID
import com.example.vitrine.feature.timer.service.TimerNotifications.goalNotificationId
import com.example.vitrine.core.util.formatTotal
import com.example.vitrine.feature.timer.service.TimerNotifications.EXTRA_TASK_ID
import com.example.vitrine.feature.timer.service.TimerNotifications.notificationId

/**
 * Notification d'un chrono en cours : nom de la tâche et temps qui défile.
 * Le temps est affiché par le compteur du système (setUsesChronometer) : l'application
 * n'a pas besoin de tourner en arrière-plan, ni d'un service au premier plan.
 * Boutons : Pause et Arrêter ; un appui ouvre l'écran des chronos.
 * Quand l'objectif d'une tâche est atteint, une seconde notification, sonore, prévient l'utilisateur.
 */
class AndroidTimerNotifier(
    private val context: Context,
) : TimerNotifier {

    private val manager = NotificationManagerCompat.from(context)

    init {
        manager.createNotificationChannelsCompat(
            listOf(
                // Chrono en cours : discret, sans son
                NotificationChannelCompat.Builder(CHANNEL_ID, NotificationManagerCompat.IMPORTANCE_LOW)
                    .setName(context.getString(R.string.timer_channel_name))
                    .setDescription(context.getString(R.string.timer_channel_description))
                    .setShowBadge(false)
                    .build(),
                // Objectif atteint : son, vibration et bandeau
                NotificationChannelCompat.Builder(GOAL_CHANNEL_ID, NotificationManagerCompat.IMPORTANCE_HIGH)
                    .setName(context.getString(R.string.timer_goal_channel_name))
                    .setDescription(context.getString(R.string.timer_goal_channel_description))
                    .setVibrationEnabled(true)
                    .build(),
            )
        )
    }

    @SuppressLint("MissingPermission") // vérifiée juste au-dessus avec canNotify()
    override fun showRunning(task: Task, state: TimerState) {
        if (!canNotify()) return
        val since = state.runningSince ?: return

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_timer)
            .setContentTitle(task.name)
            .setContentText(context.getString(R.string.timer_notification_running))
            // Le compteur affiche « maintenant − when » : on recule « when » du temps déjà compté
            .setWhen(since - state.accumulatedMillis)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setOngoing(true)
            .setSilent(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setContentIntent(openTimersIntent())
            .addAction(0, context.getString(R.string.timer_pause), actionIntent(ACTION_PAUSE, task.id))
            .addAction(0, context.getString(R.string.timer_stop), actionIntent(ACTION_STOP, task.id))
            .build()

        manager.notify(notificationId(task.id), notification)
    }

    override fun cancel(taskId: Long) {
        manager.cancel(notificationId(taskId))
        manager.cancel(goalNotificationId(taskId))
    }

    @SuppressLint("MissingPermission") // vérifiée juste au-dessus avec canNotify()
    override fun showGoalReached(task: Task) {
        if (!canNotify()) return
        val goal = task.goalMillis ?: return

        val notification = NotificationCompat.Builder(context, GOAL_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_timer)
            .setContentTitle(context.getString(R.string.timer_goal_reached_title))
            .setContentText(
                context.getString(R.string.timer_goal_reached_text, task.name, formatTotal(goal))
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setAutoCancel(true)
            .setContentIntent(openTimersIntent())
            .build()

        manager.notify(goalNotificationId(task.id), notification)
    }

    /** Avant Android 13, aucune permission n'est nécessaire ; ensuite, il faut POST_NOTIFICATIONS. */
    private fun canNotify(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    private fun openTimersIntent(): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .putExtra(EXTRA_DESTINATION, AppDestination.TIMER.name)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun actionIntent(action: String, taskId: Long): PendingIntent {
        val intent = Intent(context, TimerActionReceiver::class.java)
            .setAction(action)
            .putExtra(EXTRA_TASK_ID, taskId)
        // Code de requête différent par tâche et par bouton, sinon les PendingIntent se remplacent
        val requestCode = notificationId(taskId) * 2 + if (action == ACTION_PAUSE) 0 else 1
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
