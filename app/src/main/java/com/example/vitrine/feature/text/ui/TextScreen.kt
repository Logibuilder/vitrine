package com.example.vitrine.feature.text.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.Color
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.vitrine.feature.text.ui.display.TextDisplayScreen
import com.example.vitrine.feature.text.ui.editor.TextEditorScreen
import com.example.vitrine.feature.text.viewmodel.TextViewModel
import org.koin.androidx.compose.koinViewModel

/**
 * Point d'entrée de la feature texte.
 * Récupère l'état du ViewModel et choisit l'écran : édition ou affichage plein écran.
 * Les écrans en dessous ne connaissent pas le ViewModel : ils reçoivent un état et des callbacks.
 */
@Composable
fun TextScreen(
    viewModel: TextViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    if (state.isFullScreen) {
        TextDisplayScreen(
            text = state.shown,
            textColor = Color(state.readableTextColorArgb),
            bgColor = Color(state.bgColorArgb),
            onExit = viewModel::exitFullScreen,
        )
    } else {
        TextEditorScreen(
            state = state,
            onDraftChange = viewModel::onDraftChange,
            onClearDraft = viewModel::clearDraft,
            onShow = viewModel::showDraft,
            onTextColor = viewModel::setTextColor,
            onBgColor = viewModel::setBgColor,
        )
    }
}