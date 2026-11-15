package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
import com.example.vitrine.domain.model.Task
import com.example.vitrine.domain.repository.TaskRepository

/**
 * Crée une tâche avec son objectif (1 minute au minimum) ; ignore un nom vide.
 * Renvoie son identifiant, ou null.
 */
class AddTaskUseCase(
    private val tasks: TaskRepository,
    private val clock: Clock,
) {
    suspend operator fun invoke(name: String, goalMillis: Long = Task.DEFAULT_GOAL_MILLIS): Long? {
        val trimmed = name.trim().take(Task.MAX_NAME_LENGTH)
        if (trimmed.isEmpty()) return null
        return tasks.addTask(trimmed, clock.now(), goalMillis.coerceAtLeast(Task.MIN_GOAL_MILLIS))
    }
}
