#!/usr/bin/env bash
# Passe Vitrine au design plat et clair.
#   ./appliquer-design-plat.sh   -> supprime l'ancien fichier, crée le nouveau ET remplace les fichiers modifiés
# À lancer depuis la racine du projet VITRINE (là où se trouve settings.gradle.kts).
# Pensez à faire un commit avant : les fichiers existants sont écrasés.
set -euo pipefail

if [[ ! -f settings.gradle.kts || ! -d app/src/main ]]; then
  echo "Erreur : lancez ce script depuis la racine du projet VITRINE." >&2
  exit 1
fi

write() {  # write <chemin> : écrit l'entrée standard dans le fichier, en créant les dossiers
  mkdir -p "$(dirname "$1")"
  cat > "$1"
  echo "  écrit : $1"
}

remove() {  # remove <chemin> : supprime le fichier (avec git rm s'il est suivi)
  if [[ -f "$1" ]]; then
    if git ls-files --error-unmatch "$1" >/dev/null 2>&1; then git rm -q "$1"; else rm "$1"; fi
    echo "  supprimé : $1"
  else
    echo "  déjà absent : $1"
  fi
}

echo "Suppression :"
remove app/src/main/java/com/example/vitrine/core/ui/components/GlassCard.kt

echo "Création :"
write app/src/main/java/com/example/vitrine/core/ui/components/VitrineCard.kt <<'EOF_VITRINE'
package com.example.vitrine.core.ui.components

import androidx.compose.foundation.background
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineDimens
import com.example.vitrine.ui.theme.VitrineShapes

/** Carte plate : fond blanc, coins arrondis, ni bordure ni ombre. Brique de base de tous les écrans. */
@Composable
fun VitrineCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(VitrineShapes.Card)
            .background(VitrineColors.Surface)
            .padding(VitrineDimens.CardPadding),
        content = content,
    )
}

/** Libellé d'une carte, discret, en minuscules (ex. « Message », « Couleur du fond »). */
@Composable
fun SectionLabel(
    text: String,
    modifier: Modifier = Modifier,
) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelLarge,
        color = VitrineColors.TextMuted,
        modifier = modifier,
    )
}

/** Petit état précédé d'un point de couleur (ex. « ● En charge »). */
@Composable
fun StatusDot(
    text: String,
    color: Color,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier,
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
        )
    }
}
EOF_VITRINE

echo "Remplacement :"
write app/src/main/java/com/example/vitrine/MainActivity.kt <<'EOF_VITRINE'
package com.example.vitrine

import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.example.vitrine.core.navigation.VitrineApp
import com.example.vitrine.ui.theme.VitrineTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Barres système transparentes avec icônes foncées : l'interface est claire,
        // même quand le téléphone est en mode sombre.
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT),
        )
        super.onCreate(savedInstanceState)
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
 * Menu de navigation entre les fonctionnalités, plat :
 * une carte blanche, l'élément courant dans une pilule gris clair (comme un sélecteur « 1d / 7d / 14d »).
 */
