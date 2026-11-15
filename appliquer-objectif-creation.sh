#!/usr/bin/env bash
# Chronos : régler l'objectif dès la création d'une tâche (fenêtre « Nouvelle tâche »).
# À lancer depuis la racine du projet VITRINE, après appliquer-boutons-tache-v2.sh.
# Pensez à faire un commit avant : les fichiers existants sont écrasés.
set -euo pipefail

if [[ ! -f settings.gradle.kts || ! -d app/src/main ]]; then
  echo "Erreur : lancez ce script depuis la racine du projet VITRINE." >&2
  exit 1
fi

write() { mkdir -p "$(dirname "$1")"; cat > "$1"; echo "  écrit : $1"; }

echo "Remplacement :"
write app/src/main/java/com/example/vitrine/data/repository/TaskRepositoryImpl.kt <<'EOF_VITRINE'
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
        dao.insert(TaskEntity(name = name.trim(), createdAt = createdAt, goalMillis = goalMillis))

    override suspend fun updateTask(id: Long, name: String, goalMillis: Long) =
        dao.update(id, name.trim(), goalMillis)

    override suspend fun deleteTask(id: Long) = dao.deleteWithHistory(id)
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/domain/repository/TaskRepository.kt <<'EOF_VITRINE'
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
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/ui/home/EditTaskDialog.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.vitrine.R
import com.example.vitrine.core.ui.components.SectionLabel
import com.example.vitrine.core.ui.components.SegmentedControl
import com.example.vitrine.core.util.formatTotal
import com.example.vitrine.domain.model.Task
import com.example.vitrine.feature.timer.ui.components.MinusIcon
import com.example.vitrine.feature.timer.ui.components.PlusIcon
import com.example.vitrine.feature.timer.ui.components.RoundIconButton
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineShapes

private const val MINUTE = 60_000L
private const val GOAL_STEP = 5 * MINUTE
private const val GOAL_MIN = 5 * MINUTE
private const val GOAL_MAX = 10 * 60 * MINUTE
private val GOAL_PRESETS = listOf(15L, 25L, 45L, 60L).map { it * MINUTE }

/**
 * Fenêtre d'une tâche : nom et objectif (réglable de 5 en 5 minutes ou par raccourcis).
 * Sert à la création (« Nouvelle tâche » / « Créer ») et à la modification (« Modifier » / « Enregistrer »).
 * Chaque tâche a un objectif ; la suppression se fait depuis la carte.
 *
 * @param stateKey identifie ce qui est édité : les valeurs saisies sont gardées pendant une rotation.
 * @param exactAlarmAllowed faux si Android peut retarder l'alarme : on propose alors de l'autoriser.
 */
@Composable
fun EditTaskDialog(
    stateKey: String,
    title: String,
    confirmLabel: String,
    initialName: String,
    initialGoalMillis: Long,
    exactAlarmAllowed: Boolean,
    onAllowExactAlarm: () -> Unit,
    onSave: (name: String, goalMillis: Long) -> Unit,
    onDismiss: () -> Unit,
) {
    // Valeurs en cours d'édition, gardées pendant une rotation
    var name by rememberSaveable(stateKey) { mutableStateOf(initialName) }
    var goal by rememberSaveable(stateKey) { mutableLongStateOf(initialGoalMillis.coerceIn(GOAL_MIN, GOAL_MAX)) }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = VitrineColors.Surface,
        titleContentColor = VitrineColors.TextPrimary,
        title = { Text(title) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                NameField(name = name, onNameChange = { name = it.replace("\n", "").take(Task.MAX_NAME_LENGTH) })

                SectionLabel(stringResource(R.string.timer_goal_label))
                GoalStepper(goal = goal, onGoalChange = { goal = it })
                SegmentedControl(
                    options = GOAL_PRESETS,
                    selected = goal,
                    onSelect = { goal = it },
                    // Nombre de minutes seul : quatre choix doivent tenir dans la fenêtre
                    label = { preset -> (preset / MINUTE).toString() },
                    modifier = Modifier.align(Alignment.CenterHorizontally),
                )
                if (!exactAlarmAllowed) {
                    ExactAlarmHint(onAllow = onAllowExactAlarm)
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = { onSave(name, goal) },
                enabled = name.isNotBlank(),
            ) {
                Text(confirmLabel, color = VitrineColors.Accent)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.timer_cancel), color = VitrineColors.TextPrimary)
            }
        },
    )
}

