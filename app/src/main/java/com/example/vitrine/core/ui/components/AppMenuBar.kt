package com.example.vitrine.core.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.colorResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.vitrine.R
import com.example.vitrine.core.navigation.AppDestination

/**
 * Menu de navigation entre les fonctionnalités, en forme de pilule.
 * L'élément courant est mis en avant par un dégradé violet -> cyan.
 */
@Composable
fun AppMenuBar(
    current: AppDestination,
    onNavigate: (AppDestination) -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(20.dp)

    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(shape)
            .background(colorResource(R.color.vitrine_surface))
            .border(1.dp, colorResource(R.color.vitrine_stroke), shape)
            .padding(5.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        AppDestination.entries.forEach { destination ->
            MenuItem(
                label = stringResource(destination.label),
                selected = destination == current,
                onClick = { if (destination != current) onNavigate(destination) },
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun MenuItem(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(15.dp)
    val violet = colorResource(R.color.vitrine_accent_violet)
    val cyan = colorResource(R.color.vitrine_accent_cyan)
    val textColor by animateColorAsState(
        targetValue = if (selected) colorResource(R.color.vitrine_background)
        else colorResource(R.color.vitrine_text_muted),
        label = "menu-item-text",
    )

    Box(
        modifier = modifier
            .fillMaxHeight()
            .clip(shape)
            .then(
                if (selected) Modifier.background(Brush.horizontalGradient(listOf(violet, cyan)))
                else Modifier.background(Color.Transparent)
            )
            .clickable(role = Role.Tab, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = textColor,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}