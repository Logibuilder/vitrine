#!/usr/bin/env bash
# Ajoute le style à aiguilles à l'horloge de Vitrine.
# À lancer depuis la racine du projet VITRINE, après appliquer-horloge.sh.
# Pensez à faire un commit avant : les fichiers existants sont écrasés.
set -euo pipefail

if [[ ! -f settings.gradle.kts || ! -d app/src/main ]]; then
  echo "Erreur : lancez ce script depuis la racine du projet VITRINE." >&2
  exit 1
fi

write() { mkdir -p "$(dirname "$1")"; cat > "$1"; echo "  écrit : $1"; }

echo "Création :"
write app/src/main/java/com/example/vitrine/feature/clock/ui/components/AnalogClock.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.clock.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.rotate
import com.example.vitrine.feature.clock.usecase.ClockTime

/** Couleurs du cadran. */
data class AnalogClockColors(
    val face: Color,
    val minorTick: Color,
    val majorTick: Color,
    val hands: Color,
    val secondHand: Color,
)

/**
 * Horloge à aiguilles, plate : un disque, 60 graduations (plus marquées aux heures),
 * aiguilles des heures et des minutes, trotteuse colorée.
 * Reste ronde quelle que soit la place disponible.
 */
@Composable
fun AnalogClock(
    time: ClockTime,
    showSeconds: Boolean,
    colors: AnalogClockColors,
    modifier: Modifier = Modifier,
) {
    val angles = handAngles(time)

    Canvas(
        modifier = modifier
            .fillMaxSize()
            .aspectRatio(1f),
    ) {
        val radius = size.minDimension / 2f
        val unit = radius / 100f // tout est exprimé en % du rayon

        drawCircle(color = colors.face, radius = radius)
        drawTicks(radius, unit, colors)

        drawHand(angles.hour, length = 50 * unit, tail = 8 * unit, width = 7 * unit, colors.hands)
        drawHand(angles.minute, length = 76 * unit, tail = 10 * unit, width = 4.5f * unit, colors.hands)
        if (showSeconds) {
            drawHand(angles.second, length = 84 * unit, tail = 16 * unit, width = 1.8f * unit, colors.secondHand)
        }

        // Axe central
        drawCircle(color = if (showSeconds) colors.secondHand else colors.hands, radius = 4.5f * unit)
        drawCircle(color = colors.face, radius = 1.8f * unit)
    }
}

/** 60 graduations : longues et épaisses aux heures, courtes et fines aux minutes. */
private fun DrawScope.drawTicks(radius: Float, unit: Float, colors: AnalogClockColors) {
    repeat(60) { i ->
        val major = i % 5 == 0
        rotate(degrees = i * 6f, pivot = center) {
            drawLine(
                color = if (major) colors.majorTick else colors.minorTick,
                start = Offset(center.x, center.y - radius + 6 * unit),
                end = Offset(center.x, center.y - radius + (if (major) 16 else 10) * unit),
                strokeWidth = (if (major) 3.2f else 1.4f) * unit,
                cap = StrokeCap.Round,
            )
        }
    }
}

/** Aiguille tournée de [degrees] (0 = midi), qui dépasse un peu derrière l'axe ([tail]). */
private fun DrawScope.drawHand(
    degrees: Float,
    length: Float,
    tail: Float,
    width: Float,
    color: Color,
) {
    rotate(degrees = degrees, pivot = center) {
        drawLine(
            color = color,
            start = Offset(center.x, center.y + tail),
            end = Offset(center.x, center.y - length),
            strokeWidth = width,
            cap = StrokeCap.Round,
        )
    }
}

/** Angles des aiguilles, en degrés dans le sens horaire depuis midi. */
internal data class HandAngles(val hour: Float, val minute: Float, val second: Float)

/**
 * Les heures et les minutes avancent en continu (à 9 h 30, l'aiguille des heures est entre 9 et 10) ;
 * la trotteuse saute d'une seconde à l'autre, comme une montre à quartz.
 */
