package com.example.vitrine.domain.repository

import com.example.vitrine.domain.model.Task
import kotlinx.coroutines.flow.Flow

/** Les tâches de l'utilisateur. */
interface TaskRepository {
    /** Toutes les tâches, de la plus ancienne à la plus récente. */
    fun observeTasks(): Flow<List<Task>>

    suspend fun getTask(id: Long): Task?

    /** Crée une tâche avec son objectif et renvoie son identifiant. */
    suspend fun addTask(name: String, createdAt: Long, goalMillis: Long = Task.DEFAULT_GOAL_MILLIS): Long

    /** Change le nom et l'objectif d'une tâche. */
    suspend fun updateTask(id: Long, name: String, goalMillis: Long)

    /** Supprime la tâche avec son chrono et tout son historique. */
    suspend fun deleteTask(id: Long)
}
