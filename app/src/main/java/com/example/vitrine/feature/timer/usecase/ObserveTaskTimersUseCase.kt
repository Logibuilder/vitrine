package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.domain.model.TaskTimer
import com.example.vitrine.domain.repository.TaskRepository
import com.example.vitrine.domain.repository.TimerRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine

/** Les tâches avec leur chrono et leur temps cumulé, mises à jour à chaque changement en base. */
class ObserveTaskTimersUseCase(
    private val tasks: TaskRepository,
    private val timers: TimerRepository,
) {
    operator fun invoke(): Flow<List<TaskTimer>> = combine(
        tasks.observeTasks(),
        timers.observeStates(),
        timers.observeSessionTotals(),
    ) { taskList, states, totals ->
        val stateByTask = states.associateBy { it.taskId }
        taskList.map { task ->
            TaskTimer(task = task, state = stateByTask[task.id], sessionsMillis = totals[task.id] ?: 0L)
        }
    }
}