internal fun handAngles(time: ClockTime): HandAngles {
    val seconds = time.secondOfMinute.toFloat()
    val minutes = time.minuteOfHour + seconds / 60f
    val hours = (time.hourOfDay % 12) + minutes / 60f
    return HandAngles(
        hour = hours * 30f,
        minute = minutes * 6f,
        second = seconds * 6f,
    )
}
EOF_VITRINE

write app/src/test/java/com/example/vitrine/feature/clock/ui/components/HandAnglesTest.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.clock.ui.components

import com.example.vitrine.feature.clock.usecase.ClockTime
import org.junit.Assert.assertEquals
import org.junit.Test

class HandAnglesTest {

    private fun time(h: Int, m: Int, s: Int) = ClockTime(
        hours = "", minutes = "", seconds = "", period = null, date = "",
        hourOfDay = h, minuteOfHour = m, secondOfMinute = s,
    )

    @Test
    fun `3 h pile`() {
        val angles = handAngles(time(3, 0, 0))
        assertEquals(90f, angles.hour, 0.01f)
        assertEquals(0f, angles.minute, 0.01f)
        assertEquals(0f, angles.second, 0.01f)
    }

    @Test
    fun `21 h 30 - l'aiguille des heures est entre 9 et 10`() {
        val angles = handAngles(time(21, 30, 0))
        assertEquals(285f, angles.hour, 0.01f)
        assertEquals(180f, angles.minute, 0.01f)
    }

    @Test
    fun `la trotteuse saute de 6 degres par seconde`() {
        assertEquals(90f, handAngles(time(12, 0, 15)).second, 0.01f)
    }
}
EOF_VITRINE

echo "Remplacement :"
write app/src/main/java/com/example/vitrine/feature/clock/ui/ClockScreen.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.clock.ui

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.feature.clock.ui.display.ClockDisplayScreen
import com.example.vitrine.feature.clock.ui.home.ClockHomeScreen
import com.example.vitrine.feature.clock.viewmodel.ClockViewModel
import org.koin.androidx.compose.koinViewModel

/**
 * Point d'entrée de la feature horloge.
 * Récupère l'état du ViewModel et choisit l'écran : réglages ou affichage plein écran.
 */
