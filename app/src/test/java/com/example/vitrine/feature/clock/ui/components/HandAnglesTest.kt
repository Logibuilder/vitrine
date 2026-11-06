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