@Composable
fun AppMenuBar(
    current: AppDestination,
    onNavigate: (AppDestination) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(52.dp)
            .clip(VitrineShapes.Menu)
            .background(VitrineColors.Surface)
            .padding(6.dp),
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
    val background by animateColorAsState(
        targetValue = if (selected) VitrineColors.SurfaceMuted else Color.Transparent,
        label = "menu-item-background",
    )
    val textColor by animateColorAsState(
        targetValue = if (selected) VitrineColors.TextPrimary else VitrineColors.TextMuted,
        label = "menu-item-text",
    )

    Box(
        modifier = modifier
            .fillMaxHeight()
            .clip(VitrineShapes.Pill)
            .background(background)
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

write app/src/main/java/com/example/vitrine/core/ui/components/ComingSoonCard.kt <<'EOF_VITRINE'
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
EOF_VITRINE

write app/src/main/java/com/example/vitrine/core/ui/components/LedFrame.kt <<'EOF_VITRINE'
package com.example.vitrine.core.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.res.colorResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.example.vitrine.R
import kotlin.math.PI
import kotlin.math.cos

/** Valeurs par défaut du [LedFrame], lues depuis res/values/colors_vitrine.xml. */
object LedFrameDefaults {

    /** Couleurs des LEDs, dans l'ordre où elles se suivent sur la guirlande. */
    @Composable
    fun palette(): List<Color> {
        val c1 = colorResource(R.color.led_color_1)
        val c2 = colorResource(R.color.led_color_2)
        val c3 = colorResource(R.color.led_color_3)
        val c4 = colorResource(R.color.led_color_4)
        return remember(c1, c2, c3, c4) { listOf(c1, c2, c3, c4) }
    }

    /** Support de la guirlande, dans les écrans clairs (aperçu). */
    @Composable
    fun baseColor(): Color = colorResource(R.color.led_base)

    /** Support de la guirlande en plein écran, sombre pour faire ressortir les LEDs. */
    @Composable
    fun displayBaseColor(): Color = colorResource(R.color.led_base_display)

    /** LED éteinte, dans les écrans clairs. */
    @Composable
    fun offColor(): Color = colorResource(R.color.led_off)

    /** LED éteinte en plein écran. */
    @Composable
    fun displayOffColor(): Color = colorResource(R.color.led_off_display)
}

/**
 * Cadre lumineux, comme une guirlande de LEDs enroulée autour d'un tableau.
 *
 * La bande extérieure (épaisseur [ledBand]) contient des LEDs rondes régulièrement espacées.
 * Une vague de lumière fait le tour du cadre (effet chenillard) et les couleurs glissent lentement.
 * Le contenu est affiché à l'intérieur, sur [contentColor].
 *
 * Les animations sont lues uniquement pendant le dessin : aucune recomposition à chaque image.
 */
@Composable
fun LedFrame(
    contentColor: Color,
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 28.dp,
    ledBand: Dp = 16.dp,
    ledSpacing: Dp = 20.dp,
    chaseDurationMillis: Int = 900,
    colorShiftDurationMillis: Int = 6_000,
    palette: List<Color> = LedFrameDefaults.palette(),
    baseColor: Color = LedFrameDefaults.baseColor(),
    offColor: Color = LedFrameDefaults.offColor(),
    content: @Composable BoxScope.() -> Unit,
) {
    val transition = rememberInfiniteTransition(label = "led-frame")
    val chase = transition.animateFloat(
        initialValue = 0f,
        targetValue = WAVE_PERIOD,
        animationSpec = infiniteRepeatable(
            animation = tween(chaseDurationMillis, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "led-chase",
    )
    val colorShift = transition.animateFloat(
        initialValue = 0f,
        targetValue = (palette.size * COLOR_GROUP).toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(colorShiftDurationMillis, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "led-color-shift",
    )

    val innerRadius = (cornerRadius - ledBand).coerceAtLeast(0.dp)

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(cornerRadius))
            .background(baseColor)
            .drawWithCache {
                val band = ledBand.toPx()
                val inset = band / 2f
                val radius = (cornerRadius.toPx() - inset).coerceAtLeast(0f)

                // Ligne médiane de la bande : c'est là que sont posées les LEDs.
                val path = Path().apply {
                    addRoundRect(
                        RoundRect(
                            left = inset,
                            top = inset,
                            right = size.width - inset,
                            bottom = size.height - inset,
                            cornerRadius = CornerRadius(radius),
                        )
                    )
                }
                val measure = PathMeasure().apply { setPath(path, false) }
                val count = (measure.length / ledSpacing.toPx()).toInt().coerceAtLeast(1)
                val step = measure.length / count
                val positions = List(count) { i -> measure.getPosition(i * step) }

                val ledRadius = band * 0.28f
                val glowRadius = band * 0.62f

                onDrawBehind {
                    val c = chase.value
                    val shift = colorShift.value.toInt()

                    positions.forEachIndexed { i, pos ->
                        // Position de la LED dans la vague (0..1), qui avance avec le temps.
                        val d = (((i - c) % WAVE_PERIOD) + WAVE_PERIOD) % WAVE_PERIOD / WAVE_PERIOD
                        val wave = 0.5f + 0.5f * cos(2f * PI.toFloat() * d)
                        val level = 0.12f + 0.88f * wave * wave * wave

                        val color = palette[((i + shift) / COLOR_GROUP) % palette.size]

                        // Halo
                        drawCircle(
                            color = color.copy(alpha = 0.35f * level),
                            radius = glowRadius,
                            center = pos,
                        )
                        // Ampoule
                        drawCircle(color = lerp(offColor, color, level), radius = ledRadius, center = pos)
                        // Reflet blanc quand la LED est bien allumée
                        if (level > 0.6f) {
                            drawCircle(
                                color = Color.White.copy(alpha = (level - 0.6f) * 1.5f),
                                radius = ledRadius * 0.45f,
                                center = pos,
                            )
                        }
                    }
                }
            }
            .padding(ledBand),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(innerRadius))
                .background(contentColor),
            content = content,
        )
    }
}

/** Nombre de LEDs entre deux vagues de lumière. */
private const val WAVE_PERIOD = 6f

/** Nombre de LEDs consécutives de la même couleur. */
private const val COLOR_GROUP = 3
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
import androidx.compose.ui.unit.dp
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineDimens

/**
 * Gabarit commun à tous les écrans de l'application :
 * fond gris clair, titre centré en haut, contenu au milieu, menu des fonctionnalités en bas.
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
            ScreenTitle(title, modifier = Modifier.padding(vertical = 6.dp))

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
fun ScreenTitle(
    text: String,
    modifier: Modifier = Modifier,
) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleMedium,
        color = VitrineColors.TextPrimary,
        textAlign = TextAlign.Center,
        modifier = modifier.fillMaxWidth(),
    )
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/text/ui/display/TextDisplayScreen.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.text.ui.display

import android.app.Activity
import android.content.pm.ActivityInfo
import android.view.WindowManager
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.example.vitrine.core.ui.components.LedFrame
import com.example.vitrine.core.ui.components.LedFrameDefaults
import com.example.vitrine.core.ui.components.MarqueeText
import com.example.vitrine.core.ui.modifier.rotate90

/**
 * Affichage plein écran : paysage, barres système cachées, écran toujours allumé,
 * guirlande de LEDs sur les bords et message sur une ligne qui défile si besoin.
 * Un appui n'importe où ramène à l'édition.
 */
@Composable
fun TextDisplayScreen(
    text: String,
    textColor: Color,
    bgColor: Color,
    onExit: () -> Unit,
) {
    FullScreenDisplayEffect()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(LedFrameDefaults.displayBaseColor())
            .clickable(onClick = onExit),
    ) {
        LedFrame(
            contentColor = bgColor,
            modifier = Modifier.fillMaxSize(),
            baseColor = LedFrameDefaults.displayBaseColor(),
            offColor = LedFrameDefaults.displayOffColor(),
            cornerRadius = 28.dp,
            ledBand = 20.dp,
            ledSpacing = 24.dp,
        ) {
            BoxWithConstraints(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(12.dp),
            ) {
// Si l'écran n'a pas pu passer en paysage (tablette, multi-fenêtre…),
// on tourne le texte de 90° pour qu'il suive la longueur du téléphone.
                val isPortrait = maxHeight > maxWidth

                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .then(if (isPortrait) Modifier.rotate90() else Modifier),
                    contentAlignment = Alignment.Center,
                ) {
                    MarqueeText(text = text, color = textColor)
                }
            }
        }
    }
}