@Composable
fun ClockScreen(
    onNavigate: (AppDestination) -> Unit,
    viewModel: ClockViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    // Retour du téléphone en plein écran : revient aux réglages de l'horloge
    BackHandler(enabled = state.isFullScreen, onBack = viewModel::exitFullScreen)

    if (state.isFullScreen) {
        ClockDisplayScreen(
            time = state.time,
            style = state.style,
            showSeconds = state.showSeconds,
            onExit = viewModel::exitFullScreen,
        )
    } else {
        ClockHomeScreen(
            state = state,
            onStyle = viewModel::setStyle,
            onUse24Hour = viewModel::setUse24Hour,
            onShowSeconds = viewModel::setShowSeconds,
            onShowFullScreen = viewModel::showFullScreen,
            onNavigate = onNavigate,
        )
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/clock/ui/display/ClockDisplayScreen.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.clock.ui.display

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.colorResource
import androidx.compose.ui.unit.dp
import com.example.vitrine.R
import com.example.vitrine.core.ui.components.FullScreenDisplayEffect
import com.example.vitrine.core.ui.components.LedFrame
import com.example.vitrine.core.ui.components.LedFrameDefaults
import com.example.vitrine.core.ui.modifier.rotate90
import com.example.vitrine.feature.clock.ui.components.AnalogClock
import com.example.vitrine.feature.clock.ui.components.AnalogClockColors
import com.example.vitrine.feature.clock.ui.components.BigClock
import com.example.vitrine.feature.clock.usecase.ClockTime
import com.example.vitrine.feature.clock.viewmodel.ClockStyle

/**
 * Horloge plein écran : paysage, écran toujours allumé, guirlande de LEDs sur les bords,
 * comme l'affichage du texte géant. Un appui n'importe où ramène à l'écran horloge.
 */
@Composable
fun ClockDisplayScreen(
    time: ClockTime,
    style: ClockStyle,
    showSeconds: Boolean,
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
            contentColor = colorResource(R.color.bg_black),
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
                    .padding(16.dp),
            ) {
                // Si l'écran n'a pas pu passer en paysage, on tourne l'heure pour suivre sa longueur
                // (inutile pour le cadran, qui est rond)
                val isPortrait = maxHeight > maxWidth
                val white = colorResource(R.color.text_white)
                val muted = colorResource(R.color.vitrine_dark_text_muted)

                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .then(if (isPortrait && style == ClockStyle.DIGITAL) Modifier.rotate90() else Modifier),
                    contentAlignment = Alignment.Center,
                ) {
                    when (style) {
                        ClockStyle.DIGITAL -> BigClock(
                            time = time,
                            showSeconds = showSeconds,
                            color = white,
                            secondaryColor = muted,
                        )
                        ClockStyle.ANALOG -> AnalogClock(
                            time = time,
                            showSeconds = showSeconds,
                            colors = AnalogClockColors(
                                face = colorResource(R.color.vitrine_dark_surface),
                                minorTick = colorResource(R.color.vitrine_dark_divider),
                                majorTick = muted,
                                hands = white,
                                secondHand = colorResource(R.color.vitrine_dark_accent),
                            ),
                        )
                    }
                }
            }
        }
    }
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/clock/ui/home/ClockHomeScreen.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.clock.ui.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.example.vitrine.R
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.core.ui.components.SectionLabel
import com.example.vitrine.core.ui.components.SegmentedControl
import com.example.vitrine.core.ui.components.StatusDot
import com.example.vitrine.core.ui.components.VitrineCard
import com.example.vitrine.core.ui.components.VitrineScreen
import com.example.vitrine.feature.clock.ui.components.AnalogClock
import com.example.vitrine.feature.clock.ui.components.AnalogClockColors
import com.example.vitrine.feature.clock.ui.components.BigClock
import com.example.vitrine.feature.clock.viewmodel.ClockStyle
import com.example.vitrine.feature.clock.viewmodel.ClockUiState
import com.example.vitrine.ui.theme.VitrineColors
import com.example.vitrine.ui.theme.VitrineDimens

/**
 * Écran horloge : grande heure (toucher pour l'afficher en plein écran) et réglages.
 * Même gabarit que les autres écrans : titre, cartes, menu.
 */
