package com.example.vitrine.data.local.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Upsert
import com.example.vitrine.data.local.db.entity.TimerSessionEntity
import com.example.vitrine.data.local.db.entity.TimerStateEntity
import kotlinx.coroutines.flow.Flow

@Dao
abstract class TimerStateDao {

    @Query("SELECT * FROM timer_states")
    abstract fun observeAll(): Flow<List<TimerStateEntity>>

    @Query("SELECT * FROM timer_states WHERE taskId = :taskId")
    abstract suspend fun get(taskId: Long): TimerStateEntity?

    @Query("SELECT * FROM timer_states WHERE runningSince IS NOT NULL")
    abstract suspend fun getRunning(): List<TimerStateEntity>

    @Upsert
    abstract suspend fun upsert(state: TimerStateEntity)

    @Query("DELETE FROM timer_states WHERE taskId = :taskId")
    abstract suspend fun delete(taskId: Long)

    @Insert
    abstract suspend fun insertSession(session: TimerSessionEntity)

    /** Enregistre la session terminée et le nouvel état (null = remise à zéro), ensemble ou pas du tout. */
    @Transaction
    open suspend fun closeSession(session: TimerSessionEntity, newState: TimerStateEntity?) {
        insertSession(session)
        if (newState != null) upsert(newState) else delete(session.taskId)
    }
}
