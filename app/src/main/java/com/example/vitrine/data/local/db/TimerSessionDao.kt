package com.example.vitrine.data.local.db

import androidx.room.Dao
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

/** Temps cumulé des sessions terminées d'une tâche. */
data class TaskSessionTotal(
    val taskId: Long,
    val totalMillis: Long,
)

@Dao
interface TimerSessionDao {

    @Query("SELECT taskId, SUM(endedAt - startedAt) AS totalMillis FROM timer_sessions GROUP BY taskId")
    fun observeTotals(): Flow<List<TaskSessionTotal>>
}
