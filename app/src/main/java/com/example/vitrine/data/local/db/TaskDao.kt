package com.example.vitrine.data.local.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import com.example.vitrine.data.local.db.entity.TaskEntity
import kotlinx.coroutines.flow.Flow

@Dao
abstract class TaskDao {

    @Query("SELECT * FROM tasks ORDER BY createdAt ASC")
    abstract fun observeAll(): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE id = :id")
    abstract suspend fun get(id: Long): TaskEntity?

    @Insert
    abstract suspend fun insert(task: TaskEntity): Long

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
