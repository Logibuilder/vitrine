package com.example.vitrine.feature.timer.service

/** Identifiants partagés entre la notification et le récepteur de ses boutons. */
internal object TimerNotifications {
    const val CHANNEL_ID = "timers"
    const val GOAL_CHANNEL_ID = "timer_goals"
    const val ACTION_GOAL_REACHED = "com.example.vitrine.action.GOAL_REACHED"
    const val ACTION_PAUSE = "com.example.vitrine.action.PAUSE_TIMER"
    const val ACTION_STOP = "com.example.vitrine.action.STOP_TIMER"
    const val EXTRA_TASK_ID = "com.example.vitrine.extra.TASK_ID"

    /** Un identifiant de notification par tâche (décalé pour ne gêner aucune autre notification). */
    fun notificationId(taskId: Long): Int = 10_000 + (taskId % 1_000_000).toInt()

    /** Notification « objectif atteint » : distincte de celle du chrono, qui reste affichée. */
    fun goalNotificationId(taskId: Long): Int = 2_000_000 + (taskId % 1_000_000).toInt()
}
