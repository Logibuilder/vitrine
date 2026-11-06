package com.example.vitrine.core.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineShapes

/**
 * Sélecteur plat à plusieurs choix (comme « 1d / 7d / 14d ») :
 * l'option choisie est dans une pilule, les autres en texte discret.
 */
@Composable
fun <T> SegmentedControl(
    options: List<T>,
    selected: T,
    onSelect: (T) -> Unit,
    label: @Composable (T) -> String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .height(36.dp)
            .clip(VitrineShapes.Pill)
            .background(VitrineColors.Background)
            .padding(3.dp)
            .selectableGroup(),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        options.forEach { option ->
            val isSelected = option == selected
            val background by animateColorAsState(
                targetValue = if (isSelected) VitrineColors.Surface else Color.Transparent,
                label = "segment-background",
            )
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .clip(VitrineShapes.Pill)
                    .background(background)
                    .selectable(
                        selected = isSelected,
                        role = Role.RadioButton,
                        onClick = { onSelect(option) },
                    )
                    .padding(horizontal = 14.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = label(option),
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                    color = if (isSelected) VitrineColors.TextPrimary else VitrineColors.TextMuted,
                )
            }
        }
    }
}