@Composable
private fun NameField(
    name: String,
    onNameChange: (String) -> Unit,
) {
    BasicTextField(
        value = name,
        onValueChange = onNameChange,
        singleLine = true,
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
        textStyle = TextStyle(fontSize = 17.sp, color = VitrineColors.TextPrimary),
        cursorBrush = SolidColor(VitrineColors.Accent),
        modifier = Modifier.fillMaxWidth(),
        decorationBox = { inner ->
            Column(
                Modifier
                    .clip(VitrineShapes.Control)
                    .background(VitrineColors.SurfaceMuted)
                    .padding(horizontal = 14.dp, vertical = 12.dp),
            ) {
                if (name.isEmpty()) {
                    Text(
                        text = stringResource(R.string.timer_new_task_placeholder),
                        fontSize = 17.sp,
                        color = VitrineColors.TextMuted,
                    )
                }
                inner()
            }
        },
    )
}

/** [−] 25 min [+] : réglage fin, de 5 en 5 minutes, entre 5 min et 10 h. */
@Composable
private fun GoalStepper(
    goal: Long,
    onGoalChange: (Long) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        RoundIconButton(
            contentDescription = stringResource(R.string.timer_goal_less),
            background = VitrineColors.SurfaceMuted,
            size = 40.dp,
            enabled = goal > GOAL_MIN,
            onClick = { onGoalChange((goal - GOAL_STEP).coerceAtLeast(GOAL_MIN)) },
        ) {
            MinusIcon(VitrineColors.TextPrimary, Modifier.size(16.dp))
        }
        Text(
            text = formatTotal(goal),
            style = MaterialTheme.typography.headlineMedium,
            color = VitrineColors.TextPrimary,
            textAlign = TextAlign.Center,
            modifier = Modifier.weight(1f),
        )
        RoundIconButton(
            contentDescription = stringResource(R.string.timer_goal_more),
            background = VitrineColors.SurfaceMuted,
            size = 40.dp,
            enabled = goal < GOAL_MAX,
            onClick = { onGoalChange((goal + GOAL_STEP).coerceAtMost(GOAL_MAX)) },
        ) {
            PlusIcon(VitrineColors.TextPrimary, Modifier.size(16.dp))
        }
    }
}

