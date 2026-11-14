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
    onAddTask: () -> Unit,
    onToggle: (TaskTimerItem) -> Unit,
    onReset: (Long) -> Unit,
    onUpdate: (taskId: Long, name: String, goalMillis: Long?) -> Unit,
    onDelete: (Long) -> Unit,
    exactAlarmAllowed: Boolean,
    onAllowExactAlarm: () -> Unit,
    onNavigate: (AppDestination) -> Unit,
) {
    // Tâche en cours de modification, puis tâche dont on confirme la suppression
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
            onAdd = onAddTask,
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
                        modifier = Modifier.animateItem(),
                    )
                }
            }
        }
    }

    val editing = state.items.firstOrNull { it.id == editingId }
    if (editing != null) {
        EditTaskDialog(
            taskId = editing.id,
            initialName = editing.name,
            initialGoalMillis = editing.goalMillis,
            exactAlarmAllowed = exactAlarmAllowed,
            onAllowExactAlarm = onAllowExactAlarm,
            onSave = { name, goal ->
                onUpdate(editing.id, name, goal)
                editingId = null
            },
            onDeleteRequest = {
                editingId = null
                pendingDeleteId = editing.id
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

/** Champ « Nouvelle tâche » et bouton +. La touche Terminer du clavier ajoute aussi la tâche. */
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
                BasicTextField(/** Aucune tâche pour l'instant : on explique comment commencer. */

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
