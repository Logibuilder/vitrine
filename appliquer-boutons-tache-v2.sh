#!/usr/bin/env bash
# Chronos : boutons Modifier et Supprimer sur la carte, objectif obligatoire,
# et seule la barre de progression colorée.
# Remplace appliquer-boutons-tache.sh (inutile de lancer les deux).
# À lancer depuis la racine du projet VITRINE, après appliquer-objectif.sh.
# Pensez à faire un commit avant : les fichiers existants sont écrasés.
set -euo pipefail

if [[ ! -f settings.gradle.kts || ! -d app/src/main ]]; then
  echo "Erreur : lancez ce script depuis la racine du projet VITRINE." >&2
  exit 1
fi

write() { mkdir -p "$(dirname "$1")"; cat > "$1"; echo "  écrit : $1"; }

echo "Remplacement :"
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
    abstract suspend fun update(id: Long, name: String, goalMillis: Long)

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
    /**
     * Ajouté en version 2 de la base (voir AppDatabase.MIGRATION_1_2). La colonne accepte NULL
     * pour les tâches créées avant : elles prennent alors l'objectif par défaut.
     */
    val goalMillis: Long? = Task.DEFAULT_GOAL_MILLIS,
)

fun TaskEntity.toDomain() = Task(
    id = id,
    name = name,
    createdAt = createdAt,
    goalMillis = goalMillis ?: Task.DEFAULT_GOAL_MILLIS,
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

    override suspend fun updateTask(id: Long, name: String, goalMillis: Long) =
        dao.update(id, name.trim(), goalMillis)

    override suspend fun deleteTask(id: Long) = dao.deleteWithHistory(id)
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/domain/model/Task.kt <<'EOF_VITRINE'
package com.example.vitrine.domain.model

/**
 * Une tâche dont on mesure le temps (ex. « Révisions », « Sport »).
 *
 * @property goalMillis objectif de temps du chrono (ex. 25 min). Chaque tâche en a un :
 *   [DEFAULT_GOAL_MILLIS] à la création, modifiable ensuite.
 *   Quand le chrono l'atteint, une alarme sonne ; le chrono, lui, continue de compter.
 */
data class Task(
    val id: Long,
    val name: String,
    val createdAt: Long,
    val goalMillis: Long = DEFAULT_GOAL_MILLIS,
) {
    companion object {
        /** Un nom doit tenir sur une carte et dans une notification. */
        const val MAX_NAME_LENGTH = 40

        /** Objectif d'une nouvelle tâche : 25 minutes. */
        const val DEFAULT_GOAL_MILLIS = 25 * 60_000L

        /** Objectif minimal : 1 minute (un objectif nul n'aurait pas de sens). */
        const val MIN_GOAL_MILLIS = 60_000L
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
 * Null si le chrono est en pause ou si l'objectif est déjà atteint :
 * dans ces cas, il n'y a pas d'alarme à programmer.
 */
fun millisUntilGoal(goalMillis: Long, state: TimerState, now: Long): Long? {
    if (!state.isRunning) return null
    return (goalMillis - state.elapsedAt(now)).takeIf { it > 0 }
}

/** Avancement vers l'objectif : 0 au départ, 1 à l'objectif, plus de 1 s'il est dépassé. */
fun goalProgress(currentMillis: Long, goalMillis: Long): Float =
    currentMillis.coerceAtLeast(0L).toFloat() / goalMillis.coerceAtLeast(Task.MIN_GOAL_MILLIS)
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

    /** Crée une tâche (avec l'objectif par défaut) et renvoie son identifiant. */
    suspend fun addTask(name: String, createdAt: Long): Long

    /** Change le nom et l'objectif d'une tâche. */
    suspend fun updateTask(id: Long, name: String, goalMillis: Long)

    /** Supprime la tâche avec son chrono et tout son historique. */
    suspend fun deleteTask(id: Long)
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
        val goal = task.goalMillis

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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
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
import com.example.vitrine.feature.timer.ui.components.TrashIcon
import com.example.vitrine.feature.timer.viewmodel.TaskTimerItem
import com.example.vitrine.ui.theme.VitrineColors

/**
 * Carte d'une tâche :
 * - en haut : nom et état (en cours, en pause, objectif atteint) ;
 * - au milieu : grand chrono et temps total, puis les boutons
 *   [remise à zéro] [modifier] [supprimer] [lecture / pause] ;
 * - en bas : barre de progression vers l'objectif, du vert au rouge
 *   (c'est le seul élément coloré selon l'avancement).
 * Un appui long ouvre aussi la modification.
 */
@Composable
fun TaskItem(
    item: TaskTimerItem,
    onToggle: () -> Unit,
    onReset: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val haptics = LocalHapticFeedback.current
    val progress = item.goalProgress


    VitrineCard(
        modifier = modifier.pointerInput(item.id) {
            detectTapGestures(onLongPress = {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                onEdit()
            })
        },
    ) {
        Header(item)

        Spacer(Modifier.height(4.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            // Serré mais lisible : le chrono garde la place pour « 1:04:07 » même avec 4 boutons
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Column(Modifier.weight(1f)) {
                Text(
                    text = formatStopwatch(item.currentMillis),
                    style = MaterialTheme.typography.headlineMedium.merge(
                        // Chiffres de même largeur : le temps ne « tremble » pas
                        TextStyle(fontFeatureSettings = "tnum"),
                    ),
                    // Seule la barre de progression porte la couleur de l'avancement
                    color = if (item.canReset) VitrineColors.TextPrimary else VitrineColors.TextMuted,
                    maxLines = 1,
                )
                Text(
                    text = stringResource(R.string.timer_total, formatTotal(item.totalMillis)),
                    style = MaterialTheme.typography.labelSmall,
                    color = VitrineColors.TextMuted,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            AnimatedVisibility(
                visible = item.canReset,
                enter = fadeIn() + scaleIn(),
                exit = fadeOut() + scaleOut(),
            ) {
                SmallButton(stringResource(R.string.timer_reset), onReset) {
                    StopIcon(VitrineColors.TextPrimary, Modifier.size(16.dp))
                }
            }

            SmallButton(stringResource(R.string.timer_edit), onEdit) {
                EditIcon(VitrineColors.TextPrimary, Modifier.size(16.dp))
            }

            SmallButton(stringResource(R.string.timer_delete_task), onDelete) {
                TrashIcon(VitrineColors.Danger, Modifier.size(16.dp))
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

        Spacer(Modifier.height(10.dp))
        GoalProgressBar(progress = progress)
        Spacer(Modifier.height(4.dp))
        GoalCaption(item)
    }
}

/** Nom de la tâche et son état. */
@Composable
private fun Header(item: TaskTimerItem) {
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
    }
}

/** Petit bouton rond secondaire (remise à zéro, modifier, supprimer). */
@Composable
private fun SmallButton(
    contentDescription: String,
    onClick: () -> Unit,
    icon: @Composable () -> Unit,
) {
    RoundIconButton(
        contentDescription = contentDescription,
        background = VitrineColors.SurfaceMuted,
        size = 34.dp,
        onClick = onClick,
        icon = icon,
    )
}

/** « Objectif : 25 min » à gauche ; « Reste 12 min » ou « Dépassé de 3 min » à droite. */
@Composable
private fun GoalCaption(item: TaskTimerItem) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = stringResource(R.string.timer_goal_caption, formatTotal(item.goalMillis)),
            style = MaterialTheme.typography.labelSmall,
            color = VitrineColors.TextMuted,
        )
        val difference = item.currentMillis - item.goalMillis
        Text(
            text = if (difference >= 0) {
                stringResource(R.string.timer_goal_exceeded, formatTotal(difference))
            } else {
                stringResource(R.string.timer_goal_remaining, formatTotal(-difference))
            },
            style = MaterialTheme.typography.labelSmall,
            color = VitrineColors.TextMuted,
        )
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

/** Corbeille « supprimer » : couvercle, poignée et cuve aux coins arrondis. */
@Composable
fun TrashIcon(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val w = size.width
        val h = size.height
        val stroke = size.minDimension * 0.12f
        // Couvercle et poignée
        drawLine(color, Offset(w * 0.14f, h * 0.24f), Offset(w * 0.86f, h * 0.24f), stroke, StrokeCap.Round)
        drawLine(color, Offset(w * 0.38f, h * 0.10f), Offset(w * 0.62f, h * 0.10f), stroke, StrokeCap.Round)
        // Cuve
        drawRoundRect(
            color = color,
            topLeft = Offset(w * 0.24f, h * 0.34f),
            size = Size(w * 0.52f, h * 0.58f),
            cornerRadius = CornerRadius(w * 0.08f),
            style = Stroke(width = stroke),
        )
    }
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
 * Fenêtre de modification d'une tâche : nom et objectif (réglable de 5 en 5 minutes ou par raccourcis).
 * Chaque tâche a un objectif ; la suppression se fait depuis la carte.
 *
 * @param exactAlarmAllowed faux si Android peut retarder l'alarme : on propose alors de l'autoriser.
 */
@Composable
fun EditTaskDialog(
    taskId: Long,
    initialName: String,
    initialGoalMillis: Long,
    exactAlarmAllowed: Boolean,
    onAllowExactAlarm: () -> Unit,
    onSave: (name: String, goalMillis: Long) -> Unit,
    onDismiss: () -> Unit,
) {
    // Valeurs en cours d'édition, gardées pendant une rotation
    var name by rememberSaveable(taskId) { mutableStateOf(initialName) }
    var goal by rememberSaveable(taskId) { mutableLongStateOf(initialGoalMillis.coerceIn(GOAL_MIN, GOAL_MAX)) }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = VitrineColors.Surface,
        titleContentColor = VitrineColors.TextPrimary,
        title = { Text(stringResource(R.string.timer_edit_title)) },
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
    onUpdate: (taskId: Long, name: String, goalMillis: Long) -> Unit,
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
                        onDelete = { pendingDeleteId = item.id },
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
        val goal = task.goalMillis
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
 * Modifie le nom et l'objectif d'une tâche (objectif d'au moins 1 minute).
 * Si son chrono tourne, la notification prend le nouveau nom et l'alarme suit le nouvel objectif
 * (reprogrammée, ou annulée s'il est déjà dépassé).
 */
class UpdateTaskUseCase(
    private val tasks: TaskRepository,
    private val timers: TimerRepository,
    private val notifier: TimerNotifier,
    private val goalAlarm: GoalAlarmScheduler,
    private val clock: Clock,
) {
    suspend operator fun invoke(taskId: Long, name: String, goalMillis: Long) {
        val trimmed = name.trim().take(Task.MAX_NAME_LENGTH)
        if (trimmed.isEmpty()) return
        val goal = goalMillis.coerceAtLeast(Task.MIN_GOAL_MILLIS)

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
        assertEquals(0.5f, goalProgress(30_000, 60_000), 0.0001f)
        assertEquals(1.5f, goalProgress(90_000, 60_000), 0.0001f)
        assertEquals(0f, goalProgress(-5_000, 60_000), 0.0001f)
    }

    @Test
    fun `delai avant l'objectif`() {
        val running = TimerState(1, accumulatedMillis = 10_000, runningSince = 100_000)
        assertEquals(40_000L, millisUntilGoal(60_000, running, now = 110_000))
        assertEquals(null, millisUntilGoal(60_000, running.copy(runningSince = null), now = 110_000))
        assertEquals(null, millisUntilGoal(15_000, running, now = 110_000)) // déjà atteint
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
