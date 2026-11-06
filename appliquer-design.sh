#!/usr/bin/env bash
# Applique le design commun de Vitrine.
#   ./appliquer-design.sh         -> supprime l'ancien fichier et crée les nouveaux
#   ./appliquer-design.sh --all   -> fait la même chose ET remplace aussi les fichiers modifiés
# À lancer depuis la racine du projet VITRINE (là où se trouve settings.gradle.kts).
set -euo pipefail

if [[ ! -f settings.gradle.kts || ! -d app/src/main ]]; then
  echo "Erreur : lancez ce script depuis la racine du projet VITRINE." >&2
  exit 1
fi

ALL=false
[[ "${1:-}" == "--all" ]] && ALL=true

write() {  # write <chemin> : écrit l'entrée standard dans le fichier, en créant les dossiers
  mkdir -p "$(dirname "$1")"
  cat > "$1"
  echo "  écrit : $1"
}

# 1. Fichier à supprimer
OLD=app/src/main/java/com/example/vitrine/feature/text/ui/theme/TextScreenColors.kt
if [[ -f "$OLD" ]]; then
  if git ls-files --error-unmatch "$OLD" >/dev/null 2>&1; then git rm -q "$OLD"; else rm "$OLD"; fi
  echo "  supprimé : $OLD"
  rmdir "$(dirname "$OLD")" 2>/dev/null || true
else
  echo "  déjà supprimé : $OLD"
fi

# 2. Nouveaux fichiers
echo "Création des nouveaux fichiers :"
write app/src/main/java/com/example/vitrine/core/navigation/VitrineApp.kt <<'EOF_VITRINE'
package com.example.vitrine.core.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.example.vitrine.feature.clock.ui.ClockScreen
import com.example.vitrine.feature.flashlight.ui.FlashlightScreen
import com.example.vitrine.feature.text.ui.TextScreen
import com.example.vitrine.feature.timer.ui.TimerScreen

/**
 * Racine de l'application : affiche l'écran de la fonctionnalité choisie dans le menu.
 * L'écran courant survit à la rotation. Le bouton retour ramène à l'écran Texte.
 */
@Composable
fun VitrineApp() {
    var destination by rememberSaveable { mutableStateOf(AppDestination.TEXT) }
    val navigate: (AppDestination) -> Unit = { destination = it }

    when (destination) {
        AppDestination.TEXT -> TextScreen(onNavigate = navigate)
        AppDestination.CLOCK -> ClockScreen(onNavigate = navigate)
        AppDestination.FLASHLIGHT -> FlashlightScreen(onNavigate = navigate)
        AppDestination.TIMER -> TimerScreen(onNavigate = navigate)
    }

    BackHandler(enabled = destination != AppDestination.TEXT) {
        destination = AppDestination.TEXT
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/core/ui/components/ComingSoonCard.kt <<'EOF_VITRINE'
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
EOF_VITRINE

write app/src/main/java/com/example/vitrine/core/ui/components/GlassCard.kt <<'EOF_VITRINE'
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
EOF_VITRINE

write app/src/main/java/com/example/vitrine/core/ui/components/VitrineScreen.kt <<'EOF_VITRINE'
package com.example.vitrine.core.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineDimens

/**
 * Gabarit commun à tous les écrans de l'application :
 * fond sombre, titre centré en haut, contenu au milieu, menu des fonctionnalités en bas.
 *
 * Le contenu reçoit un [ColumnScope] : un bloc avec `Modifier.weight(1f)` prend la place restante,
 * ce qui permet de tout faire tenir sur un seul écran.
 * Quand le clavier s'ouvre, c'est ce bloc qui rétrécit et le menu reste visible.
 */
@Composable
fun VitrineScreen(
    title: String,
    current: AppDestination,
    onNavigate: (AppDestination) -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(VitrineColors.Background),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .imePadding()
                .padding(
                    horizontal = VitrineDimens.ScreenPaddingH,
                    vertical = VitrineDimens.ScreenPaddingV,
                ),
            verticalArrangement = Arrangement.spacedBy(VitrineDimens.SectionGap),
        ) {
            ScreenTitle(title)

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.spacedBy(VitrineDimens.SectionGap),
                content = content,
            )

            AppMenuBar(current = current, onNavigate = onNavigate)
        }
    }
}

