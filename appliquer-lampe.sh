#!/usr/bin/env bash
# Ajoute la lampe à Vitrine (lumière d'écran et flash).
# À lancer depuis la racine du projet VITRINE, après appliquer-aiguilles.sh
# (et le dernier AnalogClock.kt). Pensez à faire un commit avant : les fichiers existants sont écrasés.
set -euo pipefail

if [[ ! -f settings.gradle.kts || ! -d app/src/main ]]; then
  echo "Erreur : lancez ce script depuis la racine du projet VITRINE." >&2
  exit 1
fi

write() { mkdir -p "$(dirname "$1")"; cat > "$1"; echo "  écrit : $1"; }
remove() {
  if [[ -f "$1" ]]; then
    if git ls-files --error-unmatch "$1" >/dev/null 2>&1; then git rm -q "$1"; else rm "$1"; fi
    echo "  supprimé : $1"
  else echo "  déjà absent : $1"; fi
}

echo "Suppression :"
remove app/src/main/java/com/example/vitrine/feature/text/ui/editor/EditorComponents.kt

echo "Création :"
write app/src/main/java/com/example/vitrine/core/hardware/CameraTorchController.kt <<'EOF_VITRINE'
package com.example.vitrine.core.hardware

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Flash piloté par l'API camera2 ([CameraManager.setTorchMode]).
 * Aucune permission n'est nécessaire pour le mode torche.
 * Préfère le flash arrière ; à défaut, n'importe quelle caméra équipée d'un flash.
 */
class CameraTorchController(context: Context) : TorchController {

    private val cameraManager = context.getSystemService(CameraManager::class.java)

    private val cameraId: String? = runCatching {
        val withFlash = cameraManager.cameraIdList.filter { id ->
            cameraManager.getCameraCharacteristics(id)
                .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        }
        withFlash.firstOrNull { id ->
            cameraManager.getCameraCharacteristics(id)
                .get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
        } ?: withFlash.firstOrNull()
    }.getOrNull()

    override val isAvailable: Boolean = cameraId != null

    private val _isOn = MutableStateFlow(false)
    override val isOn: StateFlow<Boolean> = _isOn.asStateFlow()

    private val callback = object : CameraManager.TorchCallback() {
        override fun onTorchModeChanged(id: String, enabled: Boolean) {
            if (id == cameraId) _isOn.value = enabled
        }

        override fun onTorchModeUnavailable(id: String) {
            if (id == cameraId) _isOn.value = false
        }
    }

    init {
        if (isAvailable) {
            cameraManager.registerTorchCallback(callback, Handler(Looper.getMainLooper()))
        }
    }