/**
 * Pendant l'affichage : force le paysage, garde l'écran allumé et cache les barres système.
 * Tout est restauré en quittant l'affichage, mais pas pendant une rotation
 * (l'activité est alors recréée et l'affichage continue).
 */
@Composable
private fun FullScreenDisplayEffect() {
    val activity = LocalView.current.context as? Activity

    DisposableEffect(activity) {
        val window = activity?.window
        activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window?.let { w ->
            WindowCompat.getInsetsController(w, w.decorView).apply {
                systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                hide(WindowInsetsCompat.Type.systemBars())
            }
        }

        onDispose {
            if (activity?.isChangingConfigurations != true) {
                activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
                window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                window?.let { w ->
                    WindowCompat.getInsetsController(w, w.decorView)
                        .show(WindowInsetsCompat.Type.systemBars())
                }
            }
        }
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

/** Pastille de couleur avec son libellé ; un anneau foncé indique la sélection. */
@Composable
internal fun ColorSwatch(
    label: String,
    color: Color,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val ring by animateColorAsState(
        targetValue = if (selected) VitrineColors.TextPrimary else Color.Transparent,
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
                .background(color)
                // Contour discret : une pastille blanche reste visible sur une carte blanche
                .border(1.dp, VitrineColors.Divider, CircleShape),
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
import com.example.vitrine.core.ui.components.VitrineCard
import com.example.vitrine.core.ui.components.LedFrame
import com.example.vitrine.core.ui.components.MarqueeText
import com.example.vitrine.core.ui.components.SectionLabel
import com.example.vitrine.core.ui.components.StatusDot
import com.example.vitrine.core.ui.components.VitrineScreen
import com.example.vitrine.feature.text.ui.model.BackgroundColorOptions
import com.example.vitrine.feature.text.ui.model.ColorOption
import com.example.vitrine.feature.text.ui.model.TextColorOptions
import com.example.vitrine.feature.text.viewmodel.TextUiState
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineDimens
import com.example.vitrine.ui.theme.VitrineShapes

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
    VitrineCard {
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
            cursorBrush = SolidColor(VitrineColors.Accent),
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
                    color = VitrineColors.Accent,
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
    val shape = VitrineShapes.Card

    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp),
            horizontalArrangement = Arrangement.End,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Comme « ● Charging » : point vert quand l'aperçu est prêt à être affiché
            StatusDot(
                text = stringResource(
                    if (enabled) R.string.text_preview_hint else R.string.text_preview_waiting
                ),
                color = if (enabled) VitrineColors.Accent else VitrineColors.Divider,
            )
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
            cornerRadius = VitrineDimens.CardRadius,
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
    VitrineCard {
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
    /** Fond des écrans (gris très clair). */
    val Background: Color @Composable get() = colorResource(R.color.vitrine_background)

    /** Fond des cartes et du menu (blanc). */
    val Surface: Color @Composable get() = colorResource(R.color.vitrine_surface)

    /** Élément sélectionné, boutons ronds, zones en retrait. */
    val SurfaceMuted: Color @Composable get() = colorResource(R.color.vitrine_surface_muted)

    /** Contours discrets (pastilles blanches, séparateurs). */
    val Divider: Color @Composable get() = colorResource(R.color.vitrine_divider)

    val TextPrimary: Color @Composable get() = colorResource(R.color.vitrine_text_primary)
    val TextMuted: Color @Composable get() = colorResource(R.color.vitrine_text_muted)

    /** Vert : état actif, curseur, actions. */
    val Accent: Color @Composable get() = colorResource(R.color.vitrine_accent)

    /** Ambre : attention, fonctionnalité à venir. */
    val Warning: Color @Composable get() = colorResource(R.color.vitrine_warning)
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/ui/theme/Dimens.kt <<'EOF_VITRINE'
package com.example.vitrine.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.dp

/** Espacements et formes communs à tous les écrans. */
object VitrineDimens {
    /** Marge horizontale des écrans. */
    val ScreenPaddingH = 16.dp

    /** Marge verticale des écrans. */
    val ScreenPaddingV = 12.dp

    /** Espace entre deux cartes. */
    val SectionGap = 10.dp

    /** Espace entre le libellé d'une carte et son contenu. */
    val LabelGap = 8.dp

    val CardPadding = 16.dp

    val CardRadius = 22.dp
    val MenuRadius = 22.dp
    val ControlRadius = 14.dp
}

object VitrineShapes {
    val Card = RoundedCornerShape(VitrineDimens.CardRadius)
    val Menu = RoundedCornerShape(VitrineDimens.MenuRadius)
    val Control = RoundedCornerShape(VitrineDimens.ControlRadius)

    /** Pilule : puces et éléments sélectionnés. */
    val Pill = RoundedCornerShape(percent = 50)
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/ui/theme/Theme.kt <<'EOF_VITRINE'
package com.example.vitrine.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/**
 * Thème unique de l'application : plat et clair, accents vert et ambre.
 * Les couleurs dynamiques (Material You) et le thème sombre sont volontairement désactivés
 * pour que l'application garde la même identité sur tous les téléphones.
 */
@Composable
fun VitrineTheme(content: @Composable () -> Unit) {
    val colorScheme = lightColorScheme(
        primary = VitrineColors.Accent,
        onPrimary = Color.White,
        secondary = VitrineColors.Warning,
        onSecondary = Color.White,
        background = VitrineColors.Background,
        onBackground = VitrineColors.TextPrimary,
        surface = VitrineColors.Surface,
        onSurface = VitrineColors.TextPrimary,
        surfaceVariant = VitrineColors.SurfaceMuted,
        onSurfaceVariant = VitrineColors.TextMuted,
        outline = VitrineColors.Divider,
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
 * Typographie plate : peu de graisses, de grands chiffres, des libellés discrets.
 * - displayLarge : grand chiffre principal d'un écran (ex. « 83 % »)
 * - headlineMedium : chiffre d'une carte (ex. « 248 mi »)
 * - titleMedium : titre d'écran, centré
 * - bodyLarge / bodyMedium : textes courants
 * - labelLarge : libellés de carte (« Charge time »)
 * - labelMedium : menu, puces
 * - labelSmall : indications et compteurs
 */
val Typography = Typography(
    displayLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Medium,
        fontSize = 56.sp,
        lineHeight = 60.sp,
        letterSpacing = (-1).sp,
    ),
    headlineMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Medium,
        fontSize = 28.sp,
        lineHeight = 34.sp,
        letterSpacing = (-0.5).sp,
    ),
    titleMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.SemiBold,
        fontSize = 17.sp,
        lineHeight = 22.sp,
    ),
    bodyLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 22.sp,
    ),
    bodyMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 14.sp,
        lineHeight = 20.sp,
    ),
    labelLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Medium,
        fontSize = 13.sp,
        lineHeight = 18.sp,
    ),
    labelMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Medium,
        fontSize = 13.sp,
        lineHeight = 16.sp,
    ),
    labelSmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize = 11.sp,
        lineHeight = 14.sp,
    ),
)
EOF_VITRINE

