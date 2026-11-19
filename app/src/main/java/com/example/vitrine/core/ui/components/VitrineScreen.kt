package com.example.vitrine.core.ui.components

import android.content.res.Configuration
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.displayCutoutPadding
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.ui.theme.LocalThemeController
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineDimens

/**
 * Gabarit commun à tous les écrans de l'application :
 * fond ivoire (ou noir profond), grand titre en haut, contenu au milieu, menu des fonctionnalités en bas.
 *
 * Le contenu reçoit un [ColumnScope] : un bloc avec `Modifier.weight(1f)` prend la place restante,
 * ce qui permet de tout faire tenir sur un seul écran.
 * Quand le clavier s'ouvre, le menu se masque et c'est ce bloc qui rétrécit.
 */
@OptIn(ExperimentalLayoutApi::class)
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
                // En paysage, évite l'encoche de la caméra
                .displayCutoutPadding()
                .imePadding()
                .padding(
                    horizontal = VitrineDimens.ScreenPaddingH,
                    vertical = VitrineDimens.ScreenPaddingV,
                ),
            verticalArrangement = Arrangement.spacedBy(VitrineDimens.SectionGap),
        ) {
            // En paysage, clavier ouvert : la hauteur manque, on masque aussi le titre
            val landscape = LocalConfiguration.current.orientation == Configuration.ORIENTATION_LANDSCAPE
            AnimatedVisibility(
                visible = !(landscape && WindowInsets.isImeVisible),
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically(),
            ) {
                ScreenHeader(eyebrow = stringResource(current.label), title = title)
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.spacedBy(VitrineDimens.SectionGap),
                content = content,
            )

            // Clavier ouvert : on masque le menu pour laisser la place à la saisie et à l'aperçu
            AnimatedVisibility(
                visible = !WindowInsets.isImeVisible,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically(),
            ) {
                AppMenuBar(current = current, onNavigate = onNavigate)
            }
        }
    }
}

/**
 * En-tête : à gauche, le nom de la fonctionnalité en petites capitales puis le grand titre ;
 * à droite, le bouton de thème.
 * Le bouton n'apparaît que si un [LocalThemeController] est fourni (pas dans les aperçus).
 */
@Composable
private fun ScreenHeader(
    eyebrow: String,
    title: String,
) {
    val themeController = LocalThemeController.current

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 4.dp, bottom = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = eyebrow.uppercase(),
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.6.sp,
                color = VitrineColors.Accent,
                maxLines = 1,
            )
            ScreenTitle(title)
        }

        if (themeController != null) {
            ThemeToggleButton(
                isDark = themeController.isDark,
                onClick = themeController.onToggle,
            )
        }
    }
}

/** Grand titre d'écran, aligné à gauche (deux lignes au plus). */
@Composable
fun ScreenTitle(
    text: String,
    modifier: Modifier = Modifier,
) {
    Text(
        text = text,
        style = MaterialTheme.typography.headlineSmall,
        color = VitrineColors.TextPrimary,
        maxLines = 2,
        overflow = TextOverflow.Ellipsis,
        modifier = modifier.fillMaxWidth(),
    )
}
