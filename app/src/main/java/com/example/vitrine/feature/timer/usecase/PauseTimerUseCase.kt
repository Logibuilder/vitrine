package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
import com.example.vitrine.domain.alarm.GoalAlarmScheduler
import com.example.vitrine.domain.model.TimerSession
import com.example.vitrine.domain.repository.TimerRepository
import com.example.vitrine.domain.notification.TimerNotifier

/**
 * Met le chrono d'une tâche en pause : la période écoulée devient une session de l'historique
 * et s'ajoute au temps du chrono, qui pourra repartir de là.
 */
class PauseTimerUseCase(
    private val timers: TimerRepository,
    private val notifier: TimerNotifier,
    private val goalAlarm: GoalAlarmScheduler,
    private val clock: Clock,
) {
    suspend operator fun invoke(taskId: Long) {
        val current = timers.getState(taskId) ?: return
        val since = current.runningSince ?: return
        val now = clock.now()

        timers.closeSession(
            session = TimerSession(taskId = taskId, startedAt = since, endedAt = now),
            newState = current.copy(
                accumulatedMillis = current.elapsedAt(now),
                runningSince = null,
            ),
        )
        notifier.cancel(taskId)
        goalAlarm.cancel(taskId) // en pause, l'objectif ne peut pas être atteint
    }
}
