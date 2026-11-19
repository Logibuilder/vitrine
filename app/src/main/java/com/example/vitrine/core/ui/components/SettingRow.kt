package com.example.vitrine.core.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.vitrine.ui.theme.VitrineColors

/** Réglage sur une ligne : libellé à gauche, choix à droite. */
@Composable
fun SettingRow(
    label: String,
    modifier: Modifier = Modifier,
    control: @Composable () -> Unit,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            color = VitrineColors.TextPrimary,
        )
        control()
    }
}

/** Filet fin entre deux réglages d'une même carte. */
@Composable
fun CardDivider(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .padding(vertical = 12.dp)
            .fillMaxWidth()
            .height(1.dp)
            .background(VitrineColors.Divider),
    )
}
