package com.example.vitrine.feature.text.ui.editor

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.res.colorResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.vitrine.R
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.core.ui.components.GlassCard
import com.example.vitrine.core.ui.components.LedFrame
import com.example.vitrine.core.ui.components.MarqueeText
import com.example.vitrine.core.ui.components.SectionLabel
import com.example.vitrine.core.ui.components.VitrineScreen
import com.example.vitrine.feature.text.ui.model.BackgroundColorOptions
import com.example.vitrine.feature.text.ui.model.ColorOption
import com.example.vitrine.feature.text.ui.model.TextColorOptions
import com.example.vitrine.feature.text.viewmodel.TextUiState
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineDimens

/**
 * Écran d'édition : saisie du message, aperçu animé, choix des couleurs et menu des fonctionnalités.
 * Toucher l'aperçu affiche le message en plein écran.
 * Tout tient sur un seul écran : l'aperçu prend la place restante.
 */
@Composable
fun TextEditorScreen(
    state: TextUiState,
    onDraftChange: (String) -> Unit,
    onClearDraft: () -> Unit,
    onShow: () -> Unit,
    onTextColor: (Int) -> Unit,
    onBgColor: (Int) -> Unit,
    onNavigate: (AppDestination) -> Unit,
) {
    VitrineScreen(
        title = stringResource(R.string.text_title),
        current = AppDestination.TEXT,
        onNavigate = onNavigate,
    ) {
        MessageField(
            draft = state.draft,
            canShow = state.canShow,
            onDraftChange = onDraftChange,
            onClear = onClearDraft,
            onShow = onShow,
        )

        // L'aperçu prend la place restante (et rétrécit quand le clavier s'ouvre)
        PreviewSection(
            modifier = Modifier.weight(1f),
            draft = state.draft,
            textColor = Color(state.readableTextColorArgb),
            bgColor = Color(state.bgColorArgb),
            enabled = state.canShow,
            onClick = onShow,
        )

        ColorsCard(
            textColorArgb = state.textColorArgb,
            bgColorArgb = state.bgColorArgb,
            onTextColor = onTextColor,
            onBgColor = onBgColor,
        )
    }
}

/**
 * Champ de saisie de 3 lignes de haut : le texte revient à la ligne tout seul,
 * et les premières lignes remontent et se cachent quand on écrit plus.
 */
@Composable
private fun MessageField(
    draft: String,
    canShow: Boolean,
    onDraftChange: (String) -> Unit,
    onClear: () -> Unit,
    onShow: () -> Unit,
) {
    GlassCard {
        SectionLabel(stringResource(R.string.text_section_message))
        Spacer(Modifier.height(VitrineDimens.LabelGap))
        BasicTextField(
            value = draft,
            onValueChange = onDraftChange,
            singleLine = false,
            minLines = 3,
            maxLines = 3,
            // Touche « Terminer » du clavier : affiche en plein écran
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { if (canShow) onShow() }),
            modifier = Modifier.fillMaxWidth(),
            textStyle = TextStyle(
                fontSize = 20.sp,
                lineHeight = 28.sp,
                color = VitrineColors.TextPrimary,
            ),
            cursorBrush = SolidColor(VitrineColors.Cyan),
            decorationBox = { inner ->
                if (draft.isEmpty()) {
                    Text(
                        text = stringResource(R.string.text_placeholder),
                        color = VitrineColors.TextMuted,
                        fontSize = 20.sp,
                    )
                }
                inner()
            },
        )
        Spacer(Modifier.height(VitrineDimens.LabelGap))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = stringResource(R.string.text_char_count, draft.length),
                style = MaterialTheme.typography.labelSmall,
                color = VitrineColors.TextMuted,
            )
            if (draft.isNotEmpty()) {
                Text(
                    text = stringResource(R.string.text_clear),
                    style = MaterialTheme.typography.labelMedium,
                    color = VitrineColors.Cyan,
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .clickable(onClick = onClear)
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                )
            }
        }
    }
}

/**
 * Aperçu : cadre de LEDs animées, message sur une ligne qui défile comme à l'affichage.
 * Un appui sur l'aperçu affiche le message en plein écran.
 */
@Composable
private fun PreviewSection(
    draft: String,
    textColor: Color,
    bgColor: Color,
    enabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(22.dp)

    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (enabled) {
                Text(
                    text = stringResource(R.string.text_preview_hint),
                    style = MaterialTheme.typography.labelSmall,
                    color = VitrineColors.Cyan,
                )
            }
        }
        LedFrame(
            contentColor = bgColor,
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .clip(shape)
                .clickable(
                    enabled = enabled,
                    onClickLabel = stringResource(R.string.text_show_full_screen),
                    role = Role.Button,
                    onClick = onClick,
                ),
            cornerRadius = 22.dp,
            ledBand = 12.dp,
            ledSpacing = 15.dp,
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(12.dp),
                contentAlignment = Alignment.Center,
            ) {
                if (draft.isBlank()) {
                    Text(
                        text = stringResource(R.string.text_preview_empty),
                        color = textColor.copy(alpha = 0.4f),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                } else {
                    MarqueeText(text = draft, color = textColor)
                }
            }
        }
    }
}

@Composable
private fun ColorsCard(
    textColorArgb: Int,
    bgColorArgb: Int,
    onTextColor: (Int) -> Unit,
    onBgColor: (Int) -> Unit,
) {
    GlassCard {
        SectionLabel(stringResource(R.string.text_section_text_color))
        Spacer(Modifier.height(VitrineDimens.LabelGap))
        ColorRow(TextColorOptions, selectedArgb = textColorArgb, onSelect = onTextColor)

        Spacer(Modifier.height(12.dp))

        SectionLabel(stringResource(R.string.text_section_bg_color))
        Spacer(Modifier.height(VitrineDimens.LabelGap))
        ColorRow(BackgroundColorOptions, selectedArgb = bgColorArgb, onSelect = onBgColor)
    }
}

@Composable
private fun ColorRow(
    options: List<ColorOption>,
    selectedArgb: Int,
    onSelect: (Int) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceEvenly,
    ) {
        options.forEach { option ->
            val color = colorResource(option.color)
            val argb = color.toArgb()
            ColorSwatch(
                label = stringResource(option.label),
                color = color,
                selected = selectedArgb == argb,
                onClick = { onSelect(argb) },
            )
        }
    }
}
