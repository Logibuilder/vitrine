package com.example.vitrine.feature.flashlight.ui.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.res.colorResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.min
import com.example.vitrine.R
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.core.ui.components.ColorSwatch
import com.example.vitrine.core.ui.components.SectionLabel
import com.example.vitrine.core.ui.components.SegmentedControl
import com.example.vitrine.core.ui.components.StatusDot
import com.example.vitrine.core.ui.components.VitrineCard
import com.example.vitrine.core.ui.components.VitrineScreen
import com.example.vitrine.feature.flashlight.ui.model.LightColorOptions
import com.example.vitrine.feature.flashlight.usecase.SetScreenBrightnessUseCase
import com.example.vitrine.feature.flashlight.viewmodel.FlashlightUiState
import com.example.vitrine.feature.flashlight.viewmodel.LightSource
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineDimens
import kotlin.math.roundToInt

/**
 * Écran lampe : un grand aperçu (lumière d'écran) ou un gros bouton (flash), puis les réglages.
 * Même gabarit que les autres écrans : titre, cartes, menu.
 */
@Composable
fun FlashlightHomeScreen(
    state: FlashlightUiState,
    onSource: (LightSource) -> Unit,
    onColor: (Int) -> Unit,
    onBrightness: (Float) -> Unit,
    onShowFullScreen: () -> Unit,
    onToggleTorch: () -> Unit,
    onNavigate: (AppDestination) -> Unit,
) {
    VitrineScreen(
        title = stringResource(R.string.flashlight_title),
        current = AppDestination.FLASHLIGHT,
        onNavigate = onNavigate,
    ) {
        when (state.source) {
            LightSource.SCREEN -> ScreenLightCard(
                color = Color(state.colorArgb),
                brightness = state.brightness,
                onClick = onShowFullScreen,
                modifier = Modifier.weight(1f),
            )
            LightSource.TORCH -> TorchCard(
                isOn = state.torchOn,
                onToggle = onToggleTorch,
                modifier = Modifier.weight(1f),
            )
        }

        VitrineCard {
            // Sans flash sur l'appareil, il n'y a qu'une source : pas de choix à afficher
            if (state.torchAvailable) {
                SettingRow(label = stringResource(R.string.light_source_label)) {
                    SegmentedControl(
                        options = LightSource.entries,
                        selected = state.source,
                        onSelect = onSource,
                        label = { source ->
                            stringResource(
                                when (source) {
                                    LightSource.SCREEN -> R.string.light_source_screen
                                    LightSource.TORCH -> R.string.light_source_torch
                                }
                            )
                        },
                    )
                }
            }

            AnimatedVisibility(
                visible = state.source == LightSource.SCREEN,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically(),
            ) {
                Column {
                    if (state.torchAvailable) Spacer(Modifier.height(VitrineDimens.SectionGap))
                    ScreenLightSettings(
                        colorArgb = state.colorArgb,
                        brightness = state.brightness,
                        onColor = onColor,
                        onBrightness = onBrightness,
                    )
                }
            }
        }
    }
}

/** Aperçu de la lumière d'écran : un disque de la couleur choisie, plus ou moins vif. */
@Composable
private fun ScreenLightCard(
    color: Color,
    brightness: Float,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    VitrineCard(
        modifier = modifier,
        onClick = onClick,
        onClickLabel = stringResource(R.string.light_turn_on_screen),
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            StatusDot(text = stringResource(R.string.light_tap_hint), color = VitrineColors.Accent)
        }
        BoxWithConstraints(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            contentAlignment = Alignment.Center,
        ) {
            val side = min(maxWidth, maxHeight) * 0.8f
            // Halo pâle autour, disque plein au centre : l'intensité règle l'opacité du disque
            Box(
                modifier = Modifier
                    .size(side)
                    .clip(CircleShape)
                    .background(color.copy(alpha = 0.18f)),
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    modifier = Modifier
                        .size(side * 0.62f)
                        .clip(CircleShape)
                        .background(color.copy(alpha = 0.35f + 0.65f * brightness)),
                )
            }
        }
    }
}