/** Android peut retarder l'alarme de quelques minutes : on explique et on propose de l'autoriser. */
@Composable
private fun ExactAlarmHint(onAllow: () -> Unit) {
    Column {
        Text(
            text = stringResource(R.string.timer_exact_alarm_hint),
            style = MaterialTheme.typography.labelSmall,
            color = VitrineColors.TextMuted,
        )
        TextButton(onClick = onAllow) {
            Text(stringResource(R.string.timer_exact_alarm_allow), color = VitrineColors.Accent)
        }
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/ui/home/TimerHomeScreen.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.vitrine.R
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.core.ui.components.StatusDot
import com.example.vitrine.core.ui.components.VitrineCard
import com.example.vitrine.core.ui.components.VitrineScreen
import com.example.vitrine.domain.model.Task
import com.example.vitrine.feature.timer.ui.TaskItem
import com.example.vitrine.feature.timer.ui.components.PlusIcon
import com.example.vitrine.feature.timer.ui.components.RoundIconButton
import com.example.vitrine.feature.timer.viewmodel.TaskTimerItem
import com.example.vitrine.feature.timer.viewmodel.TimerUiState
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineDimens

/**
 * Écran des chronos : ajout d'une tâche en haut, liste des tâches et de leurs chronos.
 * Même gabarit que les autres écrans : titre, cartes, menu.
 */
@Composable
fun TimerHomeScreen(
    state: TimerUiState,
    onNewTaskNameChange: (String) -> Unit,
    onAddTask: (name: String, goalMillis: Long) -> Unit,
    onToggle: (TaskTimerItem) -> Unit,
    onReset: (Long) -> Unit,
    onUpdate: (taskId: Long, name: String, goalMillis: Long) -> Unit,
    onDelete: (Long) -> Unit,
    exactAlarmAllowed: Boolean,
    onAllowExactAlarm: () -> Unit,
    onNavigate: (AppDestination) -> Unit,
) {
    // Création en cours (fenêtre « Nouvelle tâche »), tâche en cours de modification,
    // puis tâche dont on confirme la suppression
    var creating by rememberSaveable { mutableStateOf(false) }
    var editingId by rememberSaveable { mutableStateOf<Long?>(null) }
    var pendingDeleteId by rememberSaveable { mutableStateOf<Long?>(null) }

    VitrineScreen(
        title = stringResource(R.string.timer_title),
        current = AppDestination.TIMER,
        onNavigate = onNavigate,
    ) {
        NewTaskCard(
            name = state.newTaskName,
            canAdd = state.canAddTask,
            onNameChange = onNewTaskNameChange,
            onAdd = { creating = true },
        )

        if (!state.isLoading && state.items.isEmpty()) {
            EmptyCard(Modifier.weight(1f))
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.spacedBy(VitrineDimens.SectionGap),
            ) {
                items(state.items, key = { it.id }) { item ->
                    TaskItem(
                        item = item,
                        onToggle = { onToggle(item) },
                        onReset = { onReset(item.id) },
                        onEdit = { editingId = item.id },
                        onDelete = { pendingDeleteId = item.id },
                        modifier = Modifier.animateItem(),
                    )
                }
            }
        }
    }

    // Nouvelle tâche : on choisit son objectif tout de suite, le nom tapé est déjà rempli
    if (creating) {
        EditTaskDialog(
            stateKey = "new",
            title = stringResource(R.string.timer_new_task_title),
            confirmLabel = stringResource(R.string.timer_create),
            initialName = state.newTaskName.trim(),
            initialGoalMillis = Task.DEFAULT_GOAL_MILLIS,
            exactAlarmAllowed = exactAlarmAllowed,
            onAllowExactAlarm = onAllowExactAlarm,
            onSave = { name, goal ->
                onAddTask(name, goal)
                creating = false
            },
            onDismiss = { creating = false },
        )
    }

    val editing = state.items.firstOrNull { it.id == editingId }
    if (editing != null) {
        EditTaskDialog(
            stateKey = "edit-${editing.id}",
            title = stringResource(R.string.timer_edit_title),
            confirmLabel = stringResource(R.string.timer_save),
            initialName = editing.name,
            initialGoalMillis = editing.goalMillis,
            exactAlarmAllowed = exactAlarmAllowed,
            onAllowExactAlarm = onAllowExactAlarm,
            onSave = { name, goal ->
                onUpdate(editing.id, name, goal)
                editingId = null
            },
            onDismiss = { editingId = null },
        )
    }

    val toDelete = state.items.firstOrNull { it.id == pendingDeleteId }
    if (toDelete != null) {
        DeleteTaskDialog(
            taskName = toDelete.name,
            onConfirm = {
                onDelete(toDelete.id)
                pendingDeleteId = null
            },
            onDismiss = { pendingDeleteId = null },
        )
    }
}

/**
 * Champ « Nouvelle tâche » et bouton + : ils ouvrent la fenêtre de création, où l'on règle l'objectif.
 * La touche Terminer du clavier fait de même.
 */
@Composable
private fun NewTaskCard(
    name: String,
    canAdd: Boolean,
    onNameChange: (String) -> Unit,
    onAdd: () -> Unit,
) {
    VitrineCard {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(Modifier.weight(1f)) {
                BasicTextField(
                    value = name,
                    onValueChange = onNameChange,
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.Sentences,
                        imeAction = ImeAction.Done,
                    ),
                    keyboardActions = KeyboardActions(onDone = { if (canAdd) onAdd() }),
                    textStyle = TextStyle(fontSize = 17.sp, color = VitrineColors.TextPrimary),
                    cursorBrush = SolidColor(VitrineColors.Accent),
                    modifier = Modifier.fillMaxWidth(),
                    decorationBox = { inner ->
                        if (name.isEmpty()) {
                            Text(
                                text = stringResource(R.string.timer_new_task_placeholder),
                                fontSize = 17.sp,
                                color = VitrineColors.TextMuted,
                            )
                        }
                        inner()
                    },
                )
            }
            Spacer(Modifier.width(12.dp))
            RoundIconButton(
                contentDescription = stringResource(R.string.timer_add_task),
                background = VitrineColors.Accent,
                size = 40.dp,
                enabled = canAdd,
                onClick = onAdd,
            ) {
                PlusIcon(VitrineColors.Surface, Modifier.size(18.dp))
            }
        }
    }
}

/** Aucune tâche pour l'instant : on explique comment commencer. */
@Composable
private fun EmptyCard(modifier: Modifier = Modifier) {
    VitrineCard(modifier = modifier) {
        StatusDot(text = stringResource(R.string.timer_empty_status), color = VitrineColors.Warning)
        Spacer(Modifier.height(8.dp))
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                text = stringResource(R.string.timer_empty_title),
                style = MaterialTheme.typography.headlineMedium,
                color = VitrineColors.TextPrimary,
            )
            Text(
                text = stringResource(R.string.timer_empty_body),
                style = MaterialTheme.typography.bodyMedium,
                color = VitrineColors.TextMuted,
            )
        }
    }
}

@Composable
private fun DeleteTaskDialog(
    taskName: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = VitrineColors.Surface,
        titleContentColor = VitrineColors.TextPrimary,
        textContentColor = VitrineColors.TextMuted,
        title = { Text(stringResource(R.string.timer_delete_title, taskName)) },
        text = { Text(stringResource(R.string.timer_delete_body)) },
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text(stringResource(R.string.timer_delete), color = VitrineColors.Danger)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.timer_cancel), color = VitrineColors.TextPrimary)
            }
        },
    )
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/usecase/AddTaskUseCase.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
import com.example.vitrine.domain.model.Task
import com.example.vitrine.domain.repository.TaskRepository

/**
 * Crée une tâche avec son objectif (1 minute au minimum) ; ignore un nom vide.
 * Renvoie son identifiant, ou null.
 */
