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
