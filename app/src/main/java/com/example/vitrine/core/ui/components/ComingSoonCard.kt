package com.example.vitrine.core.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.example.vitrine.R
import com.example.vitrine.ui.theme.VitrineColors

/** Carte affichée par une fonctionnalité pas encore développée. */
@Composable
fun ComingSoonCard(
    description: String,
    modifier: Modifier = Modifier,
) {
    VitrineCard(modifier = modifier) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            StatusDot(text = stringResource(R.string.coming_soon), color = VitrineColors.Warning)
            Text(
                text = description,
                style = MaterialTheme.typography.headlineMedium,
                color = VitrineColors.TextPrimary,
            )
        }
    }
}
