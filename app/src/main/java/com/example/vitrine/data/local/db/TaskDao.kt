package com.example.vitrine.data.local.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import com.example.vitrine.data.local.db.entity.TaskEntity
import kotlinx.coroutines.flow.Flow

@Dao
abstract class TaskDao {

    /** Dans l'ordre choisi par l'utilisateur ; à rang égal, la plus ancienne d'abord. */
    @Query("SELECT * FROM tasks ORDER BY position ASC, id ASC")
    abstract fun observeAll(): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE id = :id")
    abstract suspend fun get(id: Long): TaskEntity?

    @Insert
    abstract suspend fun insert(task: TaskEntity): Long

    @Query("SELECT COALESCE(MAX(position), 0) + 1 FROM tasks")
    abstract suspend fun nextPosition(): Long

    /** Ajoute la tâche en bas de la liste. */
    @Transaction
    open suspend fun insertLast(task: TaskEntity): Long = insert(task.copy(position = nextPosition()))

    @Query("UPDATE tasks SET position = :position WHERE id = :id")
    abstract suspend fun setPosition(id: Long, position: Long)

    /** Enregistre le nouvel ordre : la première tâche de [orderedIds] prend le rang 1, etc. */
    @Transaction
    open suspend fun reorder(orderedIds: List<Long>) {
        orderedIds.forEachIndexed { index, id -> setPosition(id, index + 1L) }
    }

    @Query("UPDATE tasks SET name = :name, goalMillis = :goalMillis WHERE id = :id")
    abstract suspend fun update(id: Long, name: String, goalMillis: Long)

    @Query("DELETE FROM timer_sessions WHERE taskId = :taskId")
    abstract suspend fun deleteSessions(taskId: Long)

    @Query("DELETE FROM timer_states WHERE taskId = :taskId")
    abstract suspend fun deleteState(taskId: Long)

    @Query("DELETE FROM tasks WHERE id = :taskId")
    abstract suspend fun deleteTask(taskId: Long)

    /**
     * Supprime la tâche, son chrono et son historique en une seule transaction.
     * Explicite plutôt que de compter sur ON DELETE CASCADE, qui dépend de l'activation des clés étrangères.
     */
    @Transaction
    open suspend fun deleteWithHistory(taskId: Long) {
        deleteSessions(taskId)
        deleteState(taskId)
        deleteTask(taskId)
    }
}