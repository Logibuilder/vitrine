package com.example.vitrine.core.navigation

import androidx.annotation.StringRes
import com.example.vitrine.R

/** Les fonctionnalités de l'application, telles qu'elles apparaissent dans le menu. */
enum class AppDestination(@StringRes val label: Int) {
    TEXT(R.string.menu_text),
    CLOCK(R.string.menu_clock),
    FLASHLIGHT(R.string.menu_flashlight),
    TIMER(R.string.menu_timer),
}

/**
 * Extra d'Intent qui ouvre l'application directement sur un écran (valeur : nom d'un [AppDestination]).
 * Utilisé par la notification des chronos.
 */
const val EXTRA_DESTINATION = "com.example.vitrine.extra.DESTINATION"
