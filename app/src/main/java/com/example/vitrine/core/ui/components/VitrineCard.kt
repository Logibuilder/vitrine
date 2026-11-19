package com.example.vitrine.core.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineDimens
import com.example.vitrine.ui.theme.VitrineShapes

/**
 * Carte : surface aux grands coins arrondis, filet fin et ombre très douce.
 * Brique de base de tous les écrans.
 * Avec [onClick], toute la carte devient touchable (effet d'appui dessiné par-dessus le fond).
 */
@Composable
fun VitrineCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    onClickLabel: String? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .softShadow()
            .clip(VitrineShapes.Card)
            .background(VitrineColors.Surface)
            .border(1.dp, VitrineColors.Divider, VitrineShapes.Card)
            .then(
                if (onClick != null) {
                    Modifier.clickable(onClickLabel = onClickLabel, role = Role.Button, onClick = onClick)
                } else {
                    Modifier
                }
            )
            .padding(VitrineDimens.CardPadding),
        content = content,
    )
}

/** Ombre diffuse et légère, qui détache la surface du fond sans l'alourdir. */
internal fun Modifier.softShadow(
    shape: Shape = VitrineShapes.Card,
): Modifier = shadow(
    elevation = 10.dp,
    shape = shape,
    clip = false,
    ambientColor = Color.Black.copy(alpha = 0.04f),
    spotColor = Color.Black.copy(alpha = 0.10f),
)

/** Libellé de section : petites capitales espacées, discrètes. */
@Composable
fun SectionLabel(
    text: String,
    modifier: Modifier = Modifier,
) {
    Text(
        text = text.uppercase(),
        style = MaterialTheme.typography.labelSmall,
        letterSpacing = 1.2.sp,
        color = VitrineColors.TextMuted,
        modifier = modifier,
    )
}

/** État dans une petite pastille teintée : point de couleur et texte (ex. « ● En cours »). */
@Composable
fun StatusDot(
    text: String,
    color: Color,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .clip(VitrineShapes.Pill)
            .background(color.copy(alpha = 0.12f))
            .padding(horizontal = 9.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(
            modifier = Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(color),
        )
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            color = VitrineColors.TextPrimary,
            maxLines = 1,
        )
    }
}
