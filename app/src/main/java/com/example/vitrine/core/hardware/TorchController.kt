package com.example.vitrine.core.hardware

import kotlinx.coroutines.flow.StateFlow

/** Flash de l'appareil photo, utilisé comme lampe torche. */
interface TorchController {
    /** Faux si l'appareil n'a pas de flash. */
    val isAvailable: Boolean

    /** État réel du flash, mis à jour aussi quand une autre application l'allume ou l'éteint. */
    val isOn: StateFlow<Boolean>

    /** Allume ou éteint le flash ; renvoie faux en cas d'échec (caméra déjà utilisée, etc.). */
    fun setEnabled(enabled: Boolean): Boolean
}
