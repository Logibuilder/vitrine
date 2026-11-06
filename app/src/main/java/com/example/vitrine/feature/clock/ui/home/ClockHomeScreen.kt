package com.example.vitrine.feature.clock.ui.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.example.vitrine.R
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.core.ui.components.SectionLabel
import com.example.vitrine.core.ui.components.SegmentedControl
import com.example.vitrine.core.ui.components.StatusDot
import com.example.vitrine.core.ui.components.VitrineCard
import com.example.vitrine.core.ui.components.VitrineScreen
import com.example.vitrine.feature.clock.ui.components.AnalogClock
import com.example.vitrine.feature.clock.ui.components.AnalogClockColors
import com.example.vitrine.feature.clock.ui.components.BigClock
import com.example.vitrine.feature.clock.viewmodel.ClockStyle
import com.example.vitrine.feature.clock.viewmodel.ClockUiState
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineDimens

/**
 * Écran horloge : grande heure (toucher pour l'afficher en plein écran) et réglages.
 * Même gabarit que les autres écrans : titre, cartes, menu.
 */
@Composable
fun ClockHomeScreen(
    state: ClockUiState,
    onStyle: (ClockStyle) -> Unit,
    onUse24Hour: (Boolean) -> Unit,
    onShowSeconds: (Boolean) -> Unit,
    onShowFullScreen: () -> Unit,
    onNavigate: (AppDestination) -> Unit,
) {
    VitrineScreen(
        title = stringResource(R.string.clock_title),
        current = AppDestination.CLOCK,
        onNavigate = onNavigate,
    ) {
        // Carte de l'heure : prend la place restante, toucher pour passer en plein écran
        VitrineCard(
            modifier = Modifier.weight(1f),
            onClick = onShowFullScreen,
            onClickLabel = stringResource(R.string.text_show_full_screen),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
            ) {
                StatusDot(
                    text = stringResource(R.string.clock_tap_hint),
                    color = VitrineColors.Accent,
                )
            }
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(top = 4.dp),
                contentAlignment = Alignment.Center,
            ) {
                val analogColors = AnalogClockColors(
                    face = VitrineColors.Background,
                    minorTick = VitrineColors.Divider,
                    majorTick = VitrineColors.TextMuted,
                    hands = VitrineColors.TextPrimary,
                    secondHand = VitrineColors.Accent,
                )
                Crossfade(targetState = state.style, label = "clock-style") { style ->
                    when (style) {
                        ClockStyle.DIGITAL -> BigClock(
                            time = state.time,
                            showSeconds = state.showSeconds,
                            color = VitrineColors.TextPrimary,
                            secondaryColor = VitrineColors.TextMuted,
                        )
                        ClockStyle.ANALOG -> Column(
                            modifier = Modifier.fillMaxSize(),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            AnalogClock(
                                time = state.time,
                                showSeconds = state.showSeconds,
                                colors = analogColors,
                                modifier = Modifier.weight(1f),
                            )
                            Text(
                                text = state.time.date,
                                style = MaterialTheme.typography.bodyMedium,
                                color = VitrineColors.TextMuted,
                            )
                        }
                    }
                }
            }
        }

        VitrineCard {
            SettingRow(label = stringResource(R.string.clock_style_label)) {
                SegmentedControl(
                    options = ClockStyle.entries,
                    selected = state.style,
                    onSelect = onStyle,
                    label = { style ->
                        stringResource(
                            when (style) {
                                ClockStyle.DIGITAL -> R.string.clock_style_digital
                                ClockStyle.ANALOG -> R.string.clock_style_analog
                            }
                        )
                    },
                )
            }
            Spacer(Modifier.height(VitrineDimens.SectionGap))

            // Le format 12/24 h ne concerne que l'affichage en chiffres
            AnimatedVisibility(
                visible = state.style == ClockStyle.DIGITAL,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically(),
            ) {
                Column {
                    SettingRow(label = stringResource(R.string.clock_format_label)) {
                        SegmentedControl(
                            options = listOf(true, false),
                            selected = state.use24Hour,
                            onSelect = onUse24Hour,
                            label = { h24 ->
                                stringResource(if (h24) R.string.clock_format_24 else R.string.clock_format_12)
                            },
                        )
                    }
                    Spacer(Modifier.height(VitrineDimens.SectionGap))
                }
            }
            SettingRow(label = stringResource(R.string.clock_seconds_label)) {
                SegmentedControl(
                    options = listOf(true, false),
                    selected = state.showSeconds,
                    onSelect = onShowSeconds,
                    label = { show ->
                        stringResource(if (show) R.string.clock_seconds_show else R.string.clock_seconds_hide)
                    },
                )
            }
        }
    }
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
