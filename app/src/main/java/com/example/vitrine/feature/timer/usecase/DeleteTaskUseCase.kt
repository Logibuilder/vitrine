package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.domain.repository.TaskRepository

/**
 * Supprime une tâche : son chrono est d'abord arrêté (notification et alarme retirées),
 * puis la tâche est effacée avec tout son historique.
 */
class DeleteTaskUseCase(
    private val stopTimer: StopTimerUseCase,
    private val tasks: TaskRepository,
) {
    suspend operator fun invoke(taskId: Long) {
        stopTimer(taskId)
        tasks.deleteTask(taskId)
    }
}
