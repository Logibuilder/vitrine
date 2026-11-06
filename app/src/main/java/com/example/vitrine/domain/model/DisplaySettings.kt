package com.example.vitrine.domain.model

/**
 * Thème de l'application.
 * Au lancement, c'est toujours [SYSTEM] (le thème du téléphone) ;
 * le bouton de thème passe ensuite en [LIGHT] ou [DARK] pour la session en cours.
 */
enum class ThemeMode {
    SYSTEM,
    LIGHT,
    DARK;

    companion object {
        /** Mode choisi par un appui sur le bouton : toujours l'inverse de ce qui est affiché. */
        fun toggledFrom(isDarkNow: Boolean): ThemeMode = if (isDarkNow) LIGHT else DARK
    }
}
