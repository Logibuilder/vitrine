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
