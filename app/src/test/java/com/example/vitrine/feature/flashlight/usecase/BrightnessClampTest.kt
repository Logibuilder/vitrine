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
