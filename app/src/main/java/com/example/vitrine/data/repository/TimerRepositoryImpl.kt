package com.example.vitrine.data.repository

import com.example.vitrine.data.local.db.TimerSessionDao
import com.example.vitrine.data.local.db.TimerStateDao
import com.example.vitrine.data.local.db.entity.toDomain
import com.example.vitrine.data.local.db.entity.toEntity
import com.example.vitrine.domain.model.TimerSession
import com.example.vitrine.domain.model.TimerState
import com.example.vitrine.domain.repository.TimerRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

class TimerRepositoryImpl(
    private val stateDao: TimerStateDao,
    private val sessionDao: TimerSessionDao,
) : TimerRepository {

    override fun observeStates(): Flow<List<TimerState>> =
        stateDao.observeAll().map { states -> states.map { it.toDomain() } }

    override fun observeSessionTotals(): Flow<Map<Long, Long>> =
        sessionDao.observeTotals().map { totals -> totals.associate { it.taskId to it.totalMillis } }

    override suspend fun getState(taskId: Long): TimerState? = stateDao.get(taskId)?.toDomain()

    override suspend fun getRunningStates(): List<TimerState> = stateDao.getRunning().map { it.toDomain() }

    override suspend fun saveState(state: TimerState) = stateDao.upsert(state.toEntity())

    override suspend fun deleteState(taskId: Long) = stateDao.delete(taskId)

    override suspend fun closeSession(session: TimerSession, newState: TimerState?) =
        stateDao.closeSession(session.toEntity(), newState?.toEntity())
}