/** Flash : un gros bouton d'alimentation rond, vert quand le flash est allumé. */
@Composable
private fun TorchCard(
    isOn: Boolean,
    onToggle: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val background by animateColorAsState(
        targetValue = if (isOn) VitrineColors.Accent else VitrineColors.SurfaceMuted,
        label = "torch-button",
    )
    val iconColor by animateColorAsState(
        targetValue = if (isOn) VitrineColors.Surface else VitrineColors.TextPrimary,
        label = "torch-icon",
    )
    val actionLabel = stringResource(R.string.light_toggle_torch)
    val stateLabel = stringResource(if (isOn) R.string.light_torch_on else R.string.light_torch_off)

    VitrineCard(modifier = modifier) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            StatusDot(
                text = stateLabel,
                color = if (isOn) VitrineColors.Accent else VitrineColors.Divider,
            )
        }
        BoxWithConstraints(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            contentAlignment = Alignment.Center,
        ) {
            val side = min(maxWidth, maxHeight) * 0.6f
            Box(
                modifier = Modifier
                    .size(side)
                    .clip(CircleShape)
                    .background(background)
                    .clickable(role = Role.Switch, onClick = onToggle)
                    .semantics {
                        contentDescription = actionLabel
                        stateDescription = stateLabel
                    },
                contentAlignment = Alignment.Center,
            ) {
                PowerIcon(color = iconColor, modifier = Modifier.size(side * 0.36f))
            }
        }
    }
}

/** Symbole « marche/arrêt » : un cercle ouvert en haut, traversé d'un trait. */
@Composable
private fun PowerIcon(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val stroke = size.minDimension * 0.11f
        val inset = stroke / 2
        drawArc(
            color = color,
            startAngle = -60f,
            sweepAngle = 300f,
            useCenter = false,
            topLeft = Offset(inset, inset),
            size = Size(size.width - stroke, size.height - stroke),
            style = Stroke(width = stroke, cap = StrokeCap.Round),
        )
        drawLine(
            color = color,
            start = Offset(center.x, inset),
            end = Offset(center.x, center.y),
            strokeWidth = stroke,
            cap = StrokeCap.Round,
        )
    }
}

@Composable
private fun ScreenLightSettings(
    colorArgb: Int,
    brightness: Float,
    onColor: (Int) -> Unit,
    onBrightness: (Float) -> Unit,
) {
    SectionLabel(stringResource(R.string.light_color_label))
    Spacer(Modifier.height(VitrineDimens.LabelGap))
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceEvenly,
    ) {
        LightColorOptions.forEach { option ->
            val color = colorResource(option.color)
            val argb = color.toArgb()
            ColorSwatch(
                label = stringResource(option.label),
                color = color,
                selected = colorArgb == argb,
                onClick = { onColor(argb) },
            )
        }
    }

    Spacer(Modifier.height(VitrineDimens.SectionGap))

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SectionLabel(stringResource(R.string.light_brightness_label))
        Text(
            text = stringResource(R.string.light_level, (brightness * 100).roundToInt()),
            style = MaterialTheme.typography.labelLarge,
            color = VitrineColors.TextPrimary,
        )
    }
    Slider(
        value = brightness,
        onValueChange = onBrightness,
        valueRange = SetScreenBrightnessUseCase.MIN_LEVEL..1f,
        colors = SliderDefaults.colors(
            thumbColor = VitrineColors.TextPrimary,
            activeTrackColor = VitrineColors.Accent,
            inactiveTrackColor = VitrineColors.SurfaceMuted,
        ),
    )
}

/** Réglage sur une ligne : libellé à gauche, choix à droite. */
@Composable
private fun SettingRow(
    label: String,
    control: @Composable () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        SectionLabel(label)
        control()
    }
}
