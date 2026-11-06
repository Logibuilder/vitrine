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
