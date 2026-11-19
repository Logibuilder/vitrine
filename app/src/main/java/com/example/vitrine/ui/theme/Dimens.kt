package com.example.vitrine.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.dp

/** Espacements et formes communs à tous les écrans. */
object VitrineDimens {
    /** Marge horizontale des écrans. */
    val ScreenPaddingH = 20.dp

    /** Marge verticale des écrans. */
    val ScreenPaddingV = 12.dp

    /** Espace entre deux cartes. */
    val SectionGap = 12.dp

    /** Espace entre le libellé d'une carte et son contenu. */
    val LabelGap = 8.dp

    val CardPadding = 18.dp

    val CardRadius = 28.dp
    val MenuRadius = 22.dp
    val ControlRadius = 16.dp
}

object VitrineShapes {
    val Card = RoundedCornerShape(VitrineDimens.CardRadius)
    val Menu = RoundedCornerShape(VitrineDimens.MenuRadius)
    val Control = RoundedCornerShape(VitrineDimens.ControlRadius)

    /** Pilule : puces et éléments sélectionnés. */
    val Pill = RoundedCornerShape(percent = 50)
}
