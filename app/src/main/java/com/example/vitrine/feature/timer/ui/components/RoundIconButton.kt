package com.example.vitrine.feature.timer.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp

/** Bouton rond plat contenant une icône dessinée. */
@Composable
fun RoundIconButton(
    contentDescription: String,
    background: Color,
    size: Dp,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    icon: @Composable () -> Unit,
) {
    Box(
        modifier = modifier
            .size(size)
            .alpha(if (enabled) 1f else 0.4f)
            .clip(CircleShape)
            .background(background)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        icon()
    }
}