class AddTaskUseCase(
    private val tasks: TaskRepository,
    private val clock: Clock,
) {
    suspend operator fun invoke(name: String, goalMillis: Long = Task.DEFAULT_GOAL_MILLIS): Long? {
        val trimmed = name.trim().take(Task.MAX_NAME_LENGTH)
        if (trimmed.isEmpty()) return null
        return tasks.addTask(trimmed, clock.now(), goalMillis.coerceAtLeast(Task.MIN_GOAL_MILLIS))
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/viewmodel/TimerViewModel.kt <<'EOF_VITRINE'
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
EOF_VITRINE

write app/src/main/res/values/strings_timer.xml <<'EOF_VITRINE'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Feature chronos par tâche (le titre timer_title est dans strings_menu.xml) -->
    <string name="timer_new_task_placeholder">Nouvelle tâche…</string>
    <string name="timer_add_task">Ajouter la tâche</string>
    <string name="timer_new_task_title">Nouvelle tâche</string>
    <string name="timer_create">Créer</string>

    <string name="timer_empty_status">Aucune tâche</string>
    <string name="timer_empty_title">Créez votre première tâche</string>
    <string name="timer_empty_body">Donnez-lui un nom, puis lancez son chrono. Il continue de tourner même application fermée.</string>

    <string name="timer_running">En cours</string>
    <string name="timer_paused">En pause</string>
    <string name="timer_total">Total : %1$s</string>
    <string name="timer_start">Lancer le chrono</string>
    <string name="timer_pause">Pause</string>
    <string name="timer_stop">Arrêter</string>
    <string name="timer_reset">Remettre à zéro</string>

    <!-- Modification et objectif -->
    <string name="timer_edit">Modifier la tâche</string>
    <string name="timer_edit_title">Modifier la tâche</string>
    <string name="timer_save">Enregistrer</string>
    <string name="timer_goal_label">Objectif</string>
    <string name="timer_goal_less">Réduire l\'objectif de 5 minutes</string>
    <string name="timer_goal_more">Augmenter l\'objectif de 5 minutes</string>
    <string name="timer_goal_caption">Objectif : %1$s</string>
    <string name="timer_goal_remaining">Reste %1$s</string>
    <string name="timer_goal_exceeded">Dépassé de %1$s</string>
    <string name="timer_goal_reached_status">Objectif atteint</string>
    <string name="timer_exact_alarm_hint">Android peut retarder l\'alarme de quelques minutes. Autorisez les alarmes exactes pour être prévenu à l\'heure.</string>
    <string name="timer_exact_alarm_allow">Autoriser</string>
    <string name="timer_delete_task">Supprimer la tâche</string>

    <string name="timer_delete">Supprimer</string>
    <string name="timer_delete_title">Supprimer « %1$s » ?</string>
    <string name="timer_delete_body">La tâche, son chrono et tout son historique seront effacés.</string>
    <string name="timer_cancel">Annuler</string>

    <!-- Notification -->
    <string name="timer_channel_name">Chronos en cours</string>
    <string name="timer_channel_description">Affiche le temps des chronos qui tournent.</string>
    <string name="timer_notification_running">Chrono en cours</string>
    <string name="timer_goal_channel_name">Objectifs atteints</string>
    <string name="timer_goal_channel_description">Sonne quand le chrono d\'une tâche atteint son objectif.</string>
    <string name="timer_goal_reached_title">Objectif atteint</string>
    <string name="timer_goal_reached_text">%1$s : %2$s</string>
</resources>
EOF_VITRINE

write app/src/test/java/com/example/vitrine/feature/timer/usecase/Fakes.kt <<'EOF_VITRINE'
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
    override suspend fun addTask(name: String, createdAt: Long, goalMillis: Long): Long {
        val id = nextId++
        tasks.value = tasks.value + Task(id, name, createdAt, goalMillis)
        return id
    }
    override suspend fun updateTask(id: Long, name: String, goalMillis: Long) {
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
EOF_VITRINE

write app/src/test/java/com/example/vitrine/feature/timer/usecase/GoalUseCasesTest.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.domain.usecase.ReconstructTimersUseCase
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** Objectif de temps : alarme programmée, annulée, reprogrammée ; notification au bon moment. */
class GoalUseCasesTest {

    private val minute = 60_000L

    private lateinit var clock: FakeClock
    private lateinit var tasks: FakeTaskRepository
    private lateinit var timers: FakeTimerRepository
    private lateinit var notifier: FakeTimerNotifier
    private lateinit var alarms: FakeGoalAlarmScheduler
    private lateinit var start: StartTimerUseCase
    private lateinit var pause: PauseTimerUseCase
    private lateinit var stop: StopTimerUseCase
    private lateinit var update: UpdateTaskUseCase
    private lateinit var goalReached: NotifyGoalReachedUseCase
    private var taskId = 0L

    @Before
    fun setUp() = runBlocking {
        clock = FakeClock(time = 1_000_000L)
        tasks = FakeTaskRepository()
        timers = FakeTimerRepository()
        notifier = FakeTimerNotifier()
        alarms = FakeGoalAlarmScheduler()
        pause = PauseTimerUseCase(timers, notifier, alarms, clock)
        start = StartTimerUseCase(tasks, timers, pause, notifier, alarms, clock)
        stop = StopTimerUseCase(timers, notifier, alarms, clock)
        update = UpdateTaskUseCase(tasks, timers, notifier, alarms, clock)
        goalReached = NotifyGoalReachedUseCase(tasks, timers, notifier, alarms, clock)
        taskId = tasks.addTask("Révisions", clock.now())
        tasks.updateTask(taskId, "Révisions", 25 * minute)
    }

    @Test
    fun `lancer programme l'alarme a l'heure de l'objectif`() = runBlocking {
        start(taskId)
        assertEquals(clock.now() + 25 * minute, alarms.alarms[taskId])
    }

    @Test
    fun `apres une pause l'alarme tient compte du temps deja fait`() = runBlocking {
        start(taskId)
        clock.time += 10 * minute
        pause(taskId)
        assertNull(alarms.alarms[taskId]) // en pause : pas d'alarme
        clock.time += 60 * minute
        start(taskId)
        assertEquals(clock.now() + 15 * minute, alarms.alarms[taskId])
    }

    @Test
    fun `arreter annule l'alarme`() = runBlocking {
        start(taskId)
        stop(taskId)
        assertTrue(alarms.alarms.isEmpty())
    }

    @Test
    fun `une nouvelle tache a l'objectif par defaut de 25 min`() = runBlocking {
        val id = AddTaskUseCase(tasks, clock)("Sport")!!
        assertEquals(25 * minute, tasks.getTask(id)!!.goalMillis)
        start(id)
        assertEquals(clock.now() + 25 * minute, alarms.alarms[id])
    }

    @Test
    fun `objectif deja depasse au lancement - pas d'alarme`() = runBlocking {
        start(taskId)
        clock.time += 30 * minute
        pause(taskId)
        start(taskId)
        assertNull(alarms.alarms[taskId])
    }

    @Test
    fun `modifier l'objectif d'un chrono en cours reprogramme l'alarme et renomme la notification`() = runBlocking {
        start(taskId)
        clock.time += 5 * minute
        update(taskId, "Maths", 45 * minute)
        assertEquals(clock.now() + 40 * minute, alarms.alarms[taskId])
        assertEquals("Maths", notifier.shownNames[taskId])
    }

    @Test
    fun `reduire l'objectif sous le temps deja fait annule l'alarme`() = runBlocking {
        start(taskId)
        clock.time += 20 * minute
        update(taskId, "Révisions", 10 * minute)
        assertNull(alarms.alarms[taskId])
    }

    @Test
    fun `objectif nul ramene au minimum d'une minute`() = runBlocking {
        update(taskId, "Révisions", 0)
        assertEquals(minute, tasks.getTask(taskId)!!.goalMillis)
    }

    @Test
    fun `nom vide refuse`() = runBlocking {
        update(taskId, "   ", 10 * minute)
        assertEquals("Révisions", tasks.getTask(taskId)!!.name)
    }

    @Test
    fun `l'alarme sonne a l'objectif - notification`() = runBlocking {
        start(taskId)
        clock.time += 25 * minute
        goalReached(taskId)
        assertEquals(listOf(taskId), notifier.goalsReached)
    }

    @Test
    fun `alarme perimee - objectif allonge entre-temps - on reprogramme sans notifier`() = runBlocking {
        start(taskId)
        tasks.updateTask(taskId, "Révisions", 60 * minute) // modifié sans passer par le use case
        clock.time += 25 * minute
        goalReached(taskId)
        assertTrue(notifier.goalsReached.isEmpty())
        assertEquals(clock.now() + 35 * minute, alarms.alarms[taskId])
    }

    @Test
    fun `alarme alors que le chrono est en pause - rien`() = runBlocking {
        start(taskId)
        pause(taskId)
        goalReached(taskId)
        assertTrue(notifier.goalsReached.isEmpty())
    }

    @Test
    fun `supprimer la tache arrete tout`() = runBlocking {
        start(taskId)
        DeleteTaskUseCase(stop, tasks)(taskId)
        assertNull(tasks.getTask(taskId))
        assertTrue(alarms.alarms.isEmpty())
        assertFalse(notifier.shown.containsKey(taskId))
    }

    @Test
    fun `apres un redemarrage l'alarme est reprogrammee`() = runBlocking {
        start(taskId)
        clock.time += 10 * minute
        alarms.alarms.clear() // le redémarrage efface les alarmes
        ReconstructTimersUseCase(tasks, timers, notifier, alarms, clock)()
        assertEquals(clock.now() + 15 * minute, alarms.alarms[taskId])
    }

    @Test
    fun `l'objectif choisi a la creation est garde et sert a l'alarme`() = runBlocking {
        val id = AddTaskUseCase(tasks, clock)("Lecture", 45 * minute)!!
        assertEquals(45 * minute, tasks.getTask(id)!!.goalMillis)
        start(id)
        assertEquals(clock.now() + 45 * minute, alarms.alarms[id])
    }

    @Test
    fun `objectif nul a la creation ramene au minimum`() = runBlocking {
        val id = AddTaskUseCase(tasks, clock)("Pause", 0)!!
        assertEquals(minute, tasks.getTask(id)!!.goalMillis)
    }

    @Test
    fun `ajouter une tache - nom nettoye et limite`() = runBlocking {
        val add = AddTaskUseCase(tasks, clock)
        assertNull(add("   "))
        val id = add("  " + "a".repeat(60) + "  ")!!
        assertEquals(40, tasks.getTask(id)!!.name.length)
    }
}
EOF_VITRINE

echo
echo "Terminé. Dans Android Studio : Build > Rebuild Project."
