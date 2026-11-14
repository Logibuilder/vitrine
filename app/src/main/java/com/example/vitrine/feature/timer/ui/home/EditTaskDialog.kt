package com.example.vitrine.feature.timer.ui.home

import androidx.compose.animation.AnimatedVisibility
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
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
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
private const val GOAL_DEFAULT = 25 * MINUTE
private val GOAL_PRESETS = listOf(15L, 25L, 45L, 60L).map { it * MINUTE }

/**
 * Fenêtre de modification d'une tâche : nom, objectif (activé ou non, réglable de 5 en 5 minutes
 * ou par raccourcis), et accès à la suppression.
 *
 * @param exactAlarmAllowed faux si Android peut retarder l'alarme : on propose alors de l'autoriser.
 */
@Composable
fun EditTaskDialog(
    taskId: Long,
    initialName: String,
    initialGoalMillis: Long?,
    exactAlarmAllowed: Boolean,
    onAllowExactAlarm: () -> Unit,
    onSave: (name: String, goalMillis: Long?) -> Unit,
    onDeleteRequest: () -> Unit,
    onDismiss: () -> Unit,
) {
    // Valeurs en cours d'édition, gardées pendant une rotation
    var name by rememberSaveable(taskId) { mutableStateOf(initialName) }
    var hasGoal by rememberSaveable(taskId) { mutableStateOf(initialGoalMillis != null) }
    var goal by rememberSaveable(taskId) { mutableLongStateOf(initialGoalMillis ?: GOAL_DEFAULT) }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = VitrineColors.Surface,
        titleContentColor = VitrineColors.TextPrimary,
        title = { Text(stringResource(R.string.timer_edit_title)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                NameField(name = name, onNameChange = { name = it.replace("\n", "").take(Task.MAX_NAME_LENGTH) })

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    SectionLabel(stringResource(R.string.timer_goal_label))
                    Switch(
                        checked = hasGoal,
                        onCheckedChange = { hasGoal = it },
                        colors = SwitchDefaults.colors(
                            checkedTrackColor = VitrineColors.Accent,
                            checkedThumbColor = VitrineColors.Surface,
                            uncheckedTrackColor = VitrineColors.SurfaceMuted,
                            uncheckedThumbColor = VitrineColors.TextMuted,
                            uncheckedBorderColor = VitrineColors.Divider,
                        ),
                    )
                }

                AnimatedVisibility(visible = hasGoal) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
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
                }

                // Suppression : demande une confirmation dans une seconde fenêtre
                TextButton(
                    onClick = onDeleteRequest,
                    modifier = Modifier.align(Alignment.Start),
                ) {
                    Text(stringResource(R.string.timer_delete_task), color = VitrineColors.Danger)
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = { onSave(name, if (hasGoal) goal else null) },
                enabled = name.isNotBlank(),
            ) {
                Text(stringResource(R.string.timer_save), color = VitrineColors.Accent)
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
