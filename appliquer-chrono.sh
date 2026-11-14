#!/usr/bin/env bash
# Ajoute les chronos par tâche à Vitrine (Room, notification, redémarrage).
# À lancer depuis la racine du projet VITRINE, après appliquer-lampe.sh.
# Pensez à faire un commit avant : les fichiers existants sont écrasés.
# Modifie aussi le build (Room + KSP) : faites un Sync Gradle ensuite.
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

echo "Suppression :"
remove app/src/main/java/com/example/vitrine/core/ui/components/ComingSoonCard.kt
remove app/src/main/java/com/example/vitrine/feature/timer/service/TimerForegroundService.kt

echo "Création :"
write app/src/main/java/com/example/vitrine/core/util/Clock.kt <<'EOF_VITRINE'
package com.example.vitrine.core.util

/** Source de l'heure (millisecondes depuis 1970), remplaçable dans les tests. */
fun interface Clock {
    fun now(): Long

    companion object {
        val System = Clock { java.lang.System.currentTimeMillis() }
    }
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
import com.example.vitrine.feature.timer.service.TimerNotifications.EXTRA_TASK_ID
import com.example.vitrine.feature.timer.service.TimerNotifications.notificationId

/**
 * Notification d'un chrono en cours : nom de la tâche et temps qui défile.
 * Le temps est affiché par le compteur du système (setUsesChronometer) : l'application
 * n'a pas besoin de tourner en arrière-plan, ni d'un service au premier plan.
 * Boutons : Pause et Arrêter ; un appui ouvre l'écran des chronos.
 */
class AndroidTimerNotifier(
    private val context: Context,
) : TimerNotifier {

    private val manager = NotificationManagerCompat.from(context)

    init {
        manager.createNotificationChannel(
            NotificationChannelCompat.Builder(CHANNEL_ID, NotificationManagerCompat.IMPORTANCE_LOW)
                .setName(context.getString(R.string.timer_channel_name))
                .setDescription(context.getString(R.string.timer_channel_description))
                .setShowBadge(false)
                .build()
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

write app/src/main/java/com/example/vitrine/feature/timer/service/TimerActionReceiver.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.example.vitrine.feature.timer.service.TimerNotifications.ACTION_PAUSE
import com.example.vitrine.feature.timer.service.TimerNotifications.ACTION_STOP
import com.example.vitrine.feature.timer.service.TimerNotifications.EXTRA_TASK_ID
import com.example.vitrine.feature.timer.usecase.PauseTimerUseCase
import com.example.vitrine.feature.timer.usecase.StopTimerUseCase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/** Reçoit les boutons Pause et Arrêter de la notification, même application fermée. */
class TimerActionReceiver : BroadcastReceiver(), KoinComponent {

    private val pauseTimer: PauseTimerUseCase by inject()
    private val stopTimer: StopTimerUseCase by inject()

    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getLongExtra(EXTRA_TASK_ID, -1L).takeIf { it >= 0 } ?: return
        val action = intent.action ?: return

        // L'écriture en base est asynchrone : on garde le récepteur en vie jusqu'à la fin
        val pending = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                when (action) {
                    ACTION_PAUSE -> pauseTimer(taskId)
                    ACTION_STOP -> stopTimer(taskId)
                }
            } finally {
                pending.finish()
            }
        }
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/service/TimerBootReceiver.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.service

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
 * Après un redémarrage du téléphone (ou une mise à jour de l'application), les notifications
 * ont disparu : on les remet pour les chronos qui tournent encore.
 */
class TimerBootReceiver : BroadcastReceiver(), KoinComponent {

    private val reconstructTimers: ReconstructTimersUseCase by inject()

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) return

        val pending = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                reconstructTimers()
            } finally {
                pending.finish()
            }
        }
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/service/TimerNotifications.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.service

/** Identifiants partagés entre la notification et le récepteur de ses boutons. */
internal object TimerNotifications {
    const val CHANNEL_ID = "timers"
    const val ACTION_PAUSE = "com.example.vitrine.action.PAUSE_TIMER"
    const val ACTION_STOP = "com.example.vitrine.action.STOP_TIMER"
    const val EXTRA_TASK_ID = "com.example.vitrine.extra.TASK_ID"

    /** Un identifiant de notification par tâche (décalé pour ne gêner aucune autre notification). */
    fun notificationId(taskId: Long): Int = 10_000 + (taskId % 1_000_000).toInt()
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/ui/components/RoundIconButton.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp

/** Bouton rond plat contenant une icône dessinée. */
@Composable
fun RoundIconButton(
    contentDescription: String,
    background: Color,
    size: Dp,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    icon: @Composable () -> Unit,
) {
    Box(
        modifier = modifier
            .size(size)
            .alpha(if (enabled) 1f else 0.4f)
            .clip(CircleShape)
            .background(background)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        icon()
    }
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
    onDelete: (Long) -> Unit,
    onNavigate: (AppDestination) -> Unit,
) {
    // Tâche dont on demande la suppression (dialogue de confirmation)
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
                        onDeleteRequest = { pendingDeleteId = item.id },
                        modifier = Modifier.animateItem(),
                    )
                }
            }
        }
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
                Text(stringResource(R.string.timer_delete), color = VitrineColors.Warning)
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

