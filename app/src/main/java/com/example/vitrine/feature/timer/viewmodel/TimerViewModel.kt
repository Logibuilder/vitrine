package com.example.vitrine.feature.timer.viewmodel

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.vitrine.core.util.Clock
import com.example.vitrine.core.util.tickerFlow
import com.example.vitrine.domain.model.Task
import com.example.vitrine.domain.model.TaskTimer
import com.example.vitrine.domain.model.goalProgress
import com.example.vitrine.domain.usecase.ReconstructTimersUseCase
import com.example.vitrine.feature.timer.usecase.AddTaskUseCase
import com.example.vitrine.feature.timer.usecase.DeleteTaskUseCase
import com.example.vitrine.feature.timer.usecase.ObserveTaskTimersUseCase
import com.example.vitrine.feature.timer.usecase.PauseTimerUseCase
import com.example.vitrine.feature.timer.usecase.StartTimerUseCase
import com.example.vitrine.feature.timer.usecase.StopTimerUseCase
import com.example.vitrine.feature.timer.usecase.UpdateTaskUseCase
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/** Une tâche telle qu'affichée dans la liste, avec ses temps calculés à l'instant présent. */
data class TaskTimerItem(
    val id: Long,
    val name: String,
    /** Temps du chrono depuis la dernière remise à zéro. */
    val currentMillis: Long,
    /** Temps total passé sur la tâche, toutes sessions confondues. */
    val totalMillis: Long,
    val isRunning: Boolean,
    /** Objectif de temps du chrono (chaque tâche en a un). */
    val goalMillis: Long = Task.DEFAULT_GOAL_MILLIS,
) {
    /** Vrai si le chrono n'est pas à zéro (en cours ou en pause) : on peut le remettre à zéro. */
    val canReset: Boolean get() = isRunning || currentMillis > 0

    /** Avancement vers l'objectif : 0 → 1, plus de 1 s'il est dépassé. */
    val goalProgress: Float get() = goalProgress(currentMillis, goalMillis)

    val goalReached: Boolean get() = goalProgress >= 1f
}

data class TimerUiState(
    val items: List<TaskTimerItem> = emptyList(),
    val newTaskName: String = "",
    val isLoading: Boolean = true,
) {
    val canAddTask: Boolean get() = newTaskName.isNotBlank()
}

/**
 * Liste des tâches et de leurs chronos.
 * Ne parle qu'aux use cases : la logique (un seul chrono à la fois, alarme d'objectif,
 * notification) reste dans la couche métier, testable sans Android.
 * Les temps affichés sont recalculés chaque seconde à partir des heures de départ enregistrées.
 */
class TimerViewModel(
    private val savedState: SavedStateHandle,
    observeTaskTimers: ObserveTaskTimersUseCase,
    private val addTaskUseCase: AddTaskUseCase,
    private val startTimer: StartTimerUseCase,
    private val pauseTimer: PauseTimerUseCase,
    private val stopTimer: StopTimerUseCase,
    private val updateTaskUseCase: UpdateTaskUseCase,
    private val deleteTaskUseCase: DeleteTaskUseCase,
    private val reconstructTimers: ReconstructTimersUseCase,
    clock: Clock,
) : ViewModel() {

    private val newTaskName = savedState.getStateFlow(KEY_NEW_TASK_NAME, "")

    val uiState: StateFlow<TimerUiState> = combine(
        observeTaskTimers(),
        tickerFlow(now = clock::now),
        newTaskName,
    ) { list, now, name ->
        TimerUiState(
            items = list.map { it.toItem(now) },
            newTaskName = name,
            isLoading = false,
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = TimerUiState(newTaskName = newTaskName.value),
    )

    fun onNewTaskNameChange(value: String) {
        savedState[KEY_NEW_TASK_NAME] = value.replace("\n", "").take(Task.MAX_NAME_LENGTH)
    }

    /** Crée la tâche avec le nom et l'objectif choisis dans la fenêtre « Nouvelle tâche ». */
    fun addTask(name: String, goalMillis: Long) {
        if (name.isBlank()) return
        savedState[KEY_NEW_TASK_NAME] = ""
        viewModelScope.launch { addTaskUseCase(name, goalMillis) }
    }

    /** Lance le chrono s'il est arrêté ou en pause, le met en pause s'il tourne. */
    fun toggle(item: TaskTimerItem) {
        viewModelScope.launch {
            if (item.isRunning) pauseTimer(item.id) else startTimer(item.id)
        }
    }

    fun reset(taskId: Long) {
        viewModelScope.launch { stopTimer(taskId) }
    }

    /** Nouveau nom et nouvel objectif. */
    fun updateTask(taskId: Long, name: String, goalMillis: Long) {
        viewModelScope.launch { updateTaskUseCase(taskId, name, goalMillis) }
    }

    fun delete(taskId: Long) {
        viewModelScope.launch { deleteTaskUseCase(taskId) }
    }

    /** Permission de notification accordée après coup : on affiche les notifications des chronos en cours. */
    fun onNotificationPermissionGranted() {
        viewModelScope.launch { reconstructTimers() }
    }

    private fun TaskTimer.toItem(now: Long) = TaskTimerItem(
        id = task.id,
        name = task.name,
        currentMillis = currentMillis(now),
        totalMillis = totalMillis(now),
        isRunning = isRunning,
        goalMillis = task.goalMillis,
    )

    private companion object {
        const val KEY_NEW_TASK_NAME = "newTaskName"
    }
}
