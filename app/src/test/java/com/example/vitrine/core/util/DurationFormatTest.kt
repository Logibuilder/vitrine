package com.example.vitrine.core.util

import org.junit.Assert.assertEquals
import org.junit.Test

class DurationFormatTest {

    @Test
    fun `chrono sous une heure en minutes et secondes`() {
        assertEquals("00:00", formatStopwatch(0))
        assertEquals("04:07", formatStopwatch(247_999))
    }

    @Test
    fun `chrono au-dela d'une heure`() {
        assertEquals("1:04:07", formatStopwatch(3_847_000))
    }

    @Test
    fun `temps total lisible`() {
        assertEquals("45 s", formatTotal(45_000))
        assertEquals("12 min", formatTotal(720_000))
        assertEquals("2 h", formatTotal(7_200_000))
        assertEquals("3 h 12 min", formatTotal(11_520_000))
    }

    @Test
    fun `une valeur negative s'affiche comme zero`() {
        assertEquals("00:00", formatStopwatch(-5_000))
    }
}
