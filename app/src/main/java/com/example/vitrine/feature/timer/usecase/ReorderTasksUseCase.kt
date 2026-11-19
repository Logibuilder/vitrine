package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.domain.repository.TaskRepository

/** Enregistre l'ordre des tâches choisi par glisser-déposer ([orderedIds] de haut en bas). */
class ReorderTasksUseCase(
    private val tasks: TaskRepository,
) {
    suspend operator fun invoke(orderedIds: List<Long>) {
        val ids = orderedIds.distinct()
        if (ids.size < 2) return // rien à ordonner
        tasks.reorderTasks(ids)
    }
}