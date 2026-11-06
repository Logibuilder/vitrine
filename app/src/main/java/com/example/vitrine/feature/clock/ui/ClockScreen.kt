package com.example.vitrine.feature.clock.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import com.example.vitrine.R
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.core.ui.components.ComingSoonCard
import com.example.vitrine.core.ui.components.VitrineScreen

/** Écran Clock : utilise le même gabarit que les autres écrans. Contenu à venir. */
@Composable
fun ClockScreen(
    onNavigate: (AppDestination) -> Unit,
) {
    VitrineScreen(
        title = stringResource(R.string.clock_title),
        current = AppDestination.CLOCK,
        onNavigate = onNavigate,
    ) {
        ComingSoonCard(
            description = stringResource(R.string.clock_coming_soon),
            modifier = Modifier.weight(1f),
        )
    }
}