write app/src/main/res/values/colors_vitrine.xml <<'EOF_VITRINE'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Interface : design plat et clair -->
    <color name="vitrine_background">#FFF1F1F1</color>     <!-- fond des écrans -->
    <color name="vitrine_surface">#FFFFFFFF</color>        <!-- cartes, menu -->
    <color name="vitrine_surface_muted">#FFF0F0F0</color>  <!-- élément sélectionné, boutons ronds -->
    <color name="vitrine_divider">#FFE6E6E6</color>        <!-- contours discrets -->
    <color name="vitrine_text_primary">#FF111111</color>
    <color name="vitrine_text_muted">#FF8E8E93</color>
    <color name="vitrine_accent">#FF4CA34A</color>         <!-- vert : état actif, curseur -->
    <color name="vitrine_warning">#FFE3A43A</color>        <!-- ambre : attention, bientôt -->

    <!-- Guirlande de LEDs -->
    <color name="led_base">#FFFFFFFF</color>               <!-- support (aperçu) -->
    <color name="led_base_display">#FF0A0A0A</color>       <!-- support (plein écran) -->
    <color name="led_off">#FFE4E4E4</color>                <!-- LED éteinte (aperçu) -->
    <color name="led_off_display">#FF1E1E1E</color>        <!-- LED éteinte (plein écran) -->
    <color name="led_color_1">#FF4CA34A</color>
    <color name="led_color_2">#FFE3A43A</color>
    <color name="led_color_3">#FFE86F5C</color>
    <color name="led_color_4">#FF4C8DF6</color>

    <!-- Couleurs proposées pour le texte -->
    <color name="text_white">#FFFFFFFF</color>
    <color name="text_yellow">#FFFFFF00</color>
    <color name="text_green">#FF00FF00</color>
    <color name="text_red">#FFFF0000</color>

    <!-- Couleurs proposées pour le fond -->
    <color name="bg_black">#FF000000</color>
    <color name="bg_night_blue">#FF001133</color>
    <color name="bg_night_red">#FF220000</color>
    <color name="bg_white">#FFFFFFFF</color>
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
    <string name="text_preview_waiting">En attente du message</string>
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
    <!-- Thème clair : même fond que l'application, pas de flash au lancement. -->
    <style name="Theme.Vitrine" parent="android:Theme.Material.Light.NoActionBar">
        <item name="android:windowBackground">@color/vitrine_background</item>
    </style>
</resources>
EOF_VITRINE

echo
echo "Terminé. Dans Android Studio : File > Sync Project, puis Build > Rebuild Project."
