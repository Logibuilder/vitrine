package com.example.vitrine.feature.timer.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.example.vitrine.feature.timer.service.TimerNotifications.ACTION_GOAL_REACHED
import com.example.vitrine.feature.timer.service.TimerNotifications.EXTRA_TASK_ID
import com.example.vitrine.feature.timer.usecase.NotifyGoalReachedUseCase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/** Reçoit l'alarme « objectif atteint » et délègue au use case (qui vérifie qu'elle est d'actualité). */
class GoalAlarmReceiver : BroadcastReceiver(), KoinComponent {

    private val notifyGoalReached: NotifyGoalReachedUseCase by inject()

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_GOAL_REACHED) return
        val taskId = intent.getLongExtra(EXTRA_TASK_ID, -1L).takeIf { it >= 0 } ?: return

        val pending = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                notifyGoalReached(taskId)
            } finally {
                pending.finish()
            }
        }
    }
}
