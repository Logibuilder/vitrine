package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
import com.example.vitrine.domain.alarm.GoalAlarmScheduler
import com.example.vitrine.domain.model.Task
import com.example.vitrine.domain.model.TimerSession
import com.example.vitrine.domain.model.TimerState
import com.example.vitrine.domain.notification.TimerNotifier
import com.example.vitrine.domain.repository.TaskRepository
import com.example.vitrine.domain.repository.TimerRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map

/** Horloge réglable à la main. */
class FakeClock(var time: Long = 0L) : Clock {
    override fun now(): Long = time
}

class FakeTaskRepository : TaskRepository {
    private val tasks = MutableStateFlow<List<Task>>(emptyList())
    private var nextId = 1L

    override fun observeTasks(): Flow<List<Task>> = tasks
    override suspend fun getTask(id: Long): Task? = tasks.value.firstOrNull { it.id == id }
    override suspend fun addTask(name: String, createdAt: Long): Long {
        val id = nextId++
        tasks.value = tasks.value + Task(id, name, createdAt)
        return id
    }
    override suspend fun updateTask(id: Long, name: String, goalMillis: Long?) {
        tasks.value = tasks.value.map { if (it.id == id) it.copy(name = name, goalMillis = goalMillis) else it }
    }
    override suspend fun deleteTask(id: Long) {
        tasks.value = tasks.value.filterNot { it.id == id }
    }
}

class FakeTimerRepository : TimerRepository {
    val states = MutableStateFlow<Map<Long, TimerState>>(emptyMap())
    val sessions = mutableListOf<TimerSession>()

    override fun observeStates(): Flow<List<TimerState>> = states.map { it.values.toList() }
    override fun observeSessionTotals(): Flow<Map<Long, Long>> = states.map {
        sessions.groupBy { it.taskId }.mapValues { (_, list) -> list.sumOf { s -> s.durationMillis } }
    }
    override suspend fun getState(taskId: Long): TimerState? = states.value[taskId]
    override suspend fun getRunningStates(): List<TimerState> = states.value.values.filter { it.isRunning }
    override suspend fun saveState(state: TimerState) {
        states.value = states.value + (state.taskId to state)
    }
    override suspend fun deleteState(taskId: Long) {
        states.value = states.value - taskId
    }
    override suspend fun closeSession(session: TimerSession, newState: TimerState?) {
        sessions += session
        if (newState != null) saveState(newState) else deleteState(session.taskId)
    }
}

/** Notifier qui retient les notifications affichées, sans Android. */
class FakeTimerNotifier : TimerNotifier {
    val shown = mutableMapOf<Long, TimerState>()
    val shownNames = mutableMapOf<Long, String>()
    val goalsReached = mutableListOf<Long>()
    override fun showRunning(task: Task, state: TimerState) {
        shown[task.id] = state
        shownNames[task.id] = task.name
    }
    override fun cancel(taskId: Long) {
        shown.remove(taskId)
    }
    override fun showGoalReached(task: Task) {
        goalsReached += task.id
    }
}

/** Alarmes programmées, par tâche : heure de déclenchement. */
class FakeGoalAlarmScheduler : GoalAlarmScheduler {
    val alarms = mutableMapOf<Long, Long>()
    override fun schedule(taskId: Long, triggerAtMillis: Long) {
        alarms[taskId] = triggerAtMillis
    }
    override fun cancel(taskId: Long) {
        alarms.remove(taskId)
    }
}
