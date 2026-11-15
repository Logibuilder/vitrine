package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
import com.example.vitrine.domain.alarm.GoalAlarmScheduler
import com.example.vitrine.domain.model.millisUntilGoal
import com.example.vitrine.domain.notification.TimerNotifier
import com.example.vitrine.domain.repository.TaskRepository
import com.example.vitrine.domain.repository.TimerRepository

/**
 * Appelé quand l'alarme d'une tâche sonne. On vérifie d'abord que c'est toujours d'actualité :
 * - chrono en pause, arrêté ou tâche supprimée : rien à faire ;
 * - objectif pas encore atteint (objectif modifié entre-temps) : on reprogramme l'alarme ;
 * - sinon : notification « objectif atteint ».
 */
class NotifyGoalReachedUseCase(
    private val tasks: TaskRepository,
    private val timers: TimerRepository,
    private val notifier: TimerNotifier,
    private val goalAlarm: GoalAlarmScheduler,
    private val clock: Clock,
) {
    suspend operator fun invoke(taskId: Long) {
        val task = tasks.getTask(taskId) ?: return
        val goal = task.goalMillis
        val state = timers.getState(taskId)?.takeIf { it.isRunning } ?: return

        val now = clock.now()
        val remaining = millisUntilGoal(goal, state, now)
        // Une alarme peut arriver une fraction de seconde en avance : on tolère 2 s
        if (remaining != null && remaining > EARLY_TOLERANCE_MILLIS) {
            goalAlarm.schedule(taskId, now + remaining)
        } else {
            notifier.showGoalReached(task)
        }
    }

    private companion object {
        const val EARLY_TOLERANCE_MILLIS = 2_000L
    }
}
