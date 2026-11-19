package com.example.vitrine.feature.timer.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
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
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
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
 * Le glisser-déposer (appui long) est branché par l'écran, via [modifier].
 */
@Composable
fun TaskItem(
    item: TaskTimerItem,
    onToggle: () -> Unit,
    onReset: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
    isDragging: Boolean = false,
) {
    val progress = item.goalProgress
    // La carte se soulève légèrement pendant qu'on la déplace
    val scale by animateFloatAsState(if (isDragging) 1.03f else 1f, label = "drag-scale")

    VitrineCard(
        modifier = modifier.graphicsLayer {
            scaleX = scale
            scaleY = scale
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



            SmallButton(stringResource(R.string.timer_edit), onEdit) {
                EditIcon(VitrineColors.TextPrimary, Modifier.size(16.dp))
            }

            SmallButton(stringResource(R.string.timer_delete_task), onDelete) {
                TrashIcon(VitrineColors.Danger, Modifier.size(16.dp))
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

            // Encre pour lancer (action principale), neutre pour mettre en pause
            RoundIconButton(
                contentDescription = stringResource(if (item.isRunning) R.string.timer_pause else R.string.timer_start),
                background = if (item.isRunning) VitrineColors.SurfaceMuted else VitrineColors.Ink,
                size = 52.dp,
                onClick = onToggle,
            ) {
                if (item.isRunning) {
                    PauseIcon(VitrineColors.TextPrimary, Modifier.size(22.dp))
                } else {
                    PlayIcon(VitrineColors.OnInk, Modifier.size(22.dp))
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