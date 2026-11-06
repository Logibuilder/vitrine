package com.example.vitrine.core.navigation

import androidx.activity.compose.BackHandler
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
 */
@Composable
fun VitrineApp() {
    var destination by rememberSaveable { mutableStateOf(AppDestination.TEXT) }
    val navigate: (AppDestination) -> Unit = { destination = it }

    when (destination) {
        AppDestination.TEXT -> TextScreen(onNavigate = navigate)
        AppDestination.CLOCK -> ClockScreen(onNavigate = navigate)
        AppDestination.FLASHLIGHT -> FlashlightScreen(onNavigate = navigate)
        AppDestination.TIMER -> TimerScreen(onNavigate = navigate)
    }

    BackHandler(enabled = destination != AppDestination.TEXT) {
        destination = AppDestination.TEXT
    }
}
