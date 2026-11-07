package com.example.vitrine.feature.flashlight.ui

import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.feature.flashlight.ui.display.LightDisplayScreen
import com.example.vitrine.feature.flashlight.ui.home.FlashlightHomeScreen
import com.example.vitrine.feature.flashlight.viewmodel.FlashlightViewModel
import org.koin.androidx.compose.koinViewModel

/**
 * Point d'entrée de la feature lampe.
 * Récupère l'état du ViewModel et choisit l'écran : réglages ou lumière plein écran.
 */
@Composable
fun FlashlightScreen(
    onNavigate: (AppDestination) -> Unit,
    viewModel: FlashlightViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    // En quittant l'écran lampe (autre écran du menu), on éteint le flash ;
    // mais pas pendant une rotation, où l'écran est seulement recréé
    val activity = LocalView.current.context as? Activity
    DisposableEffect(viewModel) {
        onDispose {
            if (activity?.isChangingConfigurations != true) viewModel.turnOffTorch()
        }
    }

    // Retour du téléphone en plein écran : revient aux réglages de la lampe
    BackHandler(enabled = state.isFullScreen, onBack = viewModel::exitFullScreen)

    if (state.isFullScreen) {
        LightDisplayScreen(
            color = Color(state.colorArgb),
            brightness = state.brightness,
            onBrightnessChange = viewModel::setBrightness,
            onExit = viewModel::exitFullScreen,
        )
    } else {
        FlashlightHomeScreen(
            state = state,
            onSource = viewModel::setSource,
            onColor = viewModel::setColor,
            onBrightness = viewModel::setBrightness,
            onShowFullScreen = viewModel::showFullScreen,
            onToggleTorch = viewModel::toggleTorch,
            onNavigate = onNavigate,
        )
    }
}