/** Titre d'écran, centré. */
@Composable
fun ScreenTitle(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleLarge,
        color = VitrineColors.TextPrimary,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth(),
    )
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/ui/theme/Dimens.kt <<'EOF_VITRINE'
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
EOF_VITRINE

# 3. Fichiers modifiés (seulement avec --all)
if $ALL; then
echo "Remplacement des fichiers modifiés :"
write app/src/main/java/com/example/vitrine/MainActivity.kt <<'EOF_VITRINE'
package com.example.vitrine

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.example.vitrine.core.navigation.VitrineApp
import com.example.vitrine.ui.theme.VitrineTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            VitrineTheme {
                VitrineApp()
            }
        }
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/core/ui/components/AppMenuBar.kt <<'EOF_VITRINE'
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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineShapes

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
    val shape = VitrineShapes.Menu

    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(shape)
            .background(VitrineColors.Surface)
            .border(1.dp, VitrineColors.Stroke, shape)
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
    val shape = VitrineShapes.Control
    val violet = VitrineColors.Violet
    val cyan = VitrineColors.Cyan
    val textColor by animateColorAsState(
        targetValue = if (selected) VitrineColors.Background else VitrineColors.TextMuted,
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
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/clock/ui/ClockScreen.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.clock.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import com.example.vitrine.R
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.core.ui.components.ComingSoonCard
import com.example.vitrine.core.ui.components.VitrineScreen

/** Écran Clock : utilise le même gabarit que les autres écrans. Contenu à venir. */
@Composable
fun ClockScreen(
    onNavigate: (AppDestination) -> Unit,
) {
    VitrineScreen(
        title = stringResource(R.string.clock_title),
        current = AppDestination.CLOCK,
        onNavigate = onNavigate,
    ) {
        ComingSoonCard(
            description = stringResource(R.string.clock_coming_soon),
            modifier = Modifier.weight(1f),
        )
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/flashlight/ui/FlashlightScreen.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.flashlight.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import com.example.vitrine.R
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.core.ui.components.ComingSoonCard
import com.example.vitrine.core.ui.components.VitrineScreen

/** Écran Flashlight : utilise le même gabarit que les autres écrans. Contenu à venir. */
@Composable
fun FlashlightScreen(
    onNavigate: (AppDestination) -> Unit,
) {
    VitrineScreen(
        title = stringResource(R.string.flashlight_title),
        current = AppDestination.FLASHLIGHT,
        onNavigate = onNavigate,
    ) {
        ComingSoonCard(
            description = stringResource(R.string.flashlight_coming_soon),
            modifier = Modifier.weight(1f),
        )
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/text/ui/editor/EditorComponents.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.text.ui.editor

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineShapes

/** Pastille de couleur avec son libellé ; un anneau lumineux indique la sélection. */
@Composable
internal fun ColorSwatch(
    label: String,
    color: Color,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val ring by animateColorAsState(
        targetValue = if (selected) VitrineColors.Cyan else Color.Transparent,
        label = "swatch-ring",
    )

    Column(
        modifier = Modifier
            .clip(VitrineShapes.Control)
            .clickable(onClick = onClick)
            .padding(2.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .border(2.dp, ring, CircleShape)
                .padding(4.dp)
                .clip(CircleShape)
                .background(color),
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = if (selected) VitrineColors.TextPrimary else VitrineColors.TextMuted,
        )
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/text/ui/editor/TextEditorScreen.kt <<'EOF_VITRINE'
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
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/timer/ui/TimerScreen.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.timer.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import com.example.vitrine.R
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.core.ui.components.ComingSoonCard
import com.example.vitrine.core.ui.components.VitrineScreen

/** Écran Timer : utilise le même gabarit que les autres écrans. Contenu à venir. */
@Composable
fun TimerScreen(
    onNavigate: (AppDestination) -> Unit,
) {
    VitrineScreen(
        title = stringResource(R.string.timer_title),
        current = AppDestination.TIMER,
        onNavigate = onNavigate,
    ) {
        ComingSoonCard(
            description = stringResource(R.string.timer_coming_soon),
            modifier = Modifier.weight(1f),
        )
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/ui/theme/Color.kt <<'EOF_VITRINE'
package com.example.vitrine.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.colorResource
import com.example.vitrine.R

/**
 * Palette de l'application, lue depuis res/values/colors_vitrine.xml.
 * C'est la seule source de couleurs de l'interface : tous les écrans passent par ici.
 * Les getters sont @Composable car colorResource() a besoin du contexte Compose.
 */
object VitrineColors {
    /** Fond des écrans. */
    val Background: Color @Composable get() = colorResource(R.color.vitrine_background)

    /** Fond des cartes et du menu. */
    val Surface: Color @Composable get() = colorResource(R.color.vitrine_surface)

    /** Bordure fine des cartes. */
    val Stroke: Color @Composable get() = colorResource(R.color.vitrine_stroke)

    val TextPrimary: Color @Composable get() = colorResource(R.color.vitrine_text_primary)
    val TextMuted: Color @Composable get() = colorResource(R.color.vitrine_text_muted)

    /** Accent principal : sélection, liens, curseur. */
    val Cyan: Color @Composable get() = colorResource(R.color.vitrine_accent_cyan)

    /** Accent secondaire : début des dégradés. */
    val Violet: Color @Composable get() = colorResource(R.color.vitrine_accent_violet)
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/ui/theme/Theme.kt <<'EOF_VITRINE'
package com.example.vitrine.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/**
 * Thème unique de l'application : sombre, avec les accents violet et cyan.
 * Les couleurs dynamiques (Material You) et le thème clair sont volontairement désactivés
 * pour que l'application garde la même identité sur tous les téléphones.
 */
@Composable
fun VitrineTheme(content: @Composable () -> Unit) {
    val colorScheme = darkColorScheme(
        primary = VitrineColors.Cyan,
        onPrimary = VitrineColors.Background,
        secondary = VitrineColors.Violet,
        onSecondary = Color.White,
        background = VitrineColors.Background,
        onBackground = VitrineColors.TextPrimary,
        surface = VitrineColors.Surface,
        onSurface = VitrineColors.TextPrimary,
        surfaceVariant = VitrineColors.Surface,
        onSurfaceVariant = VitrineColors.TextMuted,
        outline = VitrineColors.Stroke,
    )

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        shapes = Shapes(
            small = VitrineShapes.Control,
            medium = VitrineShapes.Menu,
            large = VitrineShapes.Card,
        ),
        content = content,
    )
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/ui/theme/Type.kt <<'EOF_VITRINE'
package com.example.vitrine.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * Typographie de l'application.
 * - titleLarge : titre des écrans
 * - titleMedium : titres de cartes
 * - bodyLarge / bodyMedium : textes courants
 * - labelMedium : libellés de section (en majuscules) et menu
 * - labelSmall : indications et compteurs
 */
val Typography = Typography(
    titleLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Bold,
        fontSize = 22.sp,
        lineHeight = 28.sp,
    ),
    titleMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.SemiBold,
        fontSize = 17.sp,
        lineHeight = 24.sp,
    ),
    bodyLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.3.sp,
    ),
    bodyMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.2.sp,
    ),
    labelMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Medium,
        fontSize = 12.sp,
        lineHeight = 16.sp,
        letterSpacing = 1.2.sp,
    ),
    labelSmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Medium,
        fontSize = 11.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.5.sp,
    ),
)
EOF_VITRINE

write app/src/main/res/values/strings_menu.xml <<'EOF_VITRINE'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Menu de navigation entre les fonctionnalités -->
    <string name="menu_text">Texte</string>
    <string name="menu_clock">Horloge</string>
    <string name="menu_flashlight">Lampe</string>
    <string name="menu_timer">Minuteur</string>

    <!-- Fonctionnalités pas encore développées -->
    <string name="coming_soon">Bientôt disponible</string>
    <string name="clock_title">L\'heure, en très grand</string>
    <string name="clock_coming_soon">Une horloge plein écran, lisible de loin.</string>
    <string name="flashlight_title">Votre écran, en lampe</string>
    <string name="flashlight_coming_soon">L\'écran devient une lumière réglable en couleur et en intensité.</string>
    <string name="timer_title">Vos minuteurs</string>
    <string name="timer_coming_soon">Des minuteurs par tâche, qui continuent même écran éteint.</string>
</resources>
EOF_VITRINE

write app/src/main/res/values/strings_text.xml <<'EOF_VITRINE'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Feature texte : écran d'édition -->
    <string name="text_title">Votre message, en très grand</string>
    <string name="text_section_message">Message</string>
    <string name="text_placeholder">Saisir le message à afficher…</string>
    <string name="text_char_count">%1$d caractères</string>
    <string name="text_clear">Effacer</string>
    <string name="text_section_preview">Aperçu</string>
    <string name="text_preview_empty">Votre aperçu apparaîtra ici</string>
    <string name="text_section_text_color">Couleur du texte</string>
    <string name="text_section_bg_color">Couleur du fond</string>
    <string name="text_preview_hint">Touchez pour afficher</string>
    <!-- Lu par TalkBack quand on touche l'aperçu -->
    <string name="text_show_full_screen">Afficher en plein écran</string>

    <!-- Noms des couleurs -->
    <string name="color_white">Blanc</string>
    <string name="color_yellow">Jaune</string>
    <string name="color_green">Vert</string>
    <string name="color_red">Rouge</string>
    <string name="color_black">Noir</string>
    <string name="color_night_blue">Bleu nuit</string>
    <string name="color_night_red">Rouge nuit</string>
</resources>
EOF_VITRINE

write app/src/main/res/values/themes.xml <<'EOF_VITRINE'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Thème sombre : évite un flash blanc au lancement, avant que Compose ne dessine. -->
    <style name="Theme.Vitrine" parent="android:Theme.Material.NoActionBar">
        <item name="android:windowBackground">@color/vitrine_background</item>
    </style>
</resources>
EOF_VITRINE

else
  echo
  echo "Fichiers existants NON remplacés (copiez-les à la main, ou relancez avec --all) :"
  echo "  - app/src/main/java/com/example/vitrine/MainActivity.kt"
  echo "  - app/src/main/java/com/example/vitrine/core/ui/components/AppMenuBar.kt"
  echo "  - app/src/main/java/com/example/vitrine/feature/clock/ui/ClockScreen.kt"
  echo "  - app/src/main/java/com/example/vitrine/feature/flashlight/ui/FlashlightScreen.kt"
  echo "  - app/src/main/java/com/example/vitrine/feature/text/ui/editor/EditorComponents.kt"
  echo "  - app/src/main/java/com/example/vitrine/feature/text/ui/editor/TextEditorScreen.kt"
  echo "  - app/src/main/java/com/example/vitrine/feature/timer/ui/TimerScreen.kt"
  echo "  - app/src/main/java/com/example/vitrine/ui/theme/Color.kt"
  echo "  - app/src/main/java/com/example/vitrine/ui/theme/Theme.kt"
  echo "  - app/src/main/java/com/example/vitrine/ui/theme/Type.kt"
  echo "  - app/src/main/res/values/strings_menu.xml"
  echo "  - app/src/main/res/values/strings_text.xml"
  echo "  - app/src/main/res/values/themes.xml"
fi

echo
echo "Terminé. Dans Android Studio : File > Sync Project, puis Build > Rebuild Project."
