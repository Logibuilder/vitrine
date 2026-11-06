package com.example.vitrine.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf

/**
 * État du bouton de thème.
 *
 * @property isDark vrai quand l'interface est affichée en sombre.
 * @property onToggle passe à l'apparence inverse (clair ↔ sombre).
 */
@Immutable
data class ThemeController(
    val isDark: Boolean,
    val onToggle: () -> Unit,
)

/**
 * Accès au bouton de thème depuis n'importe quel écran, sans le passer de paramètre en paramètre.
 * Fourni par MainActivity ; vaut null dans les aperçus Android Studio (le bouton est alors masqué).
 */
val LocalThemeController = staticCompositionLocalOf<ThemeController?> { null }
