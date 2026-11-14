package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
import com.example.vitrine.domain.alarm.GoalAlarmScheduler
import com.example.vitrine.domain.model.TimerState
import com.example.vitrine.domain.model.millisUntilGoal
import com.example.vitrine.domain.repository.TaskRepository
import com.example.vitrine.domain.repository.TimerRepository
import com.example.vitrine.domain.notification.TimerNotifier

/**
 * Lance (ou relance après une pause) le chrono d'une tâche et affiche sa notification.
 * On ne fait qu'une tâche à la fois : le chrono qui tournait sur une autre tâche est mis en pause
 * (son temps est gardé, il pourra repartir de là).
 * Si la tâche a un objectif pas encore atteint, l'alarme est programmée pour l'heure où il le sera.
 */
class StartTimerUseCase(
    private val tasks: TaskRepository,
    private val timers: TimerRepository,
    private val pauseTimer: PauseTimerUseCase,
    private val notifier: TimerNotifier,
    private val goalAlarm: GoalAlarmScheduler,
    private val clock: Clock,
) {
    suspend operator fun invoke(taskId: Long) {
        val task = tasks.getTask(taskId) ?: return
        val current = timers.getState(taskId) ?: TimerState(taskId)
        if (current.isRunning) return

        timers.getRunningStates()
            .filter { it.taskId != taskId }
            .forEach { other -> pauseTimer(other.taskId) }

        val now = clock.now()
        val running = current.copy(runningSince = now)
        timers.saveState(running)
        notifier.showRunning(task, running)
        millisUntilGoal(task.goalMillis, running, now)?.let { delay -> goalAlarm.schedule(taskId, now + delay) }
    }
}