@Composable
fun ClockHomeScreen(
    state: ClockUiState,
    onStyle: (ClockStyle) -> Unit,
    onUse24Hour: (Boolean) -> Unit,
    onShowSeconds: (Boolean) -> Unit,
    onShowFullScreen: () -> Unit,
    onNavigate: (AppDestination) -> Unit,
) {
    VitrineScreen(
        title = stringResource(R.string.clock_title),
        current = AppDestination.CLOCK,
        onNavigate = onNavigate,
    ) {
        // Carte de l'heure : prend la place restante, toucher pour passer en plein écran
        VitrineCard(
            modifier = Modifier.weight(1f),
            onClick = onShowFullScreen,
            onClickLabel = stringResource(R.string.text_show_full_screen),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
            ) {
                StatusDot(
                    text = stringResource(R.string.clock_tap_hint),
                    color = VitrineColors.Accent,
                )
            }
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(top = 4.dp),
                contentAlignment = Alignment.Center,
            ) {
                val analogColors = AnalogClockColors(
                    face = VitrineColors.Background,
                    minorTick = VitrineColors.Divider,
                    majorTick = VitrineColors.TextMuted,
                    hands = VitrineColors.TextPrimary,
                    secondHand = VitrineColors.Accent,
                )
                Crossfade(targetState = state.style, label = "clock-style") { style ->
                    when (style) {
                        ClockStyle.DIGITAL -> BigClock(
                            time = state.time,
                            showSeconds = state.showSeconds,
                            color = VitrineColors.TextPrimary,
                            secondaryColor = VitrineColors.TextMuted,
                        )
                        ClockStyle.ANALOG -> Column(
                            modifier = Modifier.fillMaxSize(),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            AnalogClock(
                                time = state.time,
                                showSeconds = state.showSeconds,
                                colors = analogColors,
                                modifier = Modifier.weight(1f),
                            )
                            Text(
                                text = state.time.date,
                                style = MaterialTheme.typography.bodyMedium,
                                color = VitrineColors.TextMuted,
                            )
                        }
                    }
                }
            }
        }

        VitrineCard {
            SettingRow(label = stringResource(R.string.clock_style_label)) {
                SegmentedControl(
                    options = ClockStyle.entries,
                    selected = state.style,
                    onSelect = onStyle,
                    label = { style ->
                        stringResource(
                            when (style) {
                                ClockStyle.DIGITAL -> R.string.clock_style_digital
                                ClockStyle.ANALOG -> R.string.clock_style_analog
                            }
                        )
                    },
                )
            }
            Spacer(Modifier.height(VitrineDimens.SectionGap))

            // Le format 12/24 h ne concerne que l'affichage en chiffres
            AnimatedVisibility(
                visible = state.style == ClockStyle.DIGITAL,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically(),
            ) {
                Column {
                    SettingRow(label = stringResource(R.string.clock_format_label)) {
                        SegmentedControl(
                            options = listOf(true, false),
                            selected = state.use24Hour,
                            onSelect = onUse24Hour,
                            label = { h24 ->
                                stringResource(if (h24) R.string.clock_format_24 else R.string.clock_format_12)
                            },
                        )
                    }
                    Spacer(Modifier.height(VitrineDimens.SectionGap))
                }
            }
            SettingRow(label = stringResource(R.string.clock_seconds_label)) {
                SegmentedControl(
                    options = listOf(true, false),
                    selected = state.showSeconds,
                    onSelect = onShowSeconds,
                    label = { show ->
                        stringResource(if (show) R.string.clock_seconds_show else R.string.clock_seconds_hide)
                    },
                )
            }
        }
    }
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

write app/src/main/java/com/example/vitrine/feature/clock/usecase/GetCurrentTimeUseCase.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.clock.usecase

import com.example.vitrine.core.util.tickerFlow
import java.text.DateFormatSymbols
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine

/**
 * Heure prête à afficher.
 *
 * @property hours heures : « 09 » en 24 h, « 9 » en 12 h.
 * @property period « AM » / « PM » (selon la langue) en 12 h, null en 24 h.
 * @property date date du jour, ex. « Vendredi 6 novembre ».
 * @property hourOfDay, minuteOfHour, secondOfMinute valeurs numériques, pour placer les aiguilles.
 */
data class ClockTime(
    val hours: String,
    val minutes: String,
    val seconds: String,
    val period: String?,
    val date: String,
    val hourOfDay: Int,
    val minuteOfHour: Int,
    val secondOfMinute: Int,
) {
    val hoursMinutes: String get() = "$hours:$minutes"
}

/**
 * Fournit l'heure courante, mise à jour chaque seconde, au format 12 h ou 24 h.
 * N'utilise que java.util (Calendar, SimpleDateFormat) : compatible minSdk 24 sans désucrage.
 */
class GetCurrentTimeUseCase(
    private val ticker: () -> Flow<Long> = { tickerFlow() },
    private val now: () -> Long = System::currentTimeMillis,
    private val timeZone: () -> TimeZone = { TimeZone.getDefault() },
    private val locale: () -> Locale = { Locale.getDefault() },
) {
    /** Flux de l'heure ; se reformate aussitôt quand [use24Hour] change. */
    operator fun invoke(use24Hour: Flow<Boolean>): Flow<ClockTime> =
        combine(ticker(), use24Hour) { millis, h24 -> format(millis, h24) }

    /** Heure de cet instant, pour un premier affichage sans attendre le flux. */
    fun current(use24Hour: Boolean): ClockTime = format(now(), use24Hour)

    private fun format(millis: Long, use24Hour: Boolean) =
        formatClockTime(millis, use24Hour, timeZone(), locale())
}

