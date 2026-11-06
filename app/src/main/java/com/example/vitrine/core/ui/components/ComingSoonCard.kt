package com.example.vitrine.core.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.example.vitrine.R
import com.example.vitrine.ui.theme.VitrineColors

/** Carte affichée par une fonctionnalité pas encore développée. */
@Composable
fun ComingSoonCard(
    description: String,
    modifier: Modifier = Modifier,
) {
    GlassCard(modifier = modifier) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = stringResource(R.string.coming_soon),
                style = MaterialTheme.typography.titleMedium,
                color = VitrineColors.Cyan,
            )
            Text(
                text = description,
                style = MaterialTheme.typography.bodyMedium,
                color = VitrineColors.TextMuted,
                textAlign = TextAlign.Center,
            )
        }
    }
}