write app/src/main/java/com/example/vitrine/feature/timer/ui/model/DurationFormat.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.ui.model

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

write app/src/main/res/drawable/ic_stat_timer.xml <<'EOF_VITRINE'
<?xml version="1.0" encoding="utf-8"?>
<!-- Icône de notification des chronos : un chronomètre plat, blanc (Android le teinte). -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M9,1h6v2H9z" />
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M12,4C7.03,4 3,8.03 3,13s4.03,9 9,9 9,-4.03 9,-9 -4.03,-9 -9,-9zM12,20c-3.87,0 -7,-3.13 -7,-7s3.13,-7 7,-7 7,3.13 7,7 -3.13,7 -7,7z" />
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M11,8h2v6h-2z" />
</vector>
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

    <string name="timer_delete">Supprimer</string>
    <string name="timer_delete_title">Supprimer « %1$s » ?</string>
    <string name="timer_delete_body">La tâche, son chrono et tout son historique seront effacés.</string>
    <string name="timer_cancel">Annuler</string>

    <!-- Notification -->
    <string name="timer_channel_name">Chronos en cours</string>
    <string name="timer_channel_description">Affiche le temps des chronos qui tournent.</string>
    <string name="timer_notification_running">Chrono en cours</string>
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
}
EOF_VITRINE

write app/src/test/java/com/example/vitrine/feature/timer/ui/model/DurationFormatTest.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.ui.model

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

write app/src/test/java/com/example/vitrine/feature/timer/usecase/Fakes.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
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
    override fun showRunning(task: Task, state: TimerState) {
        shown[task.id] = state
    }
    override fun cancel(taskId: Long) {
        shown.remove(taskId)
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
        start = StartTimerUseCase(tasks, timers, notifier, clock)
        pause = PauseTimerUseCase(timers, notifier, clock)
        stop = StopTimerUseCase(timers, notifier, clock)
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
        ReconstructTimersUseCase(tasks, timers, notifier)()
        assertTrue(notifier.shown.containsKey(taskId))
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

echo "Remplacement :"
write app/build.gradle.kts <<'EOF_VITRINE'
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
}

android {
    namespace = "com.example.vitrine"
    compileSdk {
        version = release(37)
    }

    defaultConfig {
        applicationId = "com.example.vitrine"
        minSdk = 24
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            optimization {
                enable = true
                packageScope = setOf("androidx.**", "kotlin.**", "kotlinx.**")
            }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)

    // Cycle de vie (collectAsStateWithLifecycle + ViewModel Compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)

    // DataStore pour la persistance du texte et des couleurs
    implementation(libs.androidx.datastore.preferences)

    // Koin (injection de dépendances)
    implementation(libs.koin.android)
    implementation(libs.koin.androidx.compose)

    // Room (chronos par tâche : tâches, sessions, chronos en cours)
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)

    testImplementation(libs.junit)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(libs.androidx.junit)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
    debugImplementation(libs.androidx.compose.ui.tooling)
}
EOF_VITRINE