/** Mise en forme pure, testable sans Android. */
internal fun formatClockTime(
    millis: Long,
    use24Hour: Boolean,
    timeZone: TimeZone,
    locale: Locale,
): ClockTime {
    val calendar = Calendar.getInstance(timeZone, locale).apply { timeInMillis = millis }

    val hours = if (use24Hour) {
        calendar.get(Calendar.HOUR_OF_DAY).toString().padStart(2, '0')
    } else {
        // Calendar.HOUR va de 0 à 11 : minuit et midi s'affichent « 12 »
        calendar.get(Calendar.HOUR).let { if (it == 0) 12 else it }.toString()
    }
    val period = if (use24Hour) null else {
        DateFormatSymbols.getInstance(locale).amPmStrings[calendar.get(Calendar.AM_PM)]
    }
    val date = SimpleDateFormat("EEEE d MMMM", locale)
        .apply { this.timeZone = timeZone }
        .format(Date(millis))
        .replaceFirstChar { it.titlecase(locale) }

    val minute = calendar.get(Calendar.MINUTE)
    val second = calendar.get(Calendar.SECOND)

    return ClockTime(
        hours = hours,
        minutes = minute.toString().padStart(2, '0'),
        seconds = second.toString().padStart(2, '0'),
        period = period,
        date = date,
        hourOfDay = calendar.get(Calendar.HOUR_OF_DAY),
        minuteOfHour = minute,
        secondOfMinute = second,
    )
}
EOF_VITRINE

write app/src/main/java/com/example/vitrine/feature/clock/viewmodel/ClockViewModel.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.clock.viewmodel

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.vitrine.feature.clock.usecase.ClockTime
import com.example.vitrine.feature.clock.usecase.GetCurrentTimeUseCase
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn

/** Apparence de l'horloge. */
enum class ClockStyle { DIGITAL, ANALOG }

/** État de l'écran horloge. */
data class ClockUiState(
    val time: ClockTime,
    val style: ClockStyle = ClockStyle.DIGITAL,
    val use24Hour: Boolean = true,
    val showSeconds: Boolean = true,
    val isFullScreen: Boolean = false,
)

/**
 * Gère l'heure affichée, ses réglages et le passage en plein écran.
 * Les réglages sont gardés dans le [SavedStateHandle] : ils survivent à la rotation.
 * L'heure ne tourne que lorsque l'écran est visible (arrêt 5 s après sa disparition).
 */