    override fun setEnabled(enabled: Boolean): Boolean {
        val id = cameraId ?: return false
        return runCatching { cameraManager.setTorchMode(id, enabled) }.isSuccess
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/core/hardware/TorchController.kt <<'EOF_VITRINE'
package com.example.vitrine.core.hardware

import kotlinx.coroutines.flow.StateFlow

/** Flash de l'appareil photo, utilisé comme lampe torche. */
interface TorchController {
    /** Faux si l'appareil n'a pas de flash. */
    val isAvailable: Boolean

    /** État réel du flash, mis à jour aussi quand une autre application l'allume ou l'éteint. */
    val isOn: StateFlow<Boolean>

    /** Allume ou éteint le flash ; renvoie faux en cas d'échec (caméra déjà utilisée, etc.). */
    fun setEnabled(enabled: Boolean): Boolean
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/flashlight/ui/display/LightDisplayScreen.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.flashlight.ui.display

import android.app.Activity
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.example.vitrine.R
import com.example.vitrine.core.ui.components.FullScreenDisplayEffect
import com.example.vitrine.feature.flashlight.usecase.SetScreenBrightnessUseCase
import kotlinx.coroutines.delay
import org.koin.compose.koinInject
import kotlin.math.roundToInt

/**
 * Lumière plein écran : tout l'écran de la couleur choisie, luminosité réglée,
 * écran toujours allumé. Glisser vers le haut ou le bas règle l'intensité ;
 * un appui ramène aux réglages.
 */
@Composable
fun LightDisplayScreen(
    color: Color,
    brightness: Float,
    onBrightnessChange: (Float) -> Unit,
    onExit: () -> Unit,
) {
    FullScreenDisplayEffect(forceLandscape = false)
    ScreenBrightnessEffect(brightness)

    val currentBrightness by rememberUpdatedState(brightness)
    var showLevel by remember { mutableStateOf(false) }
    // Le pourcentage s'efface 1,2 s après le dernier réglage
    LaunchedEffect(brightness) {
        if (showLevel) {
            delay(1_200)
            showLevel = false
        }
    }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(color)
            .pointerInput(Unit) { detectTapGestures(onTap = { onExit() }) },
    ) {
        val heightPx = with(LocalDensity.current) { maxHeight.toPx() }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .draggable(
                    orientation = Orientation.Vertical,
                    state = rememberDraggableState { delta ->
                        // Toute la hauteur de l'écran = toute la plage de luminosité ; vers le haut = plus fort
                        showLevel = true
                        onBrightnessChange(currentBrightness - delta / heightPx)
                    },
                ),
        )

        AnimatedVisibility(
            visible = showLevel,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.align(Alignment.Center),
        ) {
            // Texte foncé sur lumière claire, clair sur lumière foncée
            val onLight = if (color.luminance() > 0.5f) Color.Black else Color.White
            Text(
                text = stringResource(R.string.light_level, (brightness * 100).roundToInt()),
                style = MaterialTheme.typography.headlineMedium,
                color = onLight,
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(onLight.copy(alpha = 0.12f))
                    .padding(horizontal = 20.dp, vertical = 10.dp),
            )
        }
    }
}

/** Applique [level] à la luminosité de la fenêtre ; rend la main au téléphone en quittant. */
@Composable
private fun ScreenBrightnessEffect(level: Float) {
    val window = (LocalView.current.context as? Activity)?.window
    val setBrightness: SetScreenBrightnessUseCase = koinInject()

    LaunchedEffect(window, level) { window?.let { setBrightness(it, level) } }
    DisposableEffect(window) {
        onDispose { window?.let { setBrightness(it, null) } }
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/flashlight/ui/home/FlashlightHomeScreen.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.flashlight.ui.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.res.colorResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.min
import com.example.vitrine.R
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.core.ui.components.ColorSwatch
import com.example.vitrine.core.ui.components.SectionLabel
import com.example.vitrine.core.ui.components.SegmentedControl
import com.example.vitrine.core.ui.components.StatusDot
import com.example.vitrine.core.ui.components.VitrineCard
import com.example.vitrine.core.ui.components.VitrineScreen
import com.example.vitrine.feature.flashlight.ui.model.LightColorOptions
import com.example.vitrine.feature.flashlight.usecase.SetScreenBrightnessUseCase
import com.example.vitrine.feature.flashlight.viewmodel.FlashlightUiState
import com.example.vitrine.feature.flashlight.viewmodel.LightSource
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineDimens
import kotlin.math.roundToInt

/**
 * Écran lampe : un grand aperçu (lumière d'écran) ou un gros bouton (flash), puis les réglages.
 * Même gabarit que les autres écrans : titre, cartes, menu.
 */
@Composable
fun FlashlightHomeScreen(
    state: FlashlightUiState,
    onSource: (LightSource) -> Unit,
    onColor: (Int) -> Unit,
    onBrightness: (Float) -> Unit,
    onShowFullScreen: () -> Unit,
    onToggleTorch: () -> Unit,
    onNavigate: (AppDestination) -> Unit,
) {
    VitrineScreen(
        title = stringResource(R.string.flashlight_title),
        current = AppDestination.FLASHLIGHT,
        onNavigate = onNavigate,
    ) {
        when (state.source) {
            LightSource.SCREEN -> ScreenLightCard(
                color = Color(state.colorArgb),
                brightness = state.brightness,
                onClick = onShowFullScreen,
                modifier = Modifier.weight(1f),
            )
            LightSource.TORCH -> TorchCard(
                isOn = state.torchOn,
                onToggle = onToggleTorch,
                modifier = Modifier.weight(1f),
            )
        }

        VitrineCard {
            // Sans flash sur l'appareil, il n'y a qu'une source : pas de choix à afficher
            if (state.torchAvailable) {
                SettingRow(label = stringResource(R.string.light_source_label)) {
                    SegmentedControl(
                        options = LightSource.entries,
                        selected = state.source,
                        onSelect = onSource,
                        label = { source ->
                            stringResource(
                                when (source) {
                                    LightSource.SCREEN -> R.string.light_source_screen
                                    LightSource.TORCH -> R.string.light_source_torch
                                }
                            )
                        },
                    )
                }
            }

            AnimatedVisibility(
                visible = state.source == LightSource.SCREEN,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically(),
            ) {
                Column {
                    if (state.torchAvailable) Spacer(Modifier.height(VitrineDimens.SectionGap))
                    ScreenLightSettings(
                        colorArgb = state.colorArgb,
                        brightness = state.brightness,
                        onColor = onColor,
                        onBrightness = onBrightness,
                    )
                }
            }
        }
    }
}

/** Aperçu de la lumière d'écran : un disque de la couleur choisie, plus ou moins vif. */
@Composable
private fun ScreenLightCard(
    color: Color,
    brightness: Float,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    VitrineCard(
        modifier = modifier,
        onClick = onClick,
        onClickLabel = stringResource(R.string.light_turn_on_screen),
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            StatusDot(text = stringResource(R.string.light_tap_hint), color = VitrineColors.Accent)
        }
        BoxWithConstraints(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            contentAlignment = Alignment.Center,
        ) {
            val side = min(maxWidth, maxHeight) * 0.8f
            // Halo pâle autour, disque plein au centre : l'intensité règle l'opacité du disque
            Box(
                modifier = Modifier
                    .size(side)
                    .clip(CircleShape)
                    .background(color.copy(alpha = 0.18f)),
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    modifier = Modifier
                        .size(side * 0.62f)
                        .clip(CircleShape)
                        .background(color.copy(alpha = 0.35f + 0.65f * brightness)),
                )
            }
        }
    }
}

/** Flash : un gros bouton d'alimentation rond, vert quand le flash est allumé. */
@Composable
private fun TorchCard(
    isOn: Boolean,
    onToggle: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val background by animateColorAsState(
        targetValue = if (isOn) VitrineColors.Accent else VitrineColors.SurfaceMuted,
        label = "torch-button",
    )
    val iconColor by animateColorAsState(
        targetValue = if (isOn) VitrineColors.Surface else VitrineColors.TextPrimary,
        label = "torch-icon",
    )
    val actionLabel = stringResource(R.string.light_toggle_torch)
    val stateLabel = stringResource(if (isOn) R.string.light_torch_on else R.string.light_torch_off)

    VitrineCard(modifier = modifier) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            StatusDot(
                text = stateLabel,
                color = if (isOn) VitrineColors.Accent else VitrineColors.Divider,
            )
        }
        BoxWithConstraints(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            contentAlignment = Alignment.Center,
        ) {
            val side = min(maxWidth, maxHeight) * 0.6f
            Box(
                modifier = Modifier
                    .size(side)
                    .clip(CircleShape)
                    .background(background)
                    .clickable(role = Role.Switch, onClick = onToggle)
                    .semantics {
                        contentDescription = actionLabel
                        stateDescription = stateLabel
                    },
                contentAlignment = Alignment.Center,
            ) {
                PowerIcon(color = iconColor, modifier = Modifier.size(side * 0.36f))
            }
        }
    }
}

