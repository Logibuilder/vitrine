package com.example.vitrine.domain.model

import com.example.vitrine.MainViewModel
import org.junit.Assert.assertEquals
import org.junit.Test

class ThemeModeTest {

    @Test
    fun `l'application demarre sur le theme du telephone`() {
        assertEquals(ThemeMode.SYSTEM, MainViewModel().themeMode.value)
    }

    @Test
    fun `un appui passe toujours a l'apparence inverse`() {
        val vm = MainViewModel()
        vm.toggleTheme(isDarkNow = true)
        assertEquals(ThemeMode.LIGHT, vm.themeMode.value)
        vm.toggleTheme(isDarkNow = false)
        assertEquals(ThemeMode.DARK, vm.themeMode.value)
    }
}
