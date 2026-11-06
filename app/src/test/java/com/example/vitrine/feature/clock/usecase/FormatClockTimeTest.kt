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
