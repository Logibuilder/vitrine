package com.example.vitrine.domain.repository

import com.example.vitrine.domain.model.TimerSession
import com.example.vitrine.domain.model.TimerState
import kotlinx.coroutines.flow.Flow

/** Chronos en cours ou en pause, et historique des sessions terminées. */
interface TimerRepository {
    fun observeStates(): Flow<List<TimerState>>

    /** Temps cumulé des sessions terminées, par identifiant de tâche. */
    fun observeSessionTotals(): Flow<Map<Long, Long>>

    suspend fun getState(taskId: Long): TimerState?

    suspend fun getRunningStates(): List<TimerState>

    suspend fun saveState(state: TimerState)

    suspend fun deleteState(taskId: Long)

    /**
     * Enregistre une session terminée et, dans la même transaction, le nouvel état du chrono :
     * [newState] en pause, ou null pour remettre le chrono à zéro.
     */
    suspend fun closeSession(session: TimerSession, newState: TimerState?)
}
