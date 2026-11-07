package com.example.vitrine.feature.flashlight.viewmodel

import com.example.vitrine.core.hardware.TorchController
import kotlinx.coroutines.flow.MutableStateFlow

/** Flash simulé pour les tests : pas de caméra, juste un état. */
class FakeTorchController(override val isAvailable: Boolean = true) : TorchController {
    override val isOn = MutableStateFlow(false)
    override fun setEnabled(enabled: Boolean): Boolean {
        if (!isAvailable) return false
        isOn.value = enabled
        return true
    }
}