/** Symbole « marche/arrêt » : un cercle ouvert en haut, traversé d'un trait. */
@Composable
private fun PowerIcon(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val stroke = size.minDimension * 0.11f
        val inset = stroke / 2
        drawArc(
            color = color,
            startAngle = -60f,
            sweepAngle = 300f,
            useCenter = false,
            topLeft = Offset(inset, inset),
            size = Size(size.width - stroke, size.height - stroke),
            style = Stroke(width = stroke, cap = StrokeCap.Round),
        )
        drawLine(
            color = color,
            start = Offset(center.x, inset),
            end = Offset(center.x, center.y),
            strokeWidth = stroke,
            cap = StrokeCap.Round,
        )
    }
}

@Composable
private fun ScreenLightSettings(
    colorArgb: Int,
    brightness: Float,
    onColor: (Int) -> Unit,
    onBrightness: (Float) -> Unit,
) {
    SectionLabel(stringResource(R.string.light_color_label))
    Spacer(Modifier.height(VitrineDimens.LabelGap))
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceEvenly,
    ) {
        LightColorOptions.forEach { option ->
            val color = colorResource(option.color)
            val argb = color.toArgb()
            ColorSwatch(
                label = stringResource(option.label),
                color = color,
                selected = colorArgb == argb,
                onClick = { onColor(argb) },
            )
        }
    }

    Spacer(Modifier.height(VitrineDimens.SectionGap))

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SectionLabel(stringResource(R.string.light_brightness_label))
        Text(
            text = stringResource(R.string.light_level, (brightness * 100).roundToInt()),
            style = MaterialTheme.typography.labelLarge,
            color = VitrineColors.TextPrimary,
        )
    }
    Slider(
        value = brightness,
        onValueChange = onBrightness,
        valueRange = SetScreenBrightnessUseCase.MIN_LEVEL..1f,
        colors = SliderDefaults.colors(
            thumbColor = VitrineColors.TextPrimary,
            activeTrackColor = VitrineColors.Accent,
            inactiveTrackColor = VitrineColors.SurfaceMuted,
        ),
    )
}

