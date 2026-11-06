package com.example.vitrine.core.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineDimens

/**
 * Gabarit commun à tous les écrans de l'application :
 * fond sombre, titre centré en haut, contenu au milieu, menu des fonctionnalités en bas.
 *
 * Le contenu reçoit un [ColumnScope] : un bloc avec `Modifier.weight(1f)` prend la place restante,
 * ce qui permet de tout faire tenir sur un seul écran.
 * Quand le clavier s'ouvre, c'est ce bloc qui rétrécit et le menu reste visible.
 */
@Composable
fun VitrineScreen(
    title: String,
    current: AppDestination,
    onNavigate: (AppDestination) -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(VitrineColors.Background),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .imePadding()
                .padding(
                    horizontal = VitrineDimens.ScreenPaddingH,
                    vertical = VitrineDimens.ScreenPaddingV,
                ),
            verticalArrangement = Arrangement.spacedBy(VitrineDimens.SectionGap),
        ) {
            ScreenTitle(title)

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.spacedBy(VitrineDimens.SectionGap),
                content = content,
            )

            AppMenuBar(current = current, onNavigate = onNavigate)
        }
    }
}

/** Titre d'écran, centré. */
@Composable
fun ScreenTitle(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleLarge,
        color = VitrineColors.TextPrimary,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth(),
    )
}
