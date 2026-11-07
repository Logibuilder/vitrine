package com.example.vitrine.feature.flashlight.viewmodel

import androidx.lifecycle.SavedStateHandle
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Les actions du ViewModel sont synchrones : on vérifie leur effet sur le flash
 * et sur le SavedStateHandle, sans avoir besoin de collecter uiState.
 */
class FlashlightViewModelTest {

    @Test
    fun `le bouton allume puis eteint le flash`() {
        val torch = FakeTorchController()
        val vm = FlashlightViewModel(SavedStateHandle(), torch)
        vm.toggleTorch()
        assertTrue(torch.isOn.value)
        vm.toggleTorch()
        assertFalse(torch.isOn.value)
    }

    @Test
    fun `repasser sur l'ecran eteint le flash`() {
        val torch = FakeTorchController()
        val vm = FlashlightViewModel(SavedStateHandle(), torch)
        vm.setSource(LightSource.TORCH)
        vm.toggleTorch()
        vm.setSource(LightSource.SCREEN)
        assertFalse(torch.isOn.value)
    }

    @Test
    fun `la luminosite enregistree est bornee`() {
        val handle = SavedStateHandle()
        val vm = FlashlightViewModel(handle, FakeTorchController())
        vm.setBrightness(2f)
        assertEquals(1f, handle.get<Float>("brightness")!!, 0.0001f)
    }

    @Test
    fun `sans flash le bouton ne fait rien`() {
        val torch = FakeTorchController(isAvailable = false)
        val vm = FlashlightViewModel(SavedStateHandle(), torch)
        vm.toggleTorch()
        assertFalse(torch.isOn.value)
    }
}
