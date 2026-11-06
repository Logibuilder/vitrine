package com.example.vitrine.feature.text.viewmodel

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Gère le message, ses couleurs et le passage en plein écran.
 * L'état est sauvegardé dans le [SavedStateHandle] : il survit à la rotation
 * et à la mort du processus.
 */
class TextViewModel(
    private val savedState: SavedStateHandle,
) : ViewModel() {

    private val _uiState = MutableStateFlow(restore())
    val uiState: StateFlow<TextUiState> = _uiState.asStateFlow()

    /**
     * Le message tient sur une seule ligne : un saut de ligne (touche Entrée
     * d'un clavier physique) est retiré et lance l'affichage.
     */
    fun onDraftChange(value: String) {
        if ('\n' in value) {
            update { it.copy(draft = value.replace("\n", "")) }
            showDraft()
        } else {
            update { it.copy(draft = value) }
        }
    }

    fun clearDraft() = update { it.copy(draft = "") }

    /** Affiche le message en plein écran, s'il n'est pas vide. */
    fun showDraft() {
        if (!_uiState.value.canShow) return
        update { it.copy(shown = it.draft.trim(), isFullScreen = true) }
    }

    fun exitFullScreen() = update { it.copy(isFullScreen = false) }

    fun setTextColor(argb: Int) = update { it.copy(textColorArgb = argb) }

    fun setBgColor(argb: Int) = update { it.copy(bgColorArgb = argb) }

    private fun update(transform: (TextUiState) -> TextUiState) {
        _uiState.update { current -> transform(current).also(::save) }
    }

    private fun restore() = TextUiState(
        draft = savedState[Keys.DRAFT] ?: "",
        shown = savedState[Keys.SHOWN] ?: "",
        textColorArgb = savedState[Keys.TEXT_COLOR] ?: TextUiState.DEFAULT_TEXT_COLOR,
        bgColorArgb = savedState[Keys.BG_COLOR] ?: TextUiState.DEFAULT_BG_COLOR,
        isFullScreen = savedState[Keys.FULL_SCREEN] ?: false,
    )

    private fun save(state: TextUiState) {
        savedState[Keys.DRAFT] = state.draft
        savedState[Keys.SHOWN] = state.shown
        savedState[Keys.TEXT_COLOR] = state.textColorArgb
        savedState[Keys.BG_COLOR] = state.bgColorArgb
        savedState[Keys.FULL_SCREEN] = state.isFullScreen
    }

    private object Keys {
        const val DRAFT = "draft"
        const val SHOWN = "shown"
        const val TEXT_COLOR = "textColor"
        const val BG_COLOR = "bgColor"
        const val FULL_SCREEN = "isFullScreen"
    }
}