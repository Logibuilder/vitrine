#!/usr/bin/env bash
# Chronos : objectif par tâche (alarme, couleurs vert -> rouge), modification et suppression.
# À lancer depuis la racine du projet VITRINE, après appliquer-chrono.sh et le correctif
# « un seul chrono à la fois ». Pensez à faire un commit avant : les fichiers existants sont écrasés.
set -euo pipefail

if [[ ! -f settings.gradle.kts || ! -d app/src/main ]]; then
  echo "Erreur : lancez ce script depuis la racine du projet VITRINE." >&2
  exit 1
fi

write() { mkdir -p "$(dirname "$1")"; cat > "$1"; echo "  écrit : $1"; }
remove() {
  if [[ -f "$1" ]]; then
    if git ls-files --error-unmatch "$1" >/dev/null 2>&1; then git rm -q "$1"; else rm "$1"; fi
    echo "  supprimé : $1"
  else echo "  déjà absent : $1"; fi
}

echo "Suppression (fichiers déplacés) :"
remove app/src/main/java/com/example/vitrine/feature/timer/ui/model/DurationFormat.kt
remove app/src/test/java/com/example/vitrine/feature/timer/ui/model/DurationFormatTest.kt

echo "Création :"
write app/src/main/java/com/example/vitrine/core/util/DurationFormat.kt <<'EOF_VITRINE'
package com.example.vitrine.core.util

/**
 * Temps d'un chrono : « 04:07 » sous une heure, « 1:04:07 » au-delà.
 * Les secondes sont tronquées (un chrono n'affiche pas 1 s avant qu'elle soit écoulée).
 */
fun formatStopwatch(millis: Long): String {
    val totalSeconds = millis.coerceAtLeast(0L) / 1_000
    val hours = totalSeconds / 3_600
    val minutes = (totalSeconds % 3_600) / 60
    val seconds = totalSeconds % 60
    return if (hours > 0) {
        "$hours:${minutes.twoDigits()}:${seconds.twoDigits()}"
    } else {
        "${minutes.twoDigits()}:${seconds.twoDigits()}"
    }
}

/** Temps total, lisible d'un coup d'œil : « 3 h 12 min », « 12 min », « 45 s ». */
fun formatTotal(millis: Long): String {
    val totalSeconds = millis.coerceAtLeast(0L) / 1_000
    val hours = totalSeconds / 3_600
    val minutes = (totalSeconds % 3_600) / 60
    return when {
        hours > 0 && minutes > 0 -> "$hours h $minutes min"
        hours > 0 -> "$hours h"
        minutes > 0 -> "$minutes min"
        else -> "$totalSeconds s"
    }
}

private fun Long.twoDigits(): String = toString().padStart(2, '0')
EOF_VITRINE

write app/src/main/java/com/example/vitrine/domain/alarm/GoalAlarmScheduler.kt <<'EOF_VITRINE'
package com.example.vitrine.domain.alarm

/**
 * Programme l'alarme « objectif atteint » d'une tâche.
 * Interface du domaine : l'implémentation Android (AlarmManager) est dans feature/timer/service.
 */
interface GoalAlarmScheduler {
    /** Programme (ou reprogramme) l'alarme de la tâche à l'heure [triggerAtMillis]. */
    fun schedule(taskId: Long, triggerAtMillis: Long)

