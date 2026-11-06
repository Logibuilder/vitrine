package com.example.vitrine.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.dp

/** Espacements et formes communs à tous les écrans. */
object VitrineDimens {
    /** Marge horizontale des écrans. */
    val ScreenPaddingH = 20.dp

    /** Marge verticale des écrans. */
    val ScreenPaddingV = 16.dp

    /** Espace entre deux blocs d'un écran. */
    val SectionGap = 12.dp

    /** Espace entre un libellé de section et son contenu. */
    val LabelGap = 8.dp

    val CardPaddingH = 16.dp
    val CardPaddingV = 14.dp

    val CardRadius = 24.dp
    val MenuRadius = 20.dp
    val ControlRadius = 15.dp
}

object VitrineShapes {
    val Card = RoundedCornerShape(VitrineDimens.CardRadius)
    val Menu = RoundedCornerShape(VitrineDimens.MenuRadius)
    val Control = RoundedCornerShape(VitrineDimens.ControlRadius)
}
