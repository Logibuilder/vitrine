package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
import com.example.vitrine.domain.alarm.GoalAlarmScheduler
import com.example.vitrine.domain.model.TimerSession
import com.example.vitrine.domain.repository.TimerRepository
import com.example.vitrine.domain.notification.TimerNotifier

/**
 * Arrête le chrono d'une tâche et le remet à zéro.
 * La période en cours est gardée dans l'historique : le temps total de la tâche ne diminue pas.
 */
class StopTimerUseCase(
    private val timers: TimerRepository,
    private val notifier: TimerNotifier,
    private val goalAlarm: GoalAlarmScheduler,
    private val clock: Clock,
) {
    suspend operator fun invoke(taskId: Long) {
        val current = timers.getState(taskId) ?: return
        val since = current.runningSince

        if (since != null) {
            val session = TimerSession(taskId = taskId, startedAt = since, endedAt = clock.now())
            timers.closeSession(session, newState = null)
        } else {
            timers.deleteState(taskId)
        }
        notifier.cancel(taskId)
        goalAlarm.cancel(taskId)
    }
}
