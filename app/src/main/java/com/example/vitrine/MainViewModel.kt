package com.example.vitrine

import androidx.lifecycle.ViewModel
import com.example.vitrine.domain.model.ThemeMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * État global de l'application : le thème.
 *
 * Il démarre toujours sur le thème du téléphone. Le bouton bascule clair ↔ sombre ;
 * ce choix tient pendant la session (rotation comprise) mais n'est pas enregistré :
 * à la prochaine ouverture, l'application suit de nouveau le téléphone.
 */
class MainViewModel : ViewModel() {

    private val _themeMode = MutableStateFlow(ThemeMode.SYSTEM)
    val themeMode: StateFlow<ThemeMode> = _themeMode.asStateFlow()

    /** Passe à l'apparence inverse de celle affichée. */
    fun toggleTheme(isDarkNow: Boolean) {
        _themeMode.value = ThemeMode.toggledFrom(isDarkNow)
    }
}
