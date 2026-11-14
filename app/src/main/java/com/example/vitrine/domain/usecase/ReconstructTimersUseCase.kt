package com.example.vitrine.domain.usecase

import com.example.vitrine.domain.repository.TaskRepository
import com.example.vitrine.domain.repository.TimerRepository
import com.example.vitrine.core.util.Clock
import com.example.vitrine.domain.alarm.GoalAlarmScheduler
import com.example.vitrine.domain.model.millisUntilGoal
import com.example.vitrine.domain.notification.TimerNotifier

/**
 * Remet en place les notifications et les alarmes des chronos qui tournent, par exemple après
 * un redémarrage du téléphone (qui efface notifications et alarmes) ou au lancement de l'application.
 * Les chronos eux-mêmes n'ont rien à « rattraper » : leur heure de départ est enregistrée.
 */
class ReconstructTimersUseCase(
    private val tasks: TaskRepository,
    private val timers: TimerRepository,
    private val notifier: TimerNotifier,
    private val goalAlarm: GoalAlarmScheduler,
    private val clock: Clock,
) {
    suspend operator fun invoke() {
        val now = clock.now()
        timers.getRunningStates().forEach { state ->
            val task = tasks.getTask(state.taskId)
            if (task == null) {
                timers.deleteState(state.taskId)
                return@forEach
            }
            notifier.showRunning(task, state)
            // Objectif atteint pendant que le téléphone était éteint : rien à reprogrammer
            millisUntilGoal(task.goalMillis, state, now)?.let { delay -> goalAlarm.schedule(task.id, now + delay) }
        }
    }
}
