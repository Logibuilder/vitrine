package com.example.vitrine.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.dp

/** Espacements et formes communs à tous les écrans. */
object VitrineDimens {
    /** Marge horizontale des écrans. */
    val ScreenPaddingH = 16.dp

    /** Marge verticale des écrans. */
    val ScreenPaddingV = 12.dp

    /** Espace entre deux cartes. */
    val SectionGap = 10.dp

    /** Espace entre le libellé d'une carte et son contenu. */
    val LabelGap = 8.dp

    val CardPadding = 16.dp

    val CardRadius = 22.dp
    val MenuRadius = 22.dp
    val ControlRadius = 14.dp
}

object VitrineShapes {
    val Card = RoundedCornerShape(VitrineDimens.CardRadius)
    val Menu = RoundedCornerShape(VitrineDimens.MenuRadius)
    val Control = RoundedCornerShape(VitrineDimens.ControlRadius)

    /** Pilule : puces et éléments sélectionnés. */
    val Pill = RoundedCornerShape(percent = 50)
}
