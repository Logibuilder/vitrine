package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
import com.example.vitrine.domain.alarm.GoalAlarmScheduler
import com.example.vitrine.domain.model.Task
import com.example.vitrine.domain.model.millisUntilGoal
import com.example.vitrine.domain.notification.TimerNotifier
import com.example.vitrine.domain.repository.TaskRepository
import com.example.vitrine.domain.repository.TimerRepository

/**
 * Modifie le nom et l'objectif d'une tâche (objectif d'au moins 1 minute).
 * Si son chrono tourne, la notification prend le nouveau nom et l'alarme suit le nouvel objectif
 * (reprogrammée, ou annulée s'il est déjà dépassé).
 */
class UpdateTaskUseCase(
    private val tasks: TaskRepository,
    private val timers: TimerRepository,
    private val notifier: TimerNotifier,
    private val goalAlarm: GoalAlarmScheduler,
    private val clock: Clock,
) {
    suspend operator fun invoke(taskId: Long, name: String, goalMillis: Long) {
        val trimmed = name.trim().take(Task.MAX_NAME_LENGTH)
        if (trimmed.isEmpty()) return
        val goal = goalMillis.coerceAtLeast(Task.MIN_GOAL_MILLIS)

        tasks.updateTask(taskId, trimmed, goal)

        val task = tasks.getTask(taskId) ?: return
        val state = timers.getState(taskId)
        if (state == null || !state.isRunning) return

        notifier.showRunning(task, state)
        val now = clock.now()
        val delay = millisUntilGoal(goal, state, now)
        if (delay != null) goalAlarm.schedule(taskId, now + delay) else goalAlarm.cancel(taskId)
    }
}