write app/src/main/AndroidManifest.xml <<'EOF_VITRINE'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <!-- Chronos : notification du temps qui défile (Android 13+) et retour après redémarrage -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

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

        <!-- Remet les notifications des chronos après un redémarrage ou une mise à jour -->
        <receiver
            android:name=".feature.timer.service.TimerBootReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
            </intent-filter>
        </receiver>
    </application>

</manifest>
EOF_VITRINE

write app/src/main/java/com/example/vitrine/App.kt <<'EOF_VITRINE'
package com.example.vitrine

import android.app.Application
import com.example.vitrine.di.appModule
import com.example.vitrine.domain.usecase.ReconstructTimersUseCase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.koin.android.ext.android.get
import org.koin.android.ext.koin.androidContext
import org.koin.android.ext.koin.androidLogger
import org.koin.core.context.startKoin

class App : Application() {

    /** Travail de fond lié à la vie de l'application (pas à un écran). */
    private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onCreate() {
        super.onCreate()
        startKoin {
            androidLogger()
            androidContext(this@App)
            modules(appModule)
        }

        // Si une notification de chrono a été balayée ou perdue, on la remet au lancement
        val reconstructTimers: ReconstructTimersUseCase = get()
        appScope.launch { reconstructTimers() }
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/core/navigation/AppDestination.kt <<'EOF_VITRINE'
package com.example.vitrine.core.navigation

import androidx.annotation.StringRes
import com.example.vitrine.R

/** Les fonctionnalités de l'application, telles qu'elles apparaissent dans le menu. */
enum class AppDestination(@StringRes val label: Int) {
    TEXT(R.string.menu_text),
    CLOCK(R.string.menu_clock),
    FLASHLIGHT(R.string.menu_flashlight),
    TIMER(R.string.menu_timer),
}

/**
 * Extra d'Intent qui ouvre l'application directement sur un écran (valeur : nom d'un [AppDestination]).
 * Utilisé par la notification des chronos.
 */
const val EXTRA_DESTINATION = "com.example.vitrine.extra.DESTINATION"
EOF_VITRINE

write app/src/main/java/com/example/vitrine/core/navigation/VitrineApp.kt <<'EOF_VITRINE'
package com.example.vitrine.core.navigation

import android.content.Intent
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalContext
import androidx.core.util.Consumer
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.example.vitrine.feature.clock.ui.ClockScreen
import com.example.vitrine.feature.flashlight.ui.FlashlightScreen
import com.example.vitrine.feature.text.ui.TextScreen
import com.example.vitrine.feature.timer.ui.TimerScreen

/**
 * Racine de l'application : affiche l'écran de la fonctionnalité choisie dans le menu.
 * L'écran courant survit à la rotation. Le bouton retour ramène à l'écran Texte.
 * Un Intent avec [EXTRA_DESTINATION] (ex. la notification d'un chrono) ouvre directement un écran,
 * au lancement comme quand l'application est déjà ouverte.
 */
@Composable
fun VitrineApp() {
    val activity = LocalContext.current as? ComponentActivity
    var destination by rememberSaveable {
        mutableStateOf(activity?.intent?.toDestination() ?: AppDestination.TEXT)
    }
    val navigate: (AppDestination) -> Unit = { destination = it }

    DisposableEffect(activity) {
        val listener = Consumer<Intent> { intent ->
            intent.toDestination()?.let { destination = it }
        }
        activity?.addOnNewIntentListener(listener)
        onDispose { activity?.removeOnNewIntentListener(listener) }
    }

    // Déclaré avant les écrans : un écran peut ainsi intercepter le retour en priorité
    // (ex. quitter le plein écran avant de changer d'écran).
    BackHandler(enabled = destination != AppDestination.TEXT) {
        destination = AppDestination.TEXT
    }

    when (destination) {
        AppDestination.TEXT -> TextScreen(onNavigate = navigate)
        AppDestination.CLOCK -> ClockScreen(onNavigate = navigate)
        AppDestination.FLASHLIGHT -> FlashlightScreen(onNavigate = navigate)
        AppDestination.TIMER -> TimerScreen(onNavigate = navigate)
    }
}

private fun Intent.toDestination(): AppDestination? =
    getStringExtra(EXTRA_DESTINATION)?.let { name -> AppDestination.entries.firstOrNull { it.name == name } }
EOF_VITRINE

write app/src/main/java/com/example/vitrine/data/local/db/AppDatabase.kt <<'EOF_VITRINE'
package com.example.vitrine.data.local.db

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.example.vitrine.data.local.db.entity.TaskEntity
import com.example.vitrine.data.local.db.entity.TimerSessionEntity
import com.example.vitrine.data.local.db.entity.TimerStateEntity

/**
 * Base de données locale de l'application.
 * Version 1 : tâches, sessions terminées et chronos en cours.
 * Penser à ajouter une migration (et à monter la version) à chaque changement de schéma.
 */
@Database(
    entities = [TaskEntity::class, TimerSessionEntity::class, TimerStateEntity::class],
    version = 1,
    exportSchema = false,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun taskDao(): TaskDao
    abstract fun timerSessionDao(): TimerSessionDao
    abstract fun timerStateDao(): TimerStateDao

    companion object {
        fun create(context: Context): AppDatabase =
            Room.databaseBuilder(context, AppDatabase::class.java, "vitrine.db").build()
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

write app/src/main/java/com/example/vitrine/data/local/db/TimerSessionDao.kt <<'EOF_VITRINE'
package com.example.vitrine.data.local.db

import androidx.room.Dao
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

/** Temps cumulé des sessions terminées d'une tâche. */
data class TaskSessionTotal(
    val taskId: Long,
    val totalMillis: Long,
)

@Dao
interface TimerSessionDao {

    @Query("SELECT taskId, SUM(endedAt - startedAt) AS totalMillis FROM timer_sessions GROUP BY taskId")
    fun observeTotals(): Flow<List<TaskSessionTotal>>
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/data/local/db/TimerStateDao.kt <<'EOF_VITRINE'
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
)

fun TaskEntity.toDomain() = Task(id = id, name = name, createdAt = createdAt)
EOF_VITRINE

write app/src/main/java/com/example/vitrine/data/local/db/entity/TimerSessionEntity.kt <<'EOF_VITRINE'
package com.example.vitrine.data.local.db.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.example.vitrine.domain.model.TimerSession

@Entity(
    tableName = "timer_sessions",
    foreignKeys = [
        ForeignKey(
            entity = TaskEntity::class,
            parentColumns = ["id"],
            childColumns = ["taskId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("taskId")],
)
data class TimerSessionEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0L,
    val taskId: Long,
    val startedAt: Long,
    val endedAt: Long,
)

fun TimerSession.toEntity() = TimerSessionEntity(
    id = id,
    taskId = taskId,
    startedAt = startedAt,
    endedAt = endedAt,
)
EOF_VITRINE

write app/src/main/java/com/example/vitrine/data/local/db/entity/TimerStateEntity.kt <<'EOF_VITRINE'
package com.example.vitrine.data.local.db.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.PrimaryKey
import com.example.vitrine.domain.model.TimerState

/** Une ligne par tâche dont le chrono n'est pas à zéro (en cours ou en pause). */
@Entity(
    tableName = "timer_states",
    foreignKeys = [
        ForeignKey(
            entity = TaskEntity::class,
            parentColumns = ["id"],
            childColumns = ["taskId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
)
data class TimerStateEntity(
    @PrimaryKey val taskId: Long,
    val accumulatedMillis: Long,
    val runningSince: Long?,
)

fun TimerStateEntity.toDomain() = TimerState(
    taskId = taskId,
    accumulatedMillis = accumulatedMillis,
    runningSince = runningSince,
)

fun TimerState.toEntity() = TimerStateEntity(
    taskId = taskId,
    accumulatedMillis = accumulatedMillis,
    runningSince = runningSince,
)
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

    override suspend fun deleteTask(id: Long) = dao.deleteWithHistory(id)
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/data/repository/TimerRepositoryImpl.kt <<'EOF_VITRINE'
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
import com.example.vitrine.domain.repository.TaskRepository
import com.example.vitrine.domain.repository.TimerRepository
import com.example.vitrine.domain.usecase.ReconstructTimersUseCase
import com.example.vitrine.feature.clock.usecase.GetCurrentTimeUseCase
import com.example.vitrine.feature.clock.viewmodel.ClockViewModel
import com.example.vitrine.feature.flashlight.usecase.SetScreenBrightnessUseCase
import com.example.vitrine.feature.flashlight.viewmodel.FlashlightViewModel
import com.example.vitrine.feature.text.viewmodel.TextViewModel
import com.example.vitrine.feature.timer.service.AndroidTimerNotifier
import com.example.vitrine.domain.notification.TimerNotifier
import com.example.vitrine.feature.timer.usecase.PauseTimerUseCase
import com.example.vitrine.feature.timer.usecase.StartTimerUseCase
import com.example.vitrine.feature.timer.usecase.StopTimerUseCase
import com.example.vitrine.feature.timer.viewmodel.TimerViewModel
import org.koin.android.ext.koin.androidContext
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
    factory { StartTimerUseCase(get(), get(), get(), get()) }
    factory { PauseTimerUseCase(get(), get(), get()) }
    factory { StopTimerUseCase(get(), get(), get()) }
    factory { ReconstructTimersUseCase(get(), get(), get()) }
    viewModelOf(::TimerViewModel)
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/domain/model/Task.kt <<'EOF_VITRINE'
package com.example.vitrine.domain.model

/** Une tâche dont on mesure le temps (ex. « Révisions », « Sport »). */
data class Task(
    val id: Long,
    val name: String,
    val createdAt: Long,
)

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
EOF_VITRINE

write app/src/main/java/com/example/vitrine/domain/model/TimerSession.kt <<'EOF_VITRINE'
package com.example.vitrine.domain.model

/** Une période de travail terminée sur une tâche : de [startedAt] à [endedAt]. */
data class TimerSession(
    val taskId: Long,
    val startedAt: Long,
    val endedAt: Long,
    val id: Long = 0L,
) {
    val durationMillis: Long get() = (endedAt - startedAt).coerceAtLeast(0L)
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/domain/model/TimerState.kt <<'EOF_VITRINE'
package com.example.vitrine.domain.model

/**
 * Chrono d'une tâche, enregistré pour survivre à la fermeture de l'application et au redémarrage.
 * On ne stocke pas un compteur qui avance, mais une heure de départ : le temps écoulé se recalcule
 * à tout moment, même si rien n'a tourné entre-temps.
 *
 * @property accumulatedMillis temps déjà compté avant la dernière pause.
 * @property runningSince heure de (re)démarrage si le chrono tourne, null s'il est en pause.
 */
data class TimerState(
    val taskId: Long,
    val accumulatedMillis: Long = 0L,
    val runningSince: Long? = null,
) {
    val isRunning: Boolean get() = runningSince != null

    /** Part de temps de la session en cours (0 en pause). Jamais négative, même si l'heure recule. */
    fun runningPartAt(now: Long): Long = runningSince?.let { (now - it).coerceAtLeast(0L) } ?: 0L

    /** Temps total affiché par le chrono à l'instant [now]. */
    fun elapsedAt(now: Long): Long = accumulatedMillis + runningPartAt(now)
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

    /** Supprime la tâche avec son chrono et tout son historique. */
    suspend fun deleteTask(id: Long)
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/domain/repository/TimerRepository.kt <<'EOF_VITRINE'
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
EOF_VITRINE

write app/src/main/java/com/example/vitrine/domain/usecase/ReconstructTimersUseCase.kt <<'EOF_VITRINE'
package com.example.vitrine.domain.usecase

import com.example.vitrine.domain.repository.TaskRepository
import com.example.vitrine.domain.repository.TimerRepository
import com.example.vitrine.domain.notification.TimerNotifier

/**
 * Remet en place les notifications des chronos qui tournent, par exemple après un redémarrage
 * du téléphone (qui efface toutes les notifications) ou au lancement de l'application.
 * Les chronos eux-mêmes n'ont rien à « rattraper » : leur heure de départ est enregistrée.
 */
class ReconstructTimersUseCase(
    private val tasks: TaskRepository,
    private val timers: TimerRepository,
    private val notifier: TimerNotifier,
) {
    suspend operator fun invoke() {
        timers.getRunningStates().forEach { state ->
            val task = tasks.getTask(state.taskId)
            if (task != null) notifier.showRunning(task, state) else timers.deleteState(state.taskId)
        }
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/ui/TaskItem.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.ui

import androidx.compose.animation.AnimatedVisibility
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
import com.example.vitrine.feature.timer.ui.components.PauseIcon
import com.example.vitrine.feature.timer.ui.components.PlayIcon
import com.example.vitrine.feature.timer.ui.components.RoundIconButton
import com.example.vitrine.feature.timer.ui.components.StopIcon
import com.example.vitrine.feature.timer.ui.model.formatStopwatch
import com.example.vitrine.feature.timer.ui.model.formatTotal
import com.example.vitrine.feature.timer.viewmodel.TaskTimerItem
import com.example.vitrine.ui.theme.VitrineColors

/**
 * Carte d'une tâche : nom et état, grand chrono, temps total, boutons Lecture/Pause et Remise à zéro.
 * Un appui long propose de supprimer la tâche.
 */
@Composable
fun TaskItem(
    item: TaskTimerItem,
    onToggle: () -> Unit,
    onReset: () -> Unit,
    onDeleteRequest: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val haptics = LocalHapticFeedback.current
    val deleteLabel = stringResource(R.string.timer_delete)

    VitrineCard(
        modifier = modifier
            .pointerInput(item.id) {
                detectTapGestures(onLongPress = {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    onDeleteRequest()
                })
            }
            // TalkBack ne fait pas d'appui long : on lui propose la suppression comme action
            .semantics {
                customActions = listOf(CustomAccessibilityAction(deleteLabel) { onDeleteRequest(); true })
            },
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = item.name,
                style = MaterialTheme.typography.titleMedium,
                color = VitrineColors.TextPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false),
            )
            Spacer(Modifier.width(8.dp))
            when {
                item.isRunning -> StatusDot(stringResource(R.string.timer_running), VitrineColors.Accent)
                item.canReset -> StatusDot(stringResource(R.string.timer_paused), VitrineColors.Warning)
            }
        }

        Spacer(Modifier.height(6.dp))

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
                    color = if (item.canReset) VitrineColors.TextPrimary else VitrineColors.TextMuted,
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
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/ui/TimerScreen.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.domain.usecase.ReconstructTimersUseCase
import com.example.vitrine.feature.timer.ui.home.TimerHomeScreen
import com.example.vitrine.feature.timer.viewmodel.TimerViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.koin.androidx.compose.koinViewModel
import org.koin.compose.koinInject

/**
 * Point d'entrée de la feature chronos.
 * Au premier lancement d'un chrono (Android 13+), demande la permission d'afficher la notification.
 * Sans elle, les chronos fonctionnent quand même : seule la notification manque.
 */
@Composable
fun TimerScreen(
    onNavigate: (AppDestination) -> Unit,
    viewModel: TimerViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val reconstructTimers: ReconstructTimersUseCase = koinInject()
    var permissionAsked by rememberSaveable { mutableStateOf(false) }

    // Permission accordée après coup : on affiche tout de suite les notifications des chronos en cours
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) CoroutineScope(Dispatchers.IO).launch { reconstructTimers() }
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

    TimerHomeScreen(
        state = state,
        onNewTaskNameChange = viewModel::onNewTaskNameChange,
        onAddTask = viewModel::addTask,
        onToggle = { item ->
            if (!item.isRunning) askNotificationPermissionOnce()
            viewModel.toggle(item)
        },
        onReset = viewModel::reset,
        onDelete = viewModel::delete,
        onNavigate = onNavigate,
    )
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/usecase/PauseTimerUseCase.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
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
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/usecase/StartTimerUseCase.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
import com.example.vitrine.domain.model.TimerState
import com.example.vitrine.domain.repository.TaskRepository
import com.example.vitrine.domain.repository.TimerRepository
import com.example.vitrine.domain.notification.TimerNotifier

/** Lance (ou relance après une pause) le chrono d'une tâche et affiche sa notification. */
class StartTimerUseCase(
    private val tasks: TaskRepository,
    private val timers: TimerRepository,
    private val notifier: TimerNotifier,
    private val clock: Clock,
) {
    suspend operator fun invoke(taskId: Long) {
        val task = tasks.getTask(taskId) ?: return
        val current = timers.getState(taskId) ?: TimerState(taskId)
        if (current.isRunning) return

        val running = current.copy(runningSince = clock.now())
        timers.saveState(running)
        notifier.showRunning(task, running)
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/usecase/StopTimerUseCase.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.core.util.Clock
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
import com.example.vitrine.domain.model.TaskTimer
import com.example.vitrine.domain.repository.TaskRepository
import com.example.vitrine.domain.repository.TimerRepository
import com.example.vitrine.feature.timer.usecase.PauseTimerUseCase
import com.example.vitrine.feature.timer.usecase.StartTimerUseCase
import com.example.vitrine.feature.timer.usecase.StopTimerUseCase
import kotlinx.coroutines.flow.Flow
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
) {
    /** Vrai si le chrono n'est pas à zéro (en cours ou en pause) : on peut le remettre à zéro. */
    val canReset: Boolean get() = isRunning || currentMillis > 0
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
 * Les temps sont recalculés chaque seconde à partir des heures de départ enregistrées ;
 * les actions passent par les use cases, qui mettent aussi la notification à jour.
 */
class TimerViewModel(
    private val savedState: SavedStateHandle,
    private val tasks: TaskRepository,
    timers: TimerRepository,
    private val startTimer: StartTimerUseCase,
    private val pauseTimer: PauseTimerUseCase,
    private val stopTimer: StopTimerUseCase,
    private val clock: Clock,
) : ViewModel() {

    private val newTaskName = savedState.getStateFlow(KEY_NEW_TASK_NAME, "")

    private val taskTimers: Flow<List<TaskTimer>> = combine(
        tasks.observeTasks(),
        timers.observeStates(),
        timers.observeSessionTotals(),
    ) { taskList, states, totals ->
        val stateByTask = states.associateBy { it.taskId }
        taskList.map { task ->
            TaskTimer(task = task, state = stateByTask[task.id], sessionsMillis = totals[task.id] ?: 0L)
        }
    }

    val uiState: StateFlow<TimerUiState> = combine(
        taskTimers,
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
        // Une ligne, nom raisonnable : il doit tenir dans une carte et dans la notification
        savedState[KEY_NEW_TASK_NAME] = value.replace("\n", "").take(MAX_TASK_NAME_LENGTH)
    }

    fun addTask() {
        val name = newTaskName.value.trim()
        if (name.isEmpty()) return
        savedState[KEY_NEW_TASK_NAME] = ""
        viewModelScope.launch { tasks.addTask(name, clock.now()) }
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

    fun delete(taskId: Long) {
        viewModelScope.launch {
            stopTimer(taskId) // retire aussi la notification
            tasks.deleteTask(taskId)
        }
    }

    private fun TaskTimer.toItem(now: Long) = TaskTimerItem(
        id = task.id,
        name = task.name,
        currentMillis = currentMillis(now),
        totalMillis = totalMillis(now),
        isRunning = isRunning,
    )

    companion object {
        const val MAX_TASK_NAME_LENGTH = 40
        private const val KEY_NEW_TASK_NAME = "newTaskName"
    }
}
EOF_VITRINE

write app/src/main/res/values/strings_menu.xml <<'EOF_VITRINE'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Menu de navigation entre les fonctionnalités -->
    <string name="menu_text">Texte</string>
    <string name="menu_clock">Horloge</string>
    <string name="menu_flashlight">Lampe</string>
    <string name="menu_timer">Chrono</string>

    <string name="clock_title">L\'heure, en très grand</string>
    <string name="flashlight_title">La lumière, au bout des doigts</string>
    <string name="timer_title">Le temps, tâche par tâche</string>
</resources>
EOF_VITRINE

write build.gradle.kts <<'EOF_VITRINE'
// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.ksp) apply false
}
EOF_VITRINE

write gradle/libs.versions.toml <<'EOF_VITRINE'
[versions]
agp = "9.4.1"
coreKtx = "1.19.1"
junit = "4.13.2"
junitVersion = "1.3.0"
espressoCore = "3.7.0"
lifecycleRuntimeKtx = "2.11.0"
activityCompose = "1.13.0"
kotlin = "2.2.10"
composeBom = "2026.02.01"
koin = "4.2.2"
datastore = "1.1.7"
ksp = "2.3.13"
room = "2.8.5"

[libraries]
androidx-core-ktx = { group = "androidx.core", name = "core-ktx", version.ref = "coreKtx" }
junit = { group = "junit", name = "junit", version.ref = "junit" }
androidx-junit = { group = "androidx.test.ext", name = "junit", version.ref = "junitVersion" }
androidx-espresso-core = { group = "androidx.test.espresso", name = "espresso-core", version.ref = "espressoCore" }
androidx-lifecycle-runtime-ktx = { group = "androidx.lifecycle", name = "lifecycle-runtime-ktx", version.ref = "lifecycleRuntimeKtx" }
androidx-lifecycle-viewmodel-compose = { group = "androidx.lifecycle", name = "lifecycle-viewmodel-compose", version.ref = "lifecycleRuntimeKtx" }
androidx-lifecycle-runtime-compose = { group = "androidx.lifecycle", name = "lifecycle-runtime-compose", version.ref = "lifecycleRuntimeKtx" }
androidx-activity-compose = { group = "androidx.activity", name = "activity-compose", version.ref = "activityCompose" }
androidx-compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "composeBom" }
androidx-compose-ui = { group = "androidx.compose.ui", name = "ui" }
androidx-compose-ui-graphics = { group = "androidx.compose.ui", name = "ui-graphics" }
androidx-compose-ui-tooling = { group = "androidx.compose.ui", name = "ui-tooling" }
androidx-compose-ui-tooling-preview = { group = "androidx.compose.ui", name = "ui-tooling-preview" }
androidx-compose-ui-test-manifest = { group = "androidx.compose.ui", name = "ui-test-manifest" }
androidx-compose-ui-test-junit4 = { group = "androidx.compose.ui", name = "ui-test-junit4" }
androidx-compose-material3 = { group = "androidx.compose.material3", name = "material3" }
androidx-datastore-preferences = { group = "androidx.datastore", name = "datastore-preferences", version.ref = "datastore" }
koin-android = { group = "io.insert-koin", name = "koin-android", version.ref = "koin" }
koin-androidx-compose = { group = "io.insert-koin", name = "koin-androidx-compose", version.ref = "koin" }
androidx-room-runtime = { group = "androidx.room", name = "room-runtime", version.ref = "room" }
androidx-room-ktx = { group = "androidx.room", name = "room-ktx", version.ref = "room" }
androidx-room-compiler = { group = "androidx.room", name = "room-compiler", version.ref = "room" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
ksp = { id = "com.google.devtools.ksp", version.ref = "ksp" }
EOF_VITRINE

echo
echo "Terminé. Dans Android Studio : File > Sync Project with Gradle Files, puis Build > Rebuild Project."