class ClockViewModel(
    private val savedState: SavedStateHandle,
    getCurrentTime: GetCurrentTimeUseCase,
) : ViewModel() {

    private val style = savedState.getStateFlow(Keys.STYLE, ClockStyle.DIGITAL.name)
        .map { name -> ClockStyle.entries.firstOrNull { it.name == name } ?: ClockStyle.DIGITAL }
    private val use24Hour = savedState.getStateFlow(Keys.USE_24_HOUR, true)
    private val showSeconds = savedState.getStateFlow(Keys.SHOW_SECONDS, true)
    private val isFullScreen = savedState.getStateFlow(Keys.FULL_SCREEN, false)

    val uiState: StateFlow<ClockUiState> = combine(
        getCurrentTime(use24Hour),
        style,
        use24Hour,
        showSeconds,
        isFullScreen,
    ) { time, clockStyle, h24, seconds, fullScreen ->
        ClockUiState(
            time = time,
            style = clockStyle,
            use24Hour = h24,
            showSeconds = seconds,
            isFullScreen = fullScreen,
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = ClockUiState(
            time = getCurrentTime.current(use24Hour.value),
            style = ClockStyle.entries.firstOrNull {
                it.name == savedState.get<String>(Keys.STYLE)
            } ?: ClockStyle.DIGITAL,
            use24Hour = use24Hour.value,
            showSeconds = showSeconds.value,
            isFullScreen = isFullScreen.value,
        ),
    )

    fun setStyle(value: ClockStyle) { savedState[Keys.STYLE] = value.name }

    fun setUse24Hour(value: Boolean) { savedState[Keys.USE_24_HOUR] = value }

    fun setShowSeconds(value: Boolean) { savedState[Keys.SHOW_SECONDS] = value }

    fun showFullScreen() { savedState[Keys.FULL_SCREEN] = true }

    fun exitFullScreen() { savedState[Keys.FULL_SCREEN] = false }

    private object Keys {
        const val STYLE = "style"
        const val USE_24_HOUR = "use24Hour"
        const val SHOW_SECONDS = "showSeconds"
        const val FULL_SCREEN = "isFullScreen"
    }
}
EOF_VITRINE

write app/src/main/res/values/strings_clock.xml <<'EOF_VITRINE'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Feature horloge (le titre clock_title est dans strings_menu.xml) -->
    <string name="clock_tap_hint">Touchez pour afficher</string>
    <string name="clock_style_label">Style</string>
    <string name="clock_style_digital">Chiffres</string>
    <string name="clock_style_analog">Aiguilles</string>
    <string name="clock_format_label">Format</string>
    <string name="clock_format_24">24 h</string>
    <string name="clock_format_12">12 h</string>
    <string name="clock_seconds_label">Secondes</string>
    <string name="clock_seconds_show">Afficher</string>
    <string name="clock_seconds_hide">Masquer</string>
</resources>
EOF_VITRINE

write app/src/test/java/com/example/vitrine/feature/clock/usecase/FormatClockTimeTest.kt <<'EOF_VITRINE'
package com.example.vitrine.feature.clock.usecase

import java.util.Locale
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FormatClockTimeTest {

    private val utc = TimeZone.getTimeZone("UTC")

    // Vendredi 6 novembre 2026 (UTC)
    private val morning = 1_793_958_065_000L   // 09:41:05
    private val evening = 1_793_999_109_000L   // 21:05:09
    private val midnight = 1_793_923_380_000L  // 00:03:00

    @Test
    fun `format 24 h avec zero devant et sans AM-PM`() {
        val time = formatClockTime(morning, use24Hour = true, timeZone = utc, locale = Locale.FRANCE)
        assertEquals("09:41", time.hoursMinutes)
        assertEquals("05", time.seconds)
        assertNull(time.period)
    }

    @Test
    fun `format 12 h le soir`() {
        val time = formatClockTime(evening, use24Hour = false, timeZone = utc, locale = Locale.US)
        assertEquals("9:05", time.hoursMinutes)
        assertEquals("09", time.seconds)
        assertEquals("PM", time.period)
    }

    @Test
    fun `minuit s'affiche 12 en format 12 h et 00 en 24 h`() {
        assertEquals("12:03", formatClockTime(midnight, false, utc, Locale.US).hoursMinutes)
        assertEquals("00:03", formatClockTime(midnight, true, utc, Locale.US).hoursMinutes)
    }

    @Test
    fun `valeurs numeriques pour les aiguilles, toujours sur 24 h`() {
        val time = formatClockTime(evening, use24Hour = false, timeZone = utc, locale = Locale.US)
        assertEquals(21, time.hourOfDay)
        assertEquals(5, time.minuteOfHour)
        assertEquals(9, time.secondOfMinute)
    }

    @Test
    fun `la date commence par une majuscule`() {
        val time = formatClockTime(morning, use24Hour = true, timeZone = utc, locale = Locale.FRANCE)
        assertEquals("Vendredi 6 novembre", time.date)
    }
}
EOF_VITRINE

echo
echo "Terminé. Dans Android Studio : File > Sync Project, puis Build > Rebuild Project."