    fun cancel(taskId: Long)
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/service/AndroidGoalAlarmScheduler.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.service

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.example.vitrine.domain.alarm.GoalAlarmScheduler
import com.example.vitrine.feature.timer.service.TimerNotifications.ACTION_GOAL_REACHED
import com.example.vitrine.feature.timer.service.TimerNotifications.EXTRA_TASK_ID
import com.example.vitrine.feature.timer.service.TimerNotifications.goalNotificationId

/**
 * Alarme « objectif atteint » avec AlarmManager : elle sonne même application fermée
 * et téléphone en veille, sans rien faire tourner en arrière-plan.
 *
 * Alarme exacte si l'utilisateur l'autorise (Android 12+ : « Alarmes et rappels ») ;
 * sinon alarme non exacte, qu'Android peut retarder de quelques minutes en veille profonde.
 */
class AndroidGoalAlarmScheduler(
    private val context: Context,
) : GoalAlarmScheduler {

    private val alarmManager = context.getSystemService(AlarmManager::class.java)

    override fun schedule(taskId: Long, triggerAtMillis: Long) {
        val intent = pendingIntent(taskId)
        if (canScheduleExact()) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, intent)
        } else {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, intent)
        }
    }

    override fun cancel(taskId: Long) {
        alarmManager.cancel(pendingIntent(taskId))
    }

    private fun canScheduleExact(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()

    /** Un PendingIntent par tâche : programmer de nouveau remplace l'alarme précédente. */
    private fun pendingIntent(taskId: Long): PendingIntent {
        val intent = Intent(context, GoalAlarmReceiver::class.java)
            .setAction(ACTION_GOAL_REACHED)
            .putExtra(EXTRA_TASK_ID, taskId)
        return PendingIntent.getBroadcast(
            context,
            goalNotificationId(taskId),
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/service/GoalAlarmReceiver.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.example.vitrine.feature.timer.service.TimerNotifications.ACTION_GOAL_REACHED
import com.example.vitrine.feature.timer.service.TimerNotifications.EXTRA_TASK_ID
import com.example.vitrine.feature.timer.usecase.NotifyGoalReachedUseCase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/** Reçoit l'alarme « objectif atteint » et délègue au use case (qui vérifie qu'elle est d'actualité). */
class GoalAlarmReceiver : BroadcastReceiver(), KoinComponent {

    private val notifyGoalReached: NotifyGoalReachedUseCase by inject()

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_GOAL_REACHED) return
        val taskId = intent.getLongExtra(EXTRA_TASK_ID, -1L).takeIf { it >= 0 } ?: return

        val pending = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                notifyGoalReached(taskId)
            } finally {
                pending.finish()
            }
        }
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/ui/components/GoalProgress.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.unit.dp
import com.example.vitrine.ui.theme.VitrineColors

/**
 * Couleur selon l'avancement vers l'objectif :
 * vert jusqu'à la moitié, puis vert → ambre, puis ambre → rouge ; rouge une fois l'objectif atteint.
 */
@Composable
fun goalColor(progress: Float): Color {
    val green = VitrineColors.Accent
    val amber = VitrineColors.Warning
    val red = VitrineColors.Danger
    return when {
        progress >= 1f -> red
        progress >= 0.75f -> lerp(amber, red, (progress - 0.75f) / 0.25f)
        progress >= 0.5f -> lerp(green, amber, (progress - 0.5f) / 0.25f)
        else -> green
    }
}

/** Barre plate de progression vers l'objectif ; sa couleur suit [goalColor]. */
@Composable
fun GoalProgressBar(
    progress: Float,
    modifier: Modifier = Modifier,
) {
    val fill by animateFloatAsState(progress.coerceIn(0f, 1f), label = "goal-progress")
    val color by animateColorAsState(goalColor(progress), label = "goal-color")
    val shape = RoundedCornerShape(50)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(6.dp)
            .clip(shape)
            .background(VitrineColors.SurfaceMuted),
    ) {
        Box(
            modifier = Modifier
                .fillMaxHeight()
                .fillMaxWidth(fill)
                .clip(shape)
                .background(color),
        )
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/ui/home/EditTaskDialog.kt <<'EOF_VITRINE'
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
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/usecase/AddTaskUseCase.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
import com.example.vitrine.domain.model.Task
import com.example.vitrine.domain.repository.TaskRepository

/** Crée une tâche (sans objectif) ; ignore un nom vide. Renvoie son identifiant, ou null. */
class AddTaskUseCase(
    private val tasks: TaskRepository,
    private val clock: Clock,
) {
    suspend operator fun invoke(name: String): Long? {
        val trimmed = name.trim().take(Task.MAX_NAME_LENGTH)
        if (trimmed.isEmpty()) return null
        return tasks.addTask(trimmed, clock.now())
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/usecase/DeleteTaskUseCase.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.domain.repository.TaskRepository

/**
 * Supprime une tâche : son chrono est d'abord arrêté (notification et alarme retirées),
 * puis la tâche est effacée avec tout son historique.
 */
class DeleteTaskUseCase(
    private val stopTimer: StopTimerUseCase,
    private val tasks: TaskRepository,
) {
    suspend operator fun invoke(taskId: Long) {
        stopTimer(taskId)
        tasks.deleteTask(taskId)
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/usecase/NotifyGoalReachedUseCase.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
import com.example.vitrine.domain.alarm.GoalAlarmScheduler
import com.example.vitrine.domain.model.millisUntilGoal
import com.example.vitrine.domain.notification.TimerNotifier
import com.example.vitrine.domain.repository.TaskRepository
import com.example.vitrine.domain.repository.TimerRepository

/**
 * Appelé quand l'alarme d'une tâche sonne. On vérifie d'abord que c'est toujours d'actualité :
 * - chrono en pause, arrêté ou tâche supprimée : rien à faire ;
 * - objectif pas encore atteint (objectif modifié entre-temps) : on reprogramme l'alarme ;
 * - sinon : notification « objectif atteint ».
 */
class NotifyGoalReachedUseCase(
    private val tasks: TaskRepository,
    private val timers: TimerRepository,
    private val notifier: TimerNotifier,
    private val goalAlarm: GoalAlarmScheduler,
    private val clock: Clock,
) {
    suspend operator fun invoke(taskId: Long) {
        val task = tasks.getTask(taskId) ?: return
        val goal = task.goalMillis ?: return
        val state = timers.getState(taskId)?.takeIf { it.isRunning } ?: return

        val now = clock.now()
        val remaining = millisUntilGoal(goal, state, now)
        // Une alarme peut arriver une fraction de seconde en avance : on tolère 2 s
        if (remaining != null && remaining > EARLY_TOLERANCE_MILLIS) {
            goalAlarm.schedule(taskId, now + remaining)
        } else {
            notifier.showGoalReached(task)
        }
    }

    private companion object {
        const val EARLY_TOLERANCE_MILLIS = 2_000L
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/usecase/ObserveTaskTimersUseCase.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.domain.model.TaskTimer
import com.example.vitrine.domain.repository.TaskRepository
import com.example.vitrine.domain.repository.TimerRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine

/** Les tâches avec leur chrono et leur temps cumulé, mises à jour à chaque changement en base. */
class ObserveTaskTimersUseCase(
    private val tasks: TaskRepository,
    private val timers: TimerRepository,
) {
    operator fun invoke(): Flow<List<TaskTimer>> = combine(
        tasks.observeTasks(),
        timers.observeStates(),
        timers.observeSessionTotals(),
    ) { taskList, states, totals ->
        val stateByTask = states.associateBy { it.taskId }
        taskList.map { task ->
            TaskTimer(task = task, state = stateByTask[task.id], sessionsMillis = totals[task.id] ?: 0L)
        }
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/usecase/UpdateTaskUseCase.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
import com.example.vitrine.domain.alarm.GoalAlarmScheduler
import com.example.vitrine.domain.model.Task
import com.example.vitrine.domain.model.millisUntilGoal
import com.example.vitrine.domain.notification.TimerNotifier
import com.example.vitrine.domain.repository.TaskRepository
import com.example.vitrine.domain.repository.TimerRepository

/**
 * Modifie le nom et l'objectif d'une tâche.
 * Si son chrono tourne, la notification prend le nouveau nom et l'alarme suit le nouvel objectif
 * (reprogrammée, ou annulée s'il n'y a plus d'objectif ou s'il est déjà dépassé).
 */
class UpdateTaskUseCase(
    private val tasks: TaskRepository,
    private val timers: TimerRepository,
    private val notifier: TimerNotifier,
    private val goalAlarm: GoalAlarmScheduler,
    private val clock: Clock,
) {
    suspend operator fun invoke(taskId: Long, name: String, goalMillis: Long?) {
        val trimmed = name.trim().take(Task.MAX_NAME_LENGTH)
        if (trimmed.isEmpty()) return
        val goal = goalMillis?.takeIf { it > 0 }

        tasks.updateTask(taskId, trimmed, goal)

        val task = tasks.getTask(taskId) ?: return
        val state = timers.getState(taskId)
        if (state == null || !state.isRunning) return

        notifier.showRunning(task, state)
        val now = clock.now()
        val delay = millisUntilGoal(goal, state, now)
        if (delay != null) goalAlarm.schedule(taskId, now + delay) else goalAlarm.cancel(taskId)
    }
}
EOF_VITRINE

write app/src/test/java/com/example/vitrine/core/util/DurationFormatTest.kt <<'EOF_VITRINE'
package com.example.vitrine.core.util

import org.junit.Assert.assertEquals
import org.junit.Test

class DurationFormatTest {

    @Test
    fun `chrono sous une heure en minutes et secondes`() {
        assertEquals("00:00", formatStopwatch(0))
        assertEquals("04:07", formatStopwatch(247_999))
    }

    @Test
    fun `chrono au-dela d'une heure`() {
        assertEquals("1:04:07", formatStopwatch(3_847_000))
    }

    @Test
    fun `temps total lisible`() {
        assertEquals("45 s", formatTotal(45_000))
        assertEquals("12 min", formatTotal(720_000))
        assertEquals("2 h", formatTotal(7_200_000))
        assertEquals("3 h 12 min", formatTotal(11_520_000))
    }

    @Test
    fun `une valeur negative s'affiche comme zero`() {
        assertEquals("00:00", formatStopwatch(-5_000))
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
    fun `sans objectif aucune alarme`() = runBlocking {
        tasks.updateTask(taskId, "Révisions", null)
        start(taskId)
        assertTrue(alarms.alarms.isEmpty())
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
    fun `retirer l'objectif annule l'alarme`() = runBlocking {
        start(taskId)
        update(taskId, "Révisions", null)
        assertNull(alarms.alarms[taskId])
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
    fun `ajouter une tache - nom nettoye et limite`() = runBlocking {
        val add = AddTaskUseCase(tasks, clock)
        assertNull(add("   "))
        val id = add("  " + "a".repeat(60) + "  ")!!
        assertEquals(40, tasks.getTask(id)!!.name.length)
    }
}
EOF_VITRINE

echo "Remplacement :"
write app/src/main/AndroidManifest.xml <<'EOF_VITRINE'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <!-- Chronos : notification du temps qui défile (Android 13+) et retour après redémarrage -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <!-- Objectif de temps : alarme à l'heure exacte (Android 12+, l'utilisateur peut la refuser) -->
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />

    <application
        android:name=".App"
        android:allowBackup="true"
        android:dataExtractionRules="@xml/data_extraction_rules"
        android:fullBackupContent="@xml/backup_rules"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.Vitrine">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:label="@string/app_name"
            android:launchMode="singleTop"
            android:theme="@style/Theme.Vitrine"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />

                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <!-- Boutons Pause / Arrêter de la notification des chronos -->
        <receiver
            android:name=".feature.timer.service.TimerActionReceiver"
            android:exported="false" />

        <!-- Alarme « objectif atteint » -->
        <receiver
            android:name=".feature.timer.service.GoalAlarmReceiver"
            android:exported="false" />

        <!-- Remet notifications et alarmes des chronos après un redémarrage ou une mise à jour -->
        <receiver
            android:name=".feature.timer.service.TimerBootReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED" />
            </intent-filter>
        </receiver>
    </application>

</manifest>
EOF_VITRINE

write app/src/main/java/com/example/vitrine/data/local/db/AppDatabase.kt <<'EOF_VITRINE'
package com.example.vitrine.data.local.db

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.example.vitrine.data.local.db.entity.TaskEntity
import com.example.vitrine.data.local.db.entity.TimerSessionEntity
import com.example.vitrine.data.local.db.entity.TimerStateEntity

/**
 * Base de données locale de l'application.
 * Version 1 : tâches, sessions terminées et chronos en cours.
 * Version 2 : objectif de temps par tâche (colonne tasks.goalMillis).
 * Penser à ajouter une migration (et à monter la version) à chaque changement de schéma.
 */
@Database(
    entities = [TaskEntity::class, TimerSessionEntity::class, TimerStateEntity::class],
    version = 2,
    exportSchema = false,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun taskDao(): TaskDao
    abstract fun timerSessionDao(): TimerSessionDao
    abstract fun timerStateDao(): TimerStateDao

    companion object {
        /** Garde les tâches et l'historique existants : on ajoute seulement la colonne de l'objectif. */
        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE tasks ADD COLUMN goalMillis INTEGER")
            }
        }

        fun create(context: Context): AppDatabase =
            Room.databaseBuilder(context, AppDatabase::class.java, "vitrine.db")
                .addMigrations(MIGRATION_1_2)
                .build()
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/data/local/db/TaskDao.kt <<'EOF_VITRINE'
package com.example.vitrine.data.local.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import com.example.vitrine.data.local.db.entity.TaskEntity
import kotlinx.coroutines.flow.Flow

@Dao
abstract class TaskDao {

    @Query("SELECT * FROM tasks ORDER BY createdAt ASC")
    abstract fun observeAll(): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE id = :id")
    abstract suspend fun get(id: Long): TaskEntity?

    @Insert
    abstract suspend fun insert(task: TaskEntity): Long

    @Query("UPDATE tasks SET name = :name, goalMillis = :goalMillis WHERE id = :id")
    abstract suspend fun update(id: Long, name: String, goalMillis: Long?)

    @Query("DELETE FROM timer_sessions WHERE taskId = :taskId")
    abstract suspend fun deleteSessions(taskId: Long)

    @Query("DELETE FROM timer_states WHERE taskId = :taskId")
    abstract suspend fun deleteState(taskId: Long)

    @Query("DELETE FROM tasks WHERE id = :taskId")
    abstract suspend fun deleteTask(taskId: Long)

    /**
     * Supprime la tâche, son chrono et son historique en une seule transaction.
     * Explicite plutôt que de compter sur ON DELETE CASCADE, qui dépend de l'activation des clés étrangères.
     */
    @Transaction
    open suspend fun deleteWithHistory(taskId: Long) {
        deleteSessions(taskId)
        deleteState(taskId)
        deleteTask(taskId)
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/data/local/db/entity/TaskEntity.kt <<'EOF_VITRINE'
package com.example.vitrine.data.local.db.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.example.vitrine.domain.model.Task

@Entity(tableName = "tasks")
data class TaskEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0L,
    val name: String,
    val createdAt: Long,
    /** Ajouté en version 2 de la base (voir AppDatabase.MIGRATION_1_2). */
    val goalMillis: Long? = null,
)

fun TaskEntity.toDomain() = Task(id = id, name = name, createdAt = createdAt, goalMillis = goalMillis)
EOF_VITRINE

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

    override suspend fun addTask(name: String, createdAt: Long): Long =
        dao.insert(TaskEntity(name = name.trim(), createdAt = createdAt))

    override suspend fun updateTask(id: Long, name: String, goalMillis: Long?) =
        dao.update(id, name.trim(), goalMillis)

    override suspend fun deleteTask(id: Long) = dao.deleteWithHistory(id)
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/di/AppModule.kt <<'EOF_VITRINE'
package com.example.vitrine.di

import com.example.vitrine.MainViewModel
import com.example.vitrine.core.hardware.CameraTorchController
import com.example.vitrine.core.hardware.TorchController
import com.example.vitrine.core.util.Clock
import com.example.vitrine.data.local.db.AppDatabase
import com.example.vitrine.data.repository.TaskRepositoryImpl
import com.example.vitrine.data.repository.TimerRepositoryImpl
import com.example.vitrine.domain.alarm.GoalAlarmScheduler
import com.example.vitrine.domain.repository.TaskRepository
import com.example.vitrine.domain.repository.TimerRepository
import com.example.vitrine.domain.usecase.ReconstructTimersUseCase
import com.example.vitrine.feature.clock.usecase.GetCurrentTimeUseCase
import com.example.vitrine.feature.clock.viewmodel.ClockViewModel
import com.example.vitrine.feature.flashlight.usecase.SetScreenBrightnessUseCase
import com.example.vitrine.feature.flashlight.viewmodel.FlashlightViewModel
import com.example.vitrine.feature.text.viewmodel.TextViewModel
import com.example.vitrine.feature.timer.service.AndroidGoalAlarmScheduler
import com.example.vitrine.feature.timer.service.AndroidTimerNotifier
import com.example.vitrine.domain.notification.TimerNotifier
import com.example.vitrine.feature.timer.usecase.AddTaskUseCase
import com.example.vitrine.feature.timer.usecase.DeleteTaskUseCase
import com.example.vitrine.feature.timer.usecase.NotifyGoalReachedUseCase
import com.example.vitrine.feature.timer.usecase.ObserveTaskTimersUseCase
import com.example.vitrine.feature.timer.usecase.PauseTimerUseCase
import com.example.vitrine.feature.timer.usecase.StartTimerUseCase
import com.example.vitrine.feature.timer.usecase.StopTimerUseCase
import com.example.vitrine.feature.timer.usecase.UpdateTaskUseCase
import com.example.vitrine.feature.timer.viewmodel.TimerViewModel
import org.koin.android.ext.koin.androidContext
import org.koin.core.module.dsl.factoryOf
import org.koin.core.module.dsl.viewModelOf
import org.koin.dsl.module

val appModule = module {
    single { Clock.System }

    // Base de données Room
    single { AppDatabase.create(androidContext()) }
    single { get<AppDatabase>().taskDao() }
    single { get<AppDatabase>().timerSessionDao() }
    single { get<AppDatabase>().timerStateDao() }

    viewModelOf(::MainViewModel)
    viewModelOf(::TextViewModel)

    // Horloge
    factory { GetCurrentTimeUseCase() }
    viewModelOf(::ClockViewModel)

    // Lampe : un seul contrôleur de flash pour toute l'application
    single<TorchController> { CameraTorchController(androidContext()) }
    factory { SetScreenBrightnessUseCase() }
    viewModelOf(::FlashlightViewModel)

    // Chronos par tâche
    single<TaskRepository> { TaskRepositoryImpl(get()) }
    single<TimerRepository> { TimerRepositoryImpl(get(), get()) }
    single<TimerNotifier> { AndroidTimerNotifier(androidContext()) }
    single<GoalAlarmScheduler> { AndroidGoalAlarmScheduler(androidContext()) }
    factoryOf(::ObserveTaskTimersUseCase)
    factoryOf(::AddTaskUseCase)
    factoryOf(::StartTimerUseCase)
    factoryOf(::PauseTimerUseCase)
    factoryOf(::StopTimerUseCase)
    factoryOf(::UpdateTaskUseCase)
    factoryOf(::DeleteTaskUseCase)
    factoryOf(::NotifyGoalReachedUseCase)
    factoryOf(::ReconstructTimersUseCase)
    viewModelOf(::TimerViewModel)
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/domain/model/Task.kt <<'EOF_VITRINE'
package com.example.vitrine.domain.model

/**
 * Une tâche dont on mesure le temps (ex. « Révisions », « Sport »).
 *
 * @property goalMillis objectif de temps pour le chrono (ex. 25 min) ; null s'il n'y en a pas.
 *   Quand le chrono l'atteint, une alarme sonne ; le chrono, lui, continue de compter.
 */
data class Task(
    val id: Long,
    val name: String,
    val createdAt: Long,
    val goalMillis: Long? = null,
) {
    companion object {
        /** Un nom doit tenir sur une carte et dans une notification. */
        const val MAX_NAME_LENGTH = 40
    }
}

/**
 * Une tâche avec son chrono, prête à afficher.
 *
 * @property state chrono en cours ou en pause ; null s'il est à zéro.
 * @property sessionsMillis temps cumulé de toutes les sessions terminées.
 */
data class TaskTimer(
    val task: Task,
    val state: TimerState?,
    val sessionsMillis: Long,
) {
    val isRunning: Boolean get() = state?.isRunning == true

    /** Temps du chrono actuel (depuis la dernière remise à zéro). */
    fun currentMillis(now: Long): Long = state?.elapsedAt(now) ?: 0L

    /** Temps total passé sur la tâche, session en cours comprise. */
    fun totalMillis(now: Long): Long = sessionsMillis + (state?.runningPartAt(now) ?: 0L)
}

/**
 * Délai avant que le chrono atteigne l'objectif, s'il tourne.
 * Null s'il n'y a pas d'objectif, si le chrono est en pause, ou si l'objectif est déjà atteint :
 * dans ces cas, il n'y a pas d'alarme à programmer.
 */
fun millisUntilGoal(goalMillis: Long?, state: TimerState, now: Long): Long? {
    if (goalMillis == null || !state.isRunning) return null
    return (goalMillis - state.elapsedAt(now)).takeIf { it > 0 }
}

/**
 * Avancement vers l'objectif : 0 au départ, 1 à l'objectif, plus de 1 s'il est dépassé.
 * Null sans objectif.
 */
fun goalProgress(currentMillis: Long, goalMillis: Long?): Float? {
    if (goalMillis == null || goalMillis <= 0) return null
    return currentMillis.coerceAtLeast(0L).toFloat() / goalMillis
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/domain/notification/TimerNotifier.kt <<'EOF_VITRINE'
package com.example.vitrine.domain.notification

import com.example.vitrine.domain.model.Task
import com.example.vitrine.domain.model.TimerState

/**
 * Affiche ou retire la notification d'un chrono en cours.
 * Interface du domaine : les use cases ne dépendent pas d'Android ; l'implémentation est dans feature/timer/service.
 */
interface TimerNotifier {
    /** Notification persistante avec le temps qui défile (compteur système, sans réveiller l'app). */
    fun showRunning(task: Task, state: TimerState)

    fun cancel(taskId: Long)

    /** Notification sonore « objectif atteint » ; le chrono, lui, continue. */
    fun showGoalReached(task: Task)
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

    /** Crée une tâche et renvoie son identifiant. */
    suspend fun addTask(name: String, createdAt: Long): Long

    /** Change le nom et l'objectif d'une tâche (objectif null = aucun). */
    suspend fun updateTask(id: Long, name: String, goalMillis: Long?)

    /** Supprime la tâche avec son chrono et tout son historique. */
    suspend fun deleteTask(id: Long)
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/domain/usecase/ReconstructTimersUseCase.kt <<'EOF_VITRINE'
package com.example.vitrine.domain.usecase

import com.example.vitrine.domain.repository.TaskRepository
import com.example.vitrine.domain.repository.TimerRepository
import com.example.vitrine.core.util.Clock
import com.example.vitrine.domain.alarm.GoalAlarmScheduler
import com.example.vitrine.domain.model.millisUntilGoal
import com.example.vitrine.domain.notification.TimerNotifier

/**
 * Remet en place les notifications et les alarmes des chronos qui tournent, par exemple après
 * un redémarrage du téléphone (qui efface notifications et alarmes) ou au lancement de l'application.
 * Les chronos eux-mêmes n'ont rien à « rattraper » : leur heure de départ est enregistrée.
 */
class ReconstructTimersUseCase(
    private val tasks: TaskRepository,
    private val timers: TimerRepository,
    private val notifier: TimerNotifier,
    private val goalAlarm: GoalAlarmScheduler,
    private val clock: Clock,
) {
    suspend operator fun invoke() {
        val now = clock.now()
        timers.getRunningStates().forEach { state ->
            val task = tasks.getTask(state.taskId)
            if (task == null) {
                timers.deleteState(state.taskId)
                return@forEach
            }
            notifier.showRunning(task, state)
            // Objectif atteint pendant que le téléphone était éteint : rien à reprogrammer
            millisUntilGoal(task.goalMillis, state, now)?.let { delay -> goalAlarm.schedule(task.id, now + delay) }
        }
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/service/AndroidTimerNotifier.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.service

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.example.vitrine.MainActivity
import com.example.vitrine.R
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.core.navigation.EXTRA_DESTINATION
import com.example.vitrine.domain.model.Task
import com.example.vitrine.domain.model.TimerState
import com.example.vitrine.domain.notification.TimerNotifier
import com.example.vitrine.feature.timer.service.TimerNotifications.ACTION_PAUSE
import com.example.vitrine.feature.timer.service.TimerNotifications.ACTION_STOP
import com.example.vitrine.feature.timer.service.TimerNotifications.CHANNEL_ID
import com.example.vitrine.feature.timer.service.TimerNotifications.GOAL_CHANNEL_ID
import com.example.vitrine.feature.timer.service.TimerNotifications.goalNotificationId
import com.example.vitrine.core.util.formatTotal
import com.example.vitrine.feature.timer.service.TimerNotifications.EXTRA_TASK_ID
import com.example.vitrine.feature.timer.service.TimerNotifications.notificationId

/**
 * Notification d'un chrono en cours : nom de la tâche et temps qui défile.
 * Le temps est affiché par le compteur du système (setUsesChronometer) : l'application
 * n'a pas besoin de tourner en arrière-plan, ni d'un service au premier plan.
 * Boutons : Pause et Arrêter ; un appui ouvre l'écran des chronos.
 * Quand l'objectif d'une tâche est atteint, une seconde notification, sonore, prévient l'utilisateur.
 */
class AndroidTimerNotifier(
    private val context: Context,
) : TimerNotifier {

    private val manager = NotificationManagerCompat.from(context)

    init {
        manager.createNotificationChannelsCompat(
            listOf(
                // Chrono en cours : discret, sans son
                NotificationChannelCompat.Builder(CHANNEL_ID, NotificationManagerCompat.IMPORTANCE_LOW)
                    .setName(context.getString(R.string.timer_channel_name))
                    .setDescription(context.getString(R.string.timer_channel_description))
                    .setShowBadge(false)
                    .build(),
                // Objectif atteint : son, vibration et bandeau
                NotificationChannelCompat.Builder(GOAL_CHANNEL_ID, NotificationManagerCompat.IMPORTANCE_HIGH)
                    .setName(context.getString(R.string.timer_goal_channel_name))
                    .setDescription(context.getString(R.string.timer_goal_channel_description))
                    .setVibrationEnabled(true)
                    .build(),
            )
        )
    }

    @SuppressLint("MissingPermission") // vérifiée juste au-dessus avec canNotify()
    override fun showRunning(task: Task, state: TimerState) {
        if (!canNotify()) return
        val since = state.runningSince ?: return

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_timer)
            .setContentTitle(task.name)
            .setContentText(context.getString(R.string.timer_notification_running))
            // Le compteur affiche « maintenant − when » : on recule « when » du temps déjà compté
            .setWhen(since - state.accumulatedMillis)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setOngoing(true)
            .setSilent(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setContentIntent(openTimersIntent())
            .addAction(0, context.getString(R.string.timer_pause), actionIntent(ACTION_PAUSE, task.id))
            .addAction(0, context.getString(R.string.timer_stop), actionIntent(ACTION_STOP, task.id))
            .build()

        manager.notify(notificationId(task.id), notification)
    }

    override fun cancel(taskId: Long) {
        manager.cancel(notificationId(taskId))
        manager.cancel(goalNotificationId(taskId))
    }

    @SuppressLint("MissingPermission") // vérifiée juste au-dessus avec canNotify()
    override fun showGoalReached(task: Task) {
        if (!canNotify()) return
        val goal = task.goalMillis ?: return

        val notification = NotificationCompat.Builder(context, GOAL_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_timer)
            .setContentTitle(context.getString(R.string.timer_goal_reached_title))
            .setContentText(
                context.getString(R.string.timer_goal_reached_text, task.name, formatTotal(goal))
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setAutoCancel(true)
            .setContentIntent(openTimersIntent())
            .build()

        manager.notify(goalNotificationId(task.id), notification)
    }

    /** Avant Android 13, aucune permission n'est nécessaire ; ensuite, il faut POST_NOTIFICATIONS. */
    private fun canNotify(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    private fun openTimersIntent(): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .putExtra(EXTRA_DESTINATION, AppDestination.TIMER.name)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun actionIntent(action: String, taskId: Long): PendingIntent {
        val intent = Intent(context, TimerActionReceiver::class.java)
            .setAction(action)
            .putExtra(EXTRA_TASK_ID, taskId)
        // Code de requête différent par tâche et par bouton, sinon les PendingIntent se remplacent
        val requestCode = notificationId(taskId) * 2 + if (action == ACTION_PAUSE) 0 else 1
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/service/TimerBootReceiver.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.service

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.example.vitrine.domain.usecase.ReconstructTimersUseCase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * Après un redémarrage du téléphone (ou une mise à jour de l'application), notifications et alarmes
 * ont disparu : on les remet pour les chronos qui tournent encore.
 * Même chose quand l'utilisateur autorise les alarmes exactes : les alarmes sont reprogrammées à l'heure exacte.
 */
class TimerBootReceiver : BroadcastReceiver(), KoinComponent {

    private val reconstructTimers: ReconstructTimersUseCase by inject()

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in HANDLED_ACTIONS) return

        val pending = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                reconstructTimers()
            } finally {
                pending.finish()
            }
        }
    }

    private companion object {
        val HANDLED_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED,
        )
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/service/TimerNotifications.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.service

/** Identifiants partagés entre la notification et le récepteur de ses boutons. */
internal object TimerNotifications {
    const val CHANNEL_ID = "timers"
    const val GOAL_CHANNEL_ID = "timer_goals"
    const val ACTION_GOAL_REACHED = "com.example.vitrine.action.GOAL_REACHED"
    const val ACTION_PAUSE = "com.example.vitrine.action.PAUSE_TIMER"
    const val ACTION_STOP = "com.example.vitrine.action.STOP_TIMER"
    const val EXTRA_TASK_ID = "com.example.vitrine.extra.TASK_ID"

    /** Un identifiant de notification par tâche (décalé pour ne gêner aucune autre notification). */
    fun notificationId(taskId: Long): Int = 10_000 + (taskId % 1_000_000).toInt()

    /** Notification « objectif atteint » : distincte de celle du chrono, qui reste affichée. */
    fun goalNotificationId(taskId: Long): Int = 2_000_000 + (taskId % 1_000_000).toInt()
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/ui/TaskItem.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.vitrine.R
import com.example.vitrine.core.ui.components.StatusDot
import com.example.vitrine.core.ui.components.VitrineCard
import com.example.vitrine.core.util.formatStopwatch
import com.example.vitrine.core.util.formatTotal
import com.example.vitrine.feature.timer.ui.components.EditIcon
import com.example.vitrine.feature.timer.ui.components.GoalProgressBar
import com.example.vitrine.feature.timer.ui.components.PauseIcon
import com.example.vitrine.feature.timer.ui.components.PlayIcon
import com.example.vitrine.feature.timer.ui.components.RoundIconButton
import com.example.vitrine.feature.timer.ui.components.StopIcon
import com.example.vitrine.feature.timer.ui.components.goalColor
import com.example.vitrine.feature.timer.viewmodel.TaskTimerItem
import com.example.vitrine.ui.theme.VitrineColors

/**
 * Carte d'une tâche : nom, état et bouton Modifier ; grand chrono et boutons ;
 * barre d'objectif qui passe du vert au rouge ; temps total.
 * Un appui long ouvre aussi la modification.
 */
@Composable
fun TaskItem(
    item: TaskTimerItem,
    onToggle: () -> Unit,
    onReset: () -> Unit,
    onEdit: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val haptics = LocalHapticFeedback.current
    val editLabel = stringResource(R.string.timer_edit)
    val progress = item.goalProgress

    // Avec un objectif, le chrono prend la couleur de l'avancement (vert → rouge)
    val timeColor by animateColorAsState(
        targetValue = when {
            !item.canReset -> VitrineColors.TextMuted
            progress != null -> goalColor(progress)
            else -> VitrineColors.TextPrimary
        },
        label = "time-color",
    )

    VitrineCard(
        modifier = modifier
            .pointerInput(item.id) {
                detectTapGestures(onLongPress = {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    onEdit()
                })
            }
            .semantics {
                customActions = listOf(CustomAccessibilityAction(editLabel) { onEdit(); true })
            },
    ) {
        Header(item = item, editLabel = editLabel, onEdit = onEdit)

        Spacer(Modifier.height(4.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text(
                    text = formatStopwatch(item.currentMillis),
                    style = MaterialTheme.typography.headlineMedium.merge(
                        // Chiffres de même largeur : le temps ne « tremble » pas
                        TextStyle(fontFeatureSettings = "tnum"),
                    ),
                    color = timeColor,
                )
                Text(
                    text = stringResource(R.string.timer_total, formatTotal(item.totalMillis)),
                    style = MaterialTheme.typography.labelSmall,
                    color = VitrineColors.TextMuted,
                )
            }

            AnimatedVisibility(
                visible = item.canReset,
                enter = fadeIn() + scaleIn(),
                exit = fadeOut() + scaleOut(),
            ) {
                Row {
                    RoundIconButton(
                        contentDescription = stringResource(R.string.timer_reset),
                        background = VitrineColors.SurfaceMuted,
                        size = 40.dp,
                        onClick = onReset,
                    ) {
                        StopIcon(VitrineColors.TextPrimary, Modifier.size(18.dp))
                    }
                    Spacer(Modifier.width(10.dp))
                }
            }

            // Vert pour lancer, neutre pour mettre en pause
            RoundIconButton(
                contentDescription = stringResource(if (item.isRunning) R.string.timer_pause else R.string.timer_start),
                background = if (item.isRunning) VitrineColors.SurfaceMuted else VitrineColors.Accent,
                size = 52.dp,
                onClick = onToggle,
            ) {
                if (item.isRunning) {
                    PauseIcon(VitrineColors.TextPrimary, Modifier.size(22.dp))
                } else {
                    PlayIcon(VitrineColors.Surface, Modifier.size(22.dp))
                }
            }
        }

        val goal = item.goalMillis
        if (progress != null && goal != null) {
            Spacer(Modifier.height(10.dp))
            GoalProgressBar(progress = progress)
            Spacer(Modifier.height(4.dp))
            GoalCaption(item = item, goalMillis = goal, progress = progress)
        }
    }
}

/** Nom de la tâche, état (en cours, en pause, objectif atteint) et bouton Modifier. */
@Composable
private fun Header(
    item: TaskTimerItem,
    editLabel: String,
    onEdit: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = item.name,
            style = MaterialTheme.typography.titleMedium,
            color = VitrineColors.TextPrimary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        when {
            item.goalReached && item.isRunning ->
                StatusDot(stringResource(R.string.timer_goal_reached_status), VitrineColors.Danger)
            item.isRunning -> StatusDot(stringResource(R.string.timer_running), VitrineColors.Accent)
            item.canReset -> StatusDot(stringResource(R.string.timer_paused), VitrineColors.Warning)
        }
        RoundIconButton(
            contentDescription = editLabel,
            background = VitrineColors.SurfaceMuted,
            size = 32.dp,
            onClick = onEdit,
        ) {
            EditIcon(VitrineColors.TextPrimary, Modifier.size(14.dp))
        }
    }
}

/** « Objectif : 25 min » à gauche ; « Reste 12 min » ou « Dépassé de 3 min » à droite. */
@Composable
private fun GoalCaption(
    item: TaskTimerItem,
    goalMillis: Long,
    progress: Float,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = stringResource(R.string.timer_goal_caption, formatTotal(goalMillis)),
            style = MaterialTheme.typography.labelSmall,
            color = VitrineColors.TextMuted,
        )
        val difference = item.currentMillis - goalMillis
        Text(
            text = if (difference >= 0) {
                stringResource(R.string.timer_goal_exceeded, formatTotal(difference))
            } else {
                stringResource(R.string.timer_goal_remaining, formatTotal(-difference))
            },
            style = MaterialTheme.typography.labelSmall,
            color = if (difference >= 0) VitrineColors.Danger else goalColor(progress),
        )
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/ui/TimerScreen.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.ui

import android.Manifest
import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.feature.timer.ui.home.TimerHomeScreen
import com.example.vitrine.feature.timer.viewmodel.TimerViewModel
import org.koin.androidx.compose.koinViewModel

/**
 * Point d'entrée de la feature chronos : relie l'écran au ViewModel.
 * Seules les autorisations système restent ici (c'est de l'UI Android) :
 * - notifications : demandées au premier lancement d'un chrono (Android 13+) ;
 * - alarmes exactes : vérifiées à chaque retour sur l'écran (Android 12+), avec un lien vers le réglage.
 * Sans elles, les chronos fonctionnent : la notification manque, ou l'alarme peut être un peu retardée.
 */
@Composable
fun TimerScreen(
    onNavigate: (AppDestination) -> Unit,
    viewModel: TimerViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current

    // Notifications
    var permissionAsked by rememberSaveable { mutableStateOf(false) }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) viewModel.onNotificationPermissionGranted()
    }

    fun askNotificationPermissionOnce() {
        if (permissionAsked || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (!granted) {
            permissionAsked = true
            permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    // Alarmes exactes : revérifiées au retour du réglage système
    var exactAlarmAllowed by remember { mutableStateOf(context.canScheduleExactAlarms()) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) {
        exactAlarmAllowed = context.canScheduleExactAlarms()
    }

    TimerHomeScreen(
        state = state,
        onNewTaskNameChange = viewModel::onNewTaskNameChange,
        onAddTask = viewModel::addTask,
        onToggle = { item ->
            if (!item.isRunning) askNotificationPermissionOnce()
            viewModel.toggle(item)
        },
        onReset = viewModel::reset,
        onUpdate = viewModel::updateTask,
        onDelete = viewModel::delete,
        exactAlarmAllowed = exactAlarmAllowed,
        onAllowExactAlarm = { context.openExactAlarmSettings() },
        onNavigate = onNavigate,
    )
}

private fun Context.canScheduleExactAlarms(): Boolean =
    Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
        getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

/** Ouvre le réglage « Alarmes et rappels » de l'application (Android 12+). */
private fun Context.openExactAlarmSettings() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
    startActivity(
        Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName"))
    )
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/ui/components/TimerIcons.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke

/** Icônes plates des chronos, dessinées en code (aucune bibliothèque d'icônes nécessaire). */

/** Triangle « lecture », légèrement décalé à droite pour paraître centré. */
@Composable
fun PlayIcon(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val w = size.width
        val h = size.height
        val path = Path().apply {
            moveTo(w * 0.30f, h * 0.18f)
            lineTo(w * 0.84f, h * 0.50f)
            lineTo(w * 0.30f, h * 0.82f)
            close()
        }
        drawPath(path, color)
        drawPath(path, color, style = Stroke(width = w * 0.08f, join = StrokeJoin.Round))
    }
}

/** Deux barres arrondies « pause ». */
@Composable
fun PauseIcon(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val barWidth = size.width * 0.22f
        val radius = CornerRadius(barWidth / 2)
        listOf(0.22f, 0.56f).forEach { x ->
            drawRoundRect(
                color = color,
                topLeft = Offset(size.width * x, size.height * 0.18f),
                size = Size(barWidth, size.height * 0.64f),
                cornerRadius = radius,
            )
        }
    }
}

/** Carré arrondi « arrêt ». */
@Composable
fun StopIcon(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val side = size.minDimension * 0.56f
        drawRoundRect(
            color = color,
            topLeft = Offset((size.width - side) / 2, (size.height - side) / 2),
            size = Size(side, side),
            cornerRadius = CornerRadius(side * 0.22f),
        )
    }
}

/** Croix « ajouter ». */
@Composable
fun PlusIcon(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val stroke = size.minDimension * 0.14f
        val inset = size.minDimension * 0.18f
        drawLine(color, Offset(center.x, inset), Offset(center.x, size.height - inset), stroke, StrokeCap.Round)
        drawLine(color, Offset(inset, center.y), Offset(size.width - inset, center.y), stroke, StrokeCap.Round)
    }
}

/** Trait « moins », dans le même style que la croix « ajouter ». */
@Composable
fun MinusIcon(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val stroke = size.minDimension * 0.14f
        val inset = size.minDimension * 0.18f
        drawLine(color, Offset(inset, center.y), Offset(size.width - inset, center.y), stroke, StrokeCap.Round)
    }
}

/** Crayon « modifier » : un trait épais en diagonale avec une pointe. */
@Composable
fun EditIcon(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val stroke = size.minDimension * 0.14f
        val start = Offset(size.width * 0.24f, size.height * 0.76f)
        val end = Offset(size.width * 0.74f, size.height * 0.26f)
        drawLine(color, start, end, stroke, StrokeCap.Round)
        // Pointe du crayon
        drawLine(
            color,
            Offset(size.width * 0.16f, size.height * 0.84f),
            Offset(size.width * 0.20f, size.height * 0.80f),
            stroke,
            StrokeCap.Round,
        )
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

write app/src/main/java/com/example/vitrine/feature/timer/usecase/PauseTimerUseCase.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
import com.example.vitrine.domain.alarm.GoalAlarmScheduler
import com.example.vitrine.domain.model.TimerSession
import com.example.vitrine.domain.repository.TimerRepository
import com.example.vitrine.domain.notification.TimerNotifier

/**
 * Met le chrono d'une tâche en pause : la période écoulée devient une session de l'historique
 * et s'ajoute au temps du chrono, qui pourra repartir de là.
 */
class PauseTimerUseCase(
    private val timers: TimerRepository,
    private val notifier: TimerNotifier,
    private val goalAlarm: GoalAlarmScheduler,
    private val clock: Clock,
) {
    suspend operator fun invoke(taskId: Long) {
        val current = timers.getState(taskId) ?: return
        val since = current.runningSince ?: return
        val now = clock.now()

        timers.closeSession(
            session = TimerSession(taskId = taskId, startedAt = since, endedAt = now),
            newState = current.copy(
                accumulatedMillis = current.elapsedAt(now),
                runningSince = null,
            ),
        )
        notifier.cancel(taskId)
        goalAlarm.cancel(taskId) // en pause, l'objectif ne peut pas être atteint
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/usecase/StartTimerUseCase.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
import com.example.vitrine.domain.alarm.GoalAlarmScheduler
import com.example.vitrine.domain.model.TimerState
import com.example.vitrine.domain.model.millisUntilGoal
import com.example.vitrine.domain.repository.TaskRepository
import com.example.vitrine.domain.repository.TimerRepository
import com.example.vitrine.domain.notification.TimerNotifier

/**
 * Lance (ou relance après une pause) le chrono d'une tâche et affiche sa notification.
 * On ne fait qu'une tâche à la fois : le chrono qui tournait sur une autre tâche est mis en pause
 * (son temps est gardé, il pourra repartir de là).
 * Si la tâche a un objectif pas encore atteint, l'alarme est programmée pour l'heure où il le sera.
 */
class StartTimerUseCase(
    private val tasks: TaskRepository,
    private val timers: TimerRepository,
    private val pauseTimer: PauseTimerUseCase,
    private val notifier: TimerNotifier,
    private val goalAlarm: GoalAlarmScheduler,
    private val clock: Clock,
) {
    suspend operator fun invoke(taskId: Long) {
        val task = tasks.getTask(taskId) ?: return
        val current = timers.getState(taskId) ?: TimerState(taskId)
        if (current.isRunning) return

        timers.getRunningStates()
            .filter { it.taskId != taskId }
            .forEach { other -> pauseTimer(other.taskId) }

        val now = clock.now()
        val running = current.copy(runningSince = now)
        timers.saveState(running)
        notifier.showRunning(task, running)
        millisUntilGoal(task.goalMillis, running, now)?.let { delay -> goalAlarm.schedule(taskId, now + delay) }
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/usecase/StopTimerUseCase.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
import com.example.vitrine.domain.alarm.GoalAlarmScheduler
import com.example.vitrine.domain.model.TimerSession
import com.example.vitrine.domain.repository.TimerRepository
import com.example.vitrine.domain.notification.TimerNotifier

/**
 * Arrête le chrono d'une tâche et le remet à zéro.
 * La période en cours est gardée dans l'historique : le temps total de la tâche ne diminue pas.
 */
class StopTimerUseCase(
    private val timers: TimerRepository,
    private val notifier: TimerNotifier,
    private val goalAlarm: GoalAlarmScheduler,
    private val clock: Clock,
) {
    suspend operator fun invoke(taskId: Long) {
        val current = timers.getState(taskId) ?: return
        val since = current.runningSince

        if (since != null) {
            val session = TimerSession(taskId = taskId, startedAt = since, endedAt = clock.now())
            timers.closeSession(session, newState = null)
        } else {
            timers.deleteState(taskId)
        }
        notifier.cancel(taskId)
        goalAlarm.cancel(taskId)
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
    /** Objectif de temps du chrono ; null s'il n'y en a pas. */
    val goalMillis: Long? = null,
) {
    /** Vrai si le chrono n'est pas à zéro (en cours ou en pause) : on peut le remettre à zéro. */
    val canReset: Boolean get() = isRunning || currentMillis > 0

    /** Avancement vers l'objectif (0 → 1, plus de 1 s'il est dépassé) ; null sans objectif. */
    val goalProgress: Float? get() = goalProgress(currentMillis, goalMillis)

    val goalReached: Boolean get() = (goalProgress ?: 0f) >= 1f
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

    fun addTask() {
        val name = newTaskName.value
        if (name.isBlank()) return
        savedState[KEY_NEW_TASK_NAME] = ""
        viewModelScope.launch { addTaskUseCase(name) }
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

    /** Nouveau nom et nouvel objectif (null = sans objectif). */
    fun updateTask(taskId: Long, name: String, goalMillis: Long?) {
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

write app/src/main/java/com/example/vitrine/ui/theme/Color.kt <<'EOF_VITRINE'
package com.example.vitrine.ui.theme

import androidx.annotation.ColorRes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.colorResource
import com.example.vitrine.R

/** Vrai quand le thème sombre est actif. Fourni par [VitrineTheme]. */
internal val LocalVitrineDarkTheme = staticCompositionLocalOf { false }

/** Lit la couleur claire ou sombre selon le thème actif (pas celui du téléphone). */
@Composable
private fun themed(@ColorRes light: Int, @ColorRes dark: Int): Color =
    colorResource(if (LocalVitrineDarkTheme.current) dark else light)

/**
 * Palette de l'application, lue depuis res/values/colors_vitrine.xml.
 * C'est la seule source de couleurs de l'interface : tous les écrans passent par ici.
 * Chaque couleur existe en version claire et sombre ; la bonne est choisie selon le thème actif.
 */
object VitrineColors {
    /** Fond des écrans. */
    val Background: Color
        @Composable get() = themed(R.color.vitrine_light_background, R.color.vitrine_dark_background)

    /** Fond des cartes et du menu. */
    val Surface: Color
        @Composable get() = themed(R.color.vitrine_light_surface, R.color.vitrine_dark_surface)

    /** Élément sélectionné, boutons ronds, zones en retrait. */
    val SurfaceMuted: Color
        @Composable get() = themed(R.color.vitrine_light_surface_muted, R.color.vitrine_dark_surface_muted)

    /** Contours discrets, LEDs éteintes de l'aperçu. */
    val Divider: Color
        @Composable get() = themed(R.color.vitrine_light_divider, R.color.vitrine_dark_divider)

    val TextPrimary: Color
        @Composable get() = themed(R.color.vitrine_light_text_primary, R.color.vitrine_dark_text_primary)

    val TextMuted: Color
        @Composable get() = themed(R.color.vitrine_light_text_muted, R.color.vitrine_dark_text_muted)

    /** Vert : état actif, curseur, actions. */
    val Accent: Color
        @Composable get() = themed(R.color.vitrine_light_accent, R.color.vitrine_dark_accent)

    /** Ambre : attention, en pause, objectif bientôt atteint. */
    val Warning: Color
        @Composable get() = themed(R.color.vitrine_light_warning, R.color.vitrine_dark_warning)

    /** Rouge : objectif dépassé, action destructive (suppression). */
    val Danger: Color
        @Composable get() = themed(R.color.vitrine_light_danger, R.color.vitrine_dark_danger)
}
EOF_VITRINE

write app/src/main/res/values/colors_vitrine.xml <<'EOF_VITRINE'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!--
        Interface, design plat. Deux palettes : claire et sombre.
        VitrineColors choisit la bonne selon le thème actif (automatique, clair ou sombre),
        ce qui permet de forcer un thème différent de celui du téléphone.
    -->

    <!-- Mode clair -->
    <color name="vitrine_light_background">#FFF1F1F1</color>     <!-- fond des écrans -->
    <color name="vitrine_light_surface">#FFFFFFFF</color>        <!-- cartes, menu -->
    <color name="vitrine_light_surface_muted">#FFF0F0F0</color>  <!-- élément sélectionné -->
    <color name="vitrine_light_divider">#FFE6E6E6</color>        <!-- contours discrets, LEDs éteintes -->
    <color name="vitrine_light_text_primary">#FF111111</color>
    <color name="vitrine_light_text_muted">#FF8E8E93</color>
    <color name="vitrine_light_accent">#FF4CA34A</color>         <!-- vert : état actif -->
    <color name="vitrine_light_warning">#FFE3A43A</color>        <!-- ambre : attention -->
    <color name="vitrine_light_danger">#FFE5484D</color>         <!-- rouge : objectif dépassé, suppression -->

    <!-- Mode sombre -->
    <color name="vitrine_dark_background">#FF0E0E10</color>
    <color name="vitrine_dark_surface">#FF1C1C1E</color>
    <color name="vitrine_dark_surface_muted">#FF2C2C2E</color>
    <color name="vitrine_dark_divider">#FF3A3A3C</color>
    <color name="vitrine_dark_text_primary">#FFF5F5F7</color>
    <color name="vitrine_dark_text_muted">#FF8E8E93</color>
    <color name="vitrine_dark_accent">#FF5DBB5A</color>
    <color name="vitrine_dark_warning">#FFF0B44C</color>
    <color name="vitrine_dark_danger">#FFFF6369</color>

    <!-- Guirlande de LEDs (l'aperçu utilise les couleurs de l'interface) -->
    <color name="led_base_display">#FF0A0A0A</color>       <!-- support (plein écran) -->
    <color name="led_off_display">#FF1E1E1E</color>        <!-- LED éteinte (plein écran) -->
    <color name="led_color_1">#FF4CA34A</color>
    <color name="led_color_2">#FFE3A43A</color>
    <color name="led_color_3">#FFE86F5C</color>
    <color name="led_color_4">#FF4C8DF6</color>

    <!-- Couleurs de la lampe (lumière d'écran) -->
    <color name="light_white">#FFFFFFFF</color>
    <color name="light_warm">#FFFFD9A0</color>   <!-- blanc chaud, comme une ampoule -->
    <color name="light_cool">#FFD6ECFF</color>   <!-- blanc froid, comme la lumière du jour -->
    <color name="light_red">#FFFF2A1F</color>    <!-- préserve la vision de nuit -->

    <!-- Couleurs proposées pour le texte du message -->
    <color name="text_white">#FFFFFFFF</color>
    <color name="text_yellow">#FFFFFF00</color>
    <color name="text_green">#FF00FF00</color>
    <color name="text_red">#FFFF0000</color>

    <!-- Couleurs proposées pour le fond du message -->
    <color name="bg_black">#FF000000</color>
    <color name="bg_night_blue">#FF001133</color>
    <color name="bg_night_red">#FF220000</color>
    <color name="bg_white">#FFFFFFFF</color>
</resources>
EOF_VITRINE

write app/src/main/res/values/strings_timer.xml <<'EOF_VITRINE'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Feature chronos par tâche (le titre timer_title est dans strings_menu.xml) -->
    <string name="timer_new_task_placeholder">Nouvelle tâche…</string>
    <string name="timer_add_task">Ajouter la tâche</string>

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

write app/src/test/java/com/example/vitrine/domain/model/TimerStateTest.kt <<'EOF_VITRINE'
package com.example.vitrine.domain.model

import org.junit.Assert.assertEquals
import org.junit.Test

class TimerStateTest {

    @Test
    fun `en pause le temps ne bouge plus`() {
        val state = TimerState(taskId = 1, accumulatedMillis = 30_000, runningSince = null)
        assertEquals(30_000L, state.elapsedAt(now = 999_999_999))
    }

    @Test
    fun `si l'heure du telephone recule, le chrono ne devient pas negatif`() {
        val state = TimerState(taskId = 1, accumulatedMillis = 10_000, runningSince = 50_000)
        assertEquals(10_000L, state.elapsedAt(now = 20_000))
    }

    @Test
    fun `total de la tache avec session en cours`() {
        val timer = TaskTimer(
            task = Task(1, "Sport", 0),
            state = TimerState(1, accumulatedMillis = 60_000, runningSince = 100_000),
            sessionsMillis = 600_000,
        )
        assertEquals(90_000L, timer.currentMillis(now = 130_000))
        assertEquals(630_000L, timer.totalMillis(now = 130_000))
    }

    @Test
    fun `avancement vers l'objectif`() {
        assertEquals(null, goalProgress(10_000, null))
        assertEquals(0.5f, goalProgress(30_000, 60_000)!!, 0.0001f)
        assertEquals(1.5f, goalProgress(90_000, 60_000)!!, 0.0001f)
    }

    @Test
    fun `delai avant l'objectif`() {
        val running = TimerState(1, accumulatedMillis = 10_000, runningSince = 100_000)
        assertEquals(40_000L, millisUntilGoal(60_000, running, now = 110_000))
        assertEquals(null, millisUntilGoal(60_000, running.copy(runningSince = null), now = 110_000))
        assertEquals(null, millisUntilGoal(15_000, running, now = 110_000)) // déjà atteint
        assertEquals(null, millisUntilGoal(null, running, now = 110_000))
    }
}
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
EOF_VITRINE

write app/src/test/java/com/example/vitrine/feature/timer/usecase/TimerUseCasesTest.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.domain.usecase.ReconstructTimersUseCase
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class TimerUseCasesTest {

    private lateinit var clock: FakeClock
    private lateinit var tasks: FakeTaskRepository
    private lateinit var timers: FakeTimerRepository
    private lateinit var notifier: FakeTimerNotifier
    private lateinit var alarms: FakeGoalAlarmScheduler
    private lateinit var start: StartTimerUseCase
    private lateinit var pause: PauseTimerUseCase
    private lateinit var stop: StopTimerUseCase
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
        taskId = tasks.addTask("Révisions", clock.now())
    }

    @Test
    fun `lancer un chrono enregistre l'heure de depart et affiche la notification`() = runBlocking {
        start(taskId)
        val state = timers.getState(taskId)!!
        assertEquals(1_000_000L, state.runningSince)
        assertTrue(notifier.shown.containsKey(taskId))
    }

    @Test
    fun `la pause cumule le temps et cree une session`() = runBlocking {
        start(taskId)
        clock.time += 90_000 // 1 min 30
        pause(taskId)

        val state = timers.getState(taskId)!!
        assertFalse(state.isRunning)
        assertEquals(90_000L, state.accumulatedMillis)
        assertEquals(1, timers.sessions.size)
        assertFalse(notifier.shown.containsKey(taskId))
    }

    @Test
    fun `relancer apres une pause reprend ou on en etait`() = runBlocking {
        start(taskId)
        clock.time += 60_000
        pause(taskId)
        clock.time += 600_000 // 10 min de pause : ne comptent pas
        start(taskId)
        clock.time += 30_000

        assertEquals(90_000L, timers.getState(taskId)!!.elapsedAt(clock.now()))
    }

    @Test
    fun `arreter remet a zero mais garde le temps dans l'historique`() = runBlocking {
        start(taskId)
        clock.time += 45_000
        stop(taskId)

        assertNull(timers.getState(taskId))
        assertEquals(45_000L, timers.sessions.sumOf { it.durationMillis })
        assertFalse(notifier.shown.containsKey(taskId))
    }

    @Test
    fun `le chrono continue de compter sans que rien ne tourne`() = runBlocking {
        start(taskId)
        clock.time += 3 * 3_600_000L // téléphone éteint pendant 3 h
        assertEquals(3 * 3_600_000L, timers.getState(taskId)!!.elapsedAt(clock.now()))
    }

    @Test
    fun `apres un redemarrage les notifications des chronos en cours reviennent`() = runBlocking {
        start(taskId)
        notifier.shown.clear() // le redémarrage efface les notifications
        ReconstructTimersUseCase(tasks, timers, notifier, alarms, clock)()
        assertTrue(notifier.shown.containsKey(taskId))
    }

    @Test
    fun `un seul chrono a la fois - lancer une tache met l'autre en pause`() = runBlocking {
        val otherId = tasks.addTask("Sport", clock.now())
        start(taskId)
        clock.time += 120_000 // 2 min sur « Révisions »
        start(otherId)

        val first = timers.getState(taskId)!!
        assertFalse(first.isRunning)
        assertEquals(120_000L, first.accumulatedMillis) // le temps est gardé
        assertTrue(timers.getState(otherId)!!.isRunning)
        assertEquals(listOf(otherId), timers.getRunningStates().map { it.taskId })
        assertEquals(setOf(otherId), notifier.shown.keys) // une seule notification
    }

    @Test
    fun `lancer deux fois ne remet pas l'heure de depart a jour`() = runBlocking {
        start(taskId)
        clock.time += 5_000
        start(taskId)
        assertEquals(1_000_000L, timers.getState(taskId)!!.runningSince)
    }
}
EOF_VITRINE

echo
echo "Terminé. Dans Android Studio : File > Sync Project with Gradle Files, puis Build > Rebuild Project."