/** Réglage sur une ligne : libellé à gauche, choix à droite. */
@Composable
private fun SettingRow(
    label: String,
    control: @Composable () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        SectionLabel(label)
        control()
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/flashlight/ui/model/LightColorOption.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.flashlight.ui.model

import androidx.annotation.ColorRes
import androidx.annotation.StringRes
import com.example.vitrine.R

/** Une couleur de lumière proposée : son libellé et sa valeur, en ressources. */
internal data class LightColorOption(
    @StringRes val label: Int,
    @ColorRes val color: Int,
)

internal val LightColorOptions = listOf(
    LightColorOption(R.string.light_white, R.color.light_white),
    LightColorOption(R.string.light_warm, R.color.light_warm),
    LightColorOption(R.string.light_cool, R.color.light_cool),
    // Le rouge préserve la vision de nuit (ciel étoilé, lecture dans le noir)
    LightColorOption(R.string.light_red, R.color.light_red),
)
EOF_VITRINE

write app/src/main/res/values/strings_flashlight.xml <<'EOF_VITRINE'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Feature lampe (le titre flashlight_title est dans strings_menu.xml) -->
    <string name="light_source_label">Source</string>
    <string name="light_source_screen">Écran</string>
    <string name="light_source_torch">Flash</string>

    <string name="light_tap_hint">Touchez pour allumer</string>
    <string name="light_turn_on_screen">Allumer l\'écran en lampe</string>
    <string name="light_color_label">Couleur</string>
    <string name="light_brightness_label">Intensité</string>
    <string name="light_level">%1$d %%</string>

    <string name="light_toggle_torch">Allumer ou éteindre le flash</string>
    <string name="light_torch_on">Allumé</string>
    <string name="light_torch_off">Éteint</string>

    <!-- Noms des couleurs de lumière -->
    <string name="light_white">Blanc</string>
    <string name="light_warm">Chaud</string>
    <string name="light_cool">Froid</string>
    <string name="light_red">Rouge</string>
</resources>
EOF_VITRINE

write app/src/test/java/com/example/vitrine/feature/flashlight/usecase/BrightnessClampTest.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.flashlight.usecase

import org.junit.Assert.assertEquals
import org.junit.Test

class BrightnessClampTest {

    @Test
    fun `la luminosite reste entre le minimum et 100 pourcent`() {
        assertEquals(SetScreenBrightnessUseCase.MIN_LEVEL, SetScreenBrightnessUseCase.clamp(-0.5f), 0.0001f)
        assertEquals(SetScreenBrightnessUseCase.MIN_LEVEL, SetScreenBrightnessUseCase.clamp(0f), 0.0001f)
        assertEquals(0.5f, SetScreenBrightnessUseCase.clamp(0.5f), 0.0001f)
        assertEquals(1f, SetScreenBrightnessUseCase.clamp(3f), 0.0001f)
    }
}
EOF_VITRINE

write app/src/test/java/com/example/vitrine/feature/flashlight/viewmodel/FakeTorchController.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.flashlight.viewmodel

import com.example.vitrine.core.hardware.TorchController
import kotlinx.coroutines.flow.MutableStateFlow

/** Flash simulé pour les tests : pas de caméra, juste un état. */
class FakeTorchController(override val isAvailable: Boolean = true) : TorchController {
    override val isOn = MutableStateFlow(false)
    override fun setEnabled(enabled: Boolean): Boolean {
        if (!isAvailable) return false
        isOn.value = enabled
        return true
    }
}
EOF_VITRINE

write app/src/test/java/com/example/vitrine/feature/flashlight/viewmodel/FlashlightViewModelTest.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.flashlight.viewmodel

import androidx.lifecycle.SavedStateHandle
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Les actions du ViewModel sont synchrones : on vérifie leur effet sur le flash
 * et sur le SavedStateHandle, sans avoir besoin de collecter uiState.
 */
class FlashlightViewModelTest {

    @Test
    fun `le bouton allume puis eteint le flash`() {
        val torch = FakeTorchController()
        val vm = FlashlightViewModel(SavedStateHandle(), torch)
        vm.toggleTorch()
        assertTrue(torch.isOn.value)
        vm.toggleTorch()
        assertFalse(torch.isOn.value)
    }

    @Test
    fun `repasser sur l'ecran eteint le flash`() {
        val torch = FakeTorchController()
        val vm = FlashlightViewModel(SavedStateHandle(), torch)
        vm.setSource(LightSource.TORCH)
        vm.toggleTorch()
        vm.setSource(LightSource.SCREEN)
        assertFalse(torch.isOn.value)
    }

    @Test
    fun `la luminosite enregistree est bornee`() {
        val handle = SavedStateHandle()
        val vm = FlashlightViewModel(handle, FakeTorchController())
        vm.setBrightness(2f)
        assertEquals(1f, handle.get<Float>("brightness")!!, 0.0001f)
    }

    @Test
    fun `sans flash le bouton ne fait rien`() {
        val torch = FakeTorchController(isAvailable = false)
        val vm = FlashlightViewModel(SavedStateHandle(), torch)
        vm.toggleTorch()
        assertFalse(torch.isOn.value)
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/core/ui/components/ColorSwatch.kt <<'EOF_VITRINE'
package com.example.vitrine.core.ui.components

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
fun ColorSwatch(
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

echo "Remplacement :"
write app/src/main/java/com/example/vitrine/core/ui/components/FullScreenDisplayEffect.kt <<'EOF_VITRINE'
package com.example.vitrine.core.ui.components

import android.app.Activity
import android.content.pm.ActivityInfo
import android.view.WindowManager
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

/**
 * À placer dans un écran d'affichage plein écran (texte géant, horloge, lampe…).
 * Tant que l'écran est affiché : écran toujours allumé, barres système cachées,
 * et paysage forcé si [forceLandscape] (inutile pour la lampe, par exemple).
 * Tout est restauré en quittant l'écran, mais pas pendant une rotation
 * (l'activité est alors recréée et l'affichage continue).
 */
@Composable
fun FullScreenDisplayEffect(forceLandscape: Boolean = true) {
    val activity = LocalView.current.context as? Activity

    DisposableEffect(activity, forceLandscape) {
        val window = activity?.window
        if (forceLandscape) {
            activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        }
        window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window?.let { w ->
            WindowCompat.getInsetsController(w, w.decorView).apply {
                systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                hide(WindowInsetsCompat.Type.systemBars())
            }
        }

        onDispose {
            if (activity?.isChangingConfigurations != true) {
                if (forceLandscape) {
                    activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
                }
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

write app/src/main/java/com/example/vitrine/di/AppModule.kt <<'EOF_VITRINE'
package com.example.vitrine.di

import com.example.vitrine.MainViewModel
import com.example.vitrine.core.hardware.CameraTorchController
import com.example.vitrine.core.hardware.TorchController
import com.example.vitrine.feature.clock.usecase.GetCurrentTimeUseCase
import com.example.vitrine.feature.clock.viewmodel.ClockViewModel
import com.example.vitrine.feature.flashlight.usecase.SetScreenBrightnessUseCase
import com.example.vitrine.feature.flashlight.viewmodel.FlashlightViewModel
import com.example.vitrine.feature.text.viewmodel.TextViewModel
import org.koin.android.ext.koin.androidContext
import org.koin.core.module.dsl.viewModelOf
import org.koin.dsl.module

val appModule = module {
    viewModelOf(::MainViewModel)
    viewModelOf(::TextViewModel)

    // Horloge
    factory { GetCurrentTimeUseCase() }
    viewModelOf(::ClockViewModel)

    // Lampe : un seul contrôleur de flash pour toute l'application
    single<TorchController> { CameraTorchController(androidContext()) }
    factory { SetScreenBrightnessUseCase() }
    viewModelOf(::FlashlightViewModel)
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/flashlight/ui/FlashlightScreen.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.flashlight.ui

import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.feature.flashlight.ui.display.LightDisplayScreen
import com.example.vitrine.feature.flashlight.ui.home.FlashlightHomeScreen
import com.example.vitrine.feature.flashlight.viewmodel.FlashlightViewModel
import org.koin.androidx.compose.koinViewModel

/**
 * Point d'entrée de la feature lampe.
 * Récupère l'état du ViewModel et choisit l'écran : réglages ou lumière plein écran.
 */
@Composable
fun FlashlightScreen(
    onNavigate: (AppDestination) -> Unit,
    viewModel: FlashlightViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    // En quittant l'écran lampe (autre écran du menu), on éteint le flash ;
    // mais pas pendant une rotation, où l'écran est seulement recréé
    val activity = LocalView.current.context as? Activity
    DisposableEffect(viewModel) {
        onDispose {
            if (activity?.isChangingConfigurations != true) viewModel.turnOffTorch()
        }
    }

    // Retour du téléphone en plein écran : revient aux réglages de la lampe
    BackHandler(enabled = state.isFullScreen, onBack = viewModel::exitFullScreen)

    if (state.isFullScreen) {
        LightDisplayScreen(
            color = Color(state.colorArgb),
            brightness = state.brightness,
            onBrightnessChange = viewModel::setBrightness,
            onExit = viewModel::exitFullScreen,
        )
    } else {
        FlashlightHomeScreen(
            state = state,
            onSource = viewModel::setSource,
            onColor = viewModel::setColor,
            onBrightness = viewModel::setBrightness,
            onShowFullScreen = viewModel::showFullScreen,
            onToggleTorch = viewModel::toggleTorch,
            onNavigate = onNavigate,
        )
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/flashlight/usecase/SetScreenBrightnessUseCase.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.flashlight.usecase

import android.view.Window
import android.view.WindowManager

/**
 * Règle la luminosité de l'écran pour cette fenêtre uniquement
 * (le réglage du téléphone n'est pas modifié, aucune permission n'est nécessaire).
 */
class SetScreenBrightnessUseCase {

    /** [level] entre 0 et 1 ; null rend la main au réglage du téléphone. */
    operator fun invoke(window: Window, level: Float?) {
        window.attributes = window.attributes.apply {
            screenBrightness = level?.let(::clamp) ?: WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
        }
    }

    companion object {
        /** En dessous, certains écrans s'éteignent presque : la lampe ne servirait plus à rien. */
        const val MIN_LEVEL = 0.05f

        fun clamp(level: Float): Float = level.coerceIn(MIN_LEVEL, 1f)
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/flashlight/viewmodel/FlashlightViewModel.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.flashlight.viewmodel

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.vitrine.core.hardware.TorchController
import com.example.vitrine.feature.flashlight.usecase.SetScreenBrightnessUseCase
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn

/** D'où vient la lumière. */
enum class LightSource { SCREEN, TORCH }

/**
 * État de l'écran lampe.
 *
 * @property colorArgb couleur de la lumière d'écran (ARGB).
 * @property brightness luminosité de l'écran en plein écran, entre 0,05 et 1.
 */
data class FlashlightUiState(
    val source: LightSource = LightSource.SCREEN,
    val colorArgb: Int = DEFAULT_COLOR,
    val brightness: Float = 1f,
    val isFullScreen: Boolean = false,
    val torchAvailable: Boolean = false,
    val torchOn: Boolean = false,
) {
    companion object {
        const val DEFAULT_COLOR: Int = -0x1 // 0xFFFFFFFF, blanc
    }
}

/**
 * Gère la lampe : lumière d'écran (couleur, intensité, plein écran) ou flash.
 * Les réglages sont gardés dans le [SavedStateHandle] (rotation comprise) ;
 * l'état du flash vient du [TorchController], qui suit aussi les autres applications.
 */
class FlashlightViewModel(
    private val savedState: SavedStateHandle,
    private val torch: TorchController,
) : ViewModel() {

    private val source = savedState.getStateFlow(Keys.SOURCE, LightSource.SCREEN.name)
        .map { name -> LightSource.entries.firstOrNull { it.name == name } ?: LightSource.SCREEN }
    private val colorArgb = savedState.getStateFlow(Keys.COLOR, FlashlightUiState.DEFAULT_COLOR)
    private val brightness = savedState.getStateFlow(Keys.BRIGHTNESS, 1f)
    private val isFullScreen = savedState.getStateFlow(Keys.FULL_SCREEN, false)

    val uiState: StateFlow<FlashlightUiState> = combine(
        source,
        colorArgb,
        brightness,
        isFullScreen,
        torch.isOn,
    ) { lightSource, color, level, fullScreen, torchOn ->
        FlashlightUiState(
            // Sans flash, on reste sur l'écran
            source = if (torch.isAvailable) lightSource else LightSource.SCREEN,
            colorArgb = color,
            brightness = level,
            isFullScreen = fullScreen,
            torchAvailable = torch.isAvailable,
            torchOn = torchOn,
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = FlashlightUiState(
            source = LightSource.entries.firstOrNull { it.name == savedState.get<String>(Keys.SOURCE) }
                ?.takeIf { torch.isAvailable } ?: LightSource.SCREEN,
            colorArgb = colorArgb.value,
            brightness = brightness.value,
            isFullScreen = isFullScreen.value,
            torchAvailable = torch.isAvailable,
            torchOn = torch.isOn.value,
        ),
    )

    fun setSource(value: LightSource) {
        // On éteint le flash en repassant sur l'écran
        if (value == LightSource.SCREEN) torch.setEnabled(false)
        savedState[Keys.SOURCE] = value.name
    }

    fun setColor(argb: Int) { savedState[Keys.COLOR] = argb }

    fun setBrightness(level: Float) { savedState[Keys.BRIGHTNESS] = SetScreenBrightnessUseCase.clamp(level) }

    fun showFullScreen() { savedState[Keys.FULL_SCREEN] = true }

    fun exitFullScreen() { savedState[Keys.FULL_SCREEN] = false }

    fun toggleTorch() { torch.setEnabled(!torch.isOn.value) }

    /** À appeler en quittant l'écran lampe : on ne laisse pas le flash allumé derrière soi. */
    fun turnOffTorch() { if (torch.isOn.value) torch.setEnabled(false) }

    override fun onCleared() {
        turnOffTorch()
    }

    private object Keys {
        const val SOURCE = "source"
        const val COLOR = "color"
        const val BRIGHTNESS = "brightness"
        const val FULL_SCREEN = "isFullScreen"
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/text/ui/editor/TextEditorScreen.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.text.ui.editor

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.colorResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.vitrine.R
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.core.ui.components.ColorSwatch
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
@OptIn(ExperimentalLayoutApi::class)
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
        val keyboardVisible = WindowInsets.isImeVisible

        val message: @Composable () -> Unit = {
            MessageField(
                draft = state.draft,
                canShow = state.canShow,
                onDraftChange = onDraftChange,
                onClear = onClearDraft,
                onShow = onShow,
            )
        }
        val colors: @Composable () -> Unit = {
            ColorsCard(
                textColorArgb = state.textColorArgb,
                bgColorArgb = state.bgColorArgb,
                onTextColor = onTextColor,
                onBgColor = onBgColor,
            )
        }
        val preview: @Composable (Modifier) -> Unit = { modifier ->
            PreviewSection(
                modifier = modifier,
                draft = state.draft,
                textColor = Color(state.readableTextColorArgb),
                bgColor = Color(state.bgColorArgb),
                enabled = state.canShow,
                onClick = onShow,
            )
        }

        BoxWithConstraints(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
        ) {
            val gap = VitrineDimens.SectionGap

            if (maxWidth > maxHeight) {
                // Paysage : deux colonnes. À gauche la saisie et les couleurs (qui défilent si besoin),
                // à droite l'aperçu sur toute la hauteur. S'il reste trop peu de place (clavier ouvert),
                // l'ensemble garde la hauteur minimale de l'aperçu et devient défilable.
                val rowHeight = maxOf(maxHeight, PreviewMinHeight)
                Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(rowHeight),
                        horizontalArrangement = Arrangement.spacedBy(gap),
                    ) {
                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight()
                                .verticalScroll(rememberScrollState()),
                            verticalArrangement = Arrangement.spacedBy(gap),
                        ) {
                            message()
                            colors()
                        }
                        preview(
                            Modifier
                                .weight(1f)
                                .fillMaxHeight()
                        )
                    }
                }
            } else {
                // Portrait : saisie, aperçu, couleurs. L'aperçu prend la place restante
                // sans jamais descendre sous sa hauteur minimale ; si ça ne tient pas, l'écran défile.
                // Pendant la saisie, les couleurs se masquent pour laisser la place à l'aperçu.
                var messageHeight by remember { mutableIntStateOf(0) }
                var colorsHeight by remember { mutableIntStateOf(0) }
                val density = LocalDensity.current

                val otherHeights = with(density) {
                    val colors = if (keyboardVisible) 0 else colorsHeight
                    (messageHeight + colors).toDp()
                }
                val gaps = if (keyboardVisible) gap else gap * 2
                val previewHeight = (maxHeight - otherHeights - gaps).coerceAtLeast(PreviewMinHeight)

                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(gap),
                ) {
                    Box(Modifier.onSizeChanged { messageHeight = it.height }) { message() }
                    preview(
                        Modifier
                            .fillMaxWidth()
                            .height(previewHeight)
                    )
                    AnimatedVisibility(
                        visible = !keyboardVisible,
                        enter = fadeIn() + expandVertically(),
                        exit = fadeOut() + shrinkVertically(),
                    ) {
                        Box(Modifier.onSizeChanged { colorsHeight = it.height }) { colors() }
                    }
                }
            }
        }
    }
}

/** Hauteur minimale de l'aperçu : il reste toujours visible, même clavier ouvert. */
private val PreviewMinHeight = 96.dp

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

write app/src/main/res/values/colors_vitrine.xml <<'EOF_VITRINE'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!--
        Interface, design plat. Deux palettes : claire et sombre.
        VitrineColors choisit la bonne selon le thème actif (automatique, clair ou sombre),
        ce qui permet de forcer un thème différent de celui du téléphone.
    -->

    <!-- Mode clair -->
    <color name="vitrine_light_background">#FFF1F1F1</color>     <!-- fond des écrans -->
    <color name="vitrine_light_surface">#FFFFFFFF</color>        <!-- cartes, menu -->
    <color name="vitrine_light_surface_muted">#FFF0F0F0</color>  <!-- élément sélectionné -->
    <color name="vitrine_light_divider">#FFE6E6E6</color>        <!-- contours discrets, LEDs éteintes -->
    <color name="vitrine_light_text_primary">#FF111111</color>
    <color name="vitrine_light_text_muted">#FF8E8E93</color>
    <color name="vitrine_light_accent">#FF4CA34A</color>         <!-- vert : état actif -->
    <color name="vitrine_light_warning">#FFE3A43A</color>        <!-- ambre : attention -->

    <!-- Mode sombre -->
    <color name="vitrine_dark_background">#FF0E0E10</color>
    <color name="vitrine_dark_surface">#FF1C1C1E</color>
    <color name="vitrine_dark_surface_muted">#FF2C2C2E</color>
    <color name="vitrine_dark_divider">#FF3A3A3C</color>
    <color name="vitrine_dark_text_primary">#FFF5F5F7</color>
    <color name="vitrine_dark_text_muted">#FF8E8E93</color>
    <color name="vitrine_dark_accent">#FF5DBB5A</color>
    <color name="vitrine_dark_warning">#FFF0B44C</color>

    <!-- Guirlande de LEDs (l'aperçu utilise les couleurs de l'interface) -->
    <color name="led_base_display">#FF0A0A0A</color>       <!-- support (plein écran) -->
    <color name="led_off_display">#FF1E1E1E</color>        <!-- LED éteinte (plein écran) -->
    <color name="led_color_1">#FF4CA34A</color>
    <color name="led_color_2">#FFE3A43A</color>
    <color name="led_color_3">#FFE86F5C</color>
    <color name="led_color_4">#FF4C8DF6</color>

    <!-- Couleurs de la lampe (lumière d'écran) -->
    <color name="light_white">#FFFFFFFF</color>
    <color name="light_warm">#FFFFD9A0</color>   <!-- blanc chaud, comme une ampoule -->
    <color name="light_cool">#FFD6ECFF</color>   <!-- blanc froid, comme la lumière du jour -->
    <color name="light_red">#FFFF2A1F</color>    <!-- préserve la vision de nuit -->

    <!-- Couleurs proposées pour le texte du message -->
    <color name="text_white">#FFFFFFFF</color>
    <color name="text_yellow">#FFFFFF00</color>
    <color name="text_green">#FF00FF00</color>
    <color name="text_red">#FFFF0000</color>

    <!-- Couleurs proposées pour le fond du message -->
    <color name="bg_black">#FF000000</color>
    <color name="bg_night_blue">#FF001133</color>
    <color name="bg_night_red">#FF220000</color>
    <color name="bg_white">#FFFFFFFF</color>
</resources>
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
    <string name="flashlight_title">La lumière, au bout des doigts</string>
    <string name="timer_title">Vos minuteurs</string>
    <string name="timer_coming_soon">Des minuteurs par tâche, qui continuent même écran éteint.</string>
</resources>
EOF_VITRINE

echo
echo "Terminé. Dans Android Studio : File > Sync Project, puis Build > Rebuild Project."
