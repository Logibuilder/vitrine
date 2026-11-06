package com.example.vitrine.feature.clock.ui

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.feature.clock.ui.display.ClockDisplayScreen
import com.example.vitrine.feature.clock.ui.home.ClockHomeScreen
import com.example.vitrine.feature.clock.viewmodel.ClockViewModel
import org.koin.androidx.compose.koinViewModel

/**
 * Point d'entrée de la feature horloge.
 * Récupère l'état du ViewModel et choisit l'écran : réglages ou affichage plein écran.
 */
@Composable
fun ClockScreen(
    onNavigate: (AppDestination) -> Unit,
    viewModel: ClockViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    // Retour du téléphone en plein écran : revient aux réglages de l'horloge
    BackHandler(enabled = state.isFullScreen, onBack = viewModel::exitFullScreen)

    if (state.isFullScreen) {
        ClockDisplayScreen(
            time = state.time,
            style = state.style,
            showSeconds = state.showSeconds,
            onExit = viewModel::exitFullScreen,
        )
    } else {
        ClockHomeScreen(
            state = state,
            onStyle = viewModel::setStyle,
            onUse24Hour = viewModel::setUse24Hour,
            onShowSeconds = viewModel::setShowSeconds,
            onShowFullScreen = viewModel::showFullScreen,
            onNavigate = onNavigate,
        )
    }
}
