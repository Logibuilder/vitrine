package com.example.vitrine.feature.text.viewmodel

/**
 * État de l'écran texte.
 *
 * @property draft message en cours de saisie.
 * @property shown message affiché en plein écran (figé au moment de l'affichage).
 * @property textColorArgb couleur du texte choisie (ARGB).
 * @property bgColorArgb couleur du fond choisie (ARGB).
 * @property isFullScreen vrai quand le message est affiché en plein écran.
 */
data class TextUiState(
    val draft: String = "",
    val shown: String = "",
    val textColorArgb: Int = DEFAULT_TEXT_COLOR,
    val bgColorArgb: Int = DEFAULT_BG_COLOR,
    val isFullScreen: Boolean = false,
) {
    /** Le message peut être affiché s'il contient autre chose que des espaces. */
    val canShow: Boolean get() = draft.isNotBlank()

    /**
     * Couleur réellement utilisée pour le texte : si elle est identique au fond,
     * on bascule en noir ou blanc pour que le message reste lisible.
     */
    val readableTextColorArgb: Int get() = readableTextColor(textColorArgb, bgColorArgb)

    companion object {
        const val DEFAULT_TEXT_COLOR: Int = WHITE
        const val DEFAULT_BG_COLOR: Int = BLACK
    }
}

private const val WHITE: Int = -0x1          // 0xFFFFFFFF
private const val BLACK: Int = -0x1000000    // 0xFF000000

internal fun readableTextColor(textArgb: Int, bgArgb: Int): Int = when {
    textArgb != bgArgb -> textArgb
    luminance(bgArgb) > 0.5 -> BLACK
    else -> WHITE
}

/** Luminance perçue approximative (0 = noir, 1 = blanc). */
private fun luminance(argb: Int): Double {
    val r = (argb shr 16 and 0xFF) / 255.0
    val g = (argb shr 8 and 0xFF) / 255.0
    val b = (argb and 0xFF) / 255.0
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
}