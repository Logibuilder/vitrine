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
