package com.example.vitrine.data.repository

import com.example.vitrine.data.local.db.TaskDao
import com.example.vitrine.data.local.db.entity.TaskEntity
import com.example.vitrine.data.local.db.entity.toDomain
import com.example.vitrine.domain.model.Task
import com.example.vitrine.domain.repository.TaskRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

class TaskRepositoryImpl(
    private val dao: TaskDao,
) : TaskRepository {

    override fun observeTasks(): Flow<List<Task>> =
        dao.observeAll().map { tasks -> tasks.map { it.toDomain() } }

    override suspend fun getTask(id: Long): Task? = dao.get(id)?.toDomain()

    override suspend fun addTask(name: String, createdAt: Long, goalMillis: Long): Long =
        dao.insertLast(TaskEntity(name = name.trim(), createdAt = createdAt, goalMillis = goalMillis))

    override suspend fun updateTask(id: Long, name: String, goalMillis: Long) =
        dao.update(id, name.trim(), goalMillis)

    override suspend fun reorderTasks(orderedIds: List<Long>) = dao.reorder(orderedIds)

    override suspend fun deleteTask(id: Long) = dao.deleteWithHistory(id)
}