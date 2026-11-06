package com.example.vitrine.feature.text.viewmodel

import androidx.lifecycle.SavedStateHandle
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TextViewModelTest {

    private fun viewModel(handle: SavedStateHandle = SavedStateHandle()) = TextViewModel(handle)

    @Test
    fun `showDraft ne fait rien si le message est vide`() {
        val vm = viewModel()
        vm.onDraftChange("   ")
        vm.showDraft()
        assertFalse(vm.uiState.value.isFullScreen)
    }

    @Test
    fun `showDraft affiche le message sans espaces autour`() {
        val vm = viewModel()
        vm.onDraftChange("  Bonjour  ")
        vm.showDraft()
        assertTrue(vm.uiState.value.isFullScreen)
        assertEquals("Bonjour", vm.uiState.value.shown)
    }

    @Test
    fun `un saut de ligne est retire et lance l'affichage`() {
        val vm = viewModel()
        vm.onDraftChange("Salut\n")
        assertEquals("Salut", vm.uiState.value.draft)
        assertTrue(vm.uiState.value.isFullScreen)
    }

    @Test
    fun `l'etat est restaure depuis le SavedStateHandle`() {
        val handle = SavedStateHandle()
        viewModel(handle).apply {
            onDraftChange("Coucou")
            setBgColor(0xFF001133.toInt())
        }
        val restored = viewModel(handle).uiState.value
        assertEquals("Coucou", restored.draft)
        assertEquals(0xFF001133.toInt(), restored.bgColorArgb)
    }

    @Test
    fun `texte et fond identiques donnent une couleur lisible`() {
        val white = 0xFFFFFFFF.toInt()
        val black = 0xFF000000.toInt()
        assertEquals(black, TextUiState(textColorArgb = white, bgColorArgb = white).readableTextColorArgb)
        assertEquals(white, TextUiState(textColorArgb = black, bgColorArgb = black).readableTextColorArgb)
        assertEquals(white, TextUiState(textColorArgb = white, bgColorArgb = black).readableTextColorArgb)
    }
}