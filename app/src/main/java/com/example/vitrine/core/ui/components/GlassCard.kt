package com.example.vitrine.core.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineDimens
import com.example.vitrine.ui.theme.VitrineShapes

/** Carte sombre aux coins arrondis, avec une bordure fine. Brique de base de tous les écrans. */
@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(VitrineShapes.Card)
            .background(VitrineColors.Surface)
            .border(1.dp, VitrineColors.Stroke, VitrineShapes.Card)
            .padding(horizontal = VitrineDimens.CardPaddingH, vertical = VitrineDimens.CardPaddingV),
        content = content,
    )
}

/** Petit titre de section, en majuscules. */
@Composable
fun SectionLabel(
    text: String,
    modifier: Modifier = Modifier,
) {
    Text(
        text = text.uppercase(),
        style = MaterialTheme.typography.labelMedium,
        color = VitrineColors.TextMuted,
        modifier = modifier,
    )
}
