package com.example.vitrine.feature.flashlight.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import com.example.vitrine.R
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.core.ui.components.ComingSoonCard
import com.example.vitrine.core.ui.components.VitrineScreen

/** Écran Flashlight : utilise le même gabarit que les autres écrans. Contenu à venir. */
@Composable
fun FlashlightScreen(
    onNavigate: (AppDestination) -> Unit,
) {
    VitrineScreen(
        title = stringResource(R.string.flashlight_title),
        current = AppDestination.FLASHLIGHT,
        onNavigate = onNavigate,
    ) {
        ComingSoonCard(
            description = stringResource(R.string.flashlight_coming_soon),
            modifier = Modifier.weight(1f),
        )
    }
}
