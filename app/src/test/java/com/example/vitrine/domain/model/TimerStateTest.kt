package com.example.vitrine.domain.model

import org.junit.Assert.assertEquals
import org.junit.Test

class TimerStateTest {

    @Test
    fun `en pause le temps ne bouge plus`() {
        val state = TimerState(taskId = 1, accumulatedMillis = 30_000, runningSince = null)
        assertEquals(30_000L, state.elapsedAt(now = 999_999_999))
    }

    @Test
    fun `si l'heure du telephone recule, le chrono ne devient pas negatif`() {
        val state = TimerState(taskId = 1, accumulatedMillis = 10_000, runningSince = 50_000)
        assertEquals(10_000L, state.elapsedAt(now = 20_000))
    }

    @Test
    fun `total de la tache avec session en cours`() {
        val timer = TaskTimer(
            task = Task(1, "Sport", 0),
            state = TimerState(1, accumulatedMillis = 60_000, runningSince = 100_000),
            sessionsMillis = 600_000,
        )
        assertEquals(90_000L, timer.currentMillis(now = 130_000))
        assertEquals(630_000L, timer.totalMillis(now = 130_000))
    }

    @Test
    fun `avancement vers l'objectif`() {
        assertEquals(null, goalProgress(10_000, null))
        assertEquals(0.5f, goalProgress(30_000, 60_000)!!, 0.0001f)
        assertEquals(1.5f, goalProgress(90_000, 60_000)!!, 0.0001f)
    }

    @Test
    fun `delai avant l'objectif`() {
        val running = TimerState(1, accumulatedMillis = 10_000, runningSince = 100_000)
        assertEquals(40_000L, millisUntilGoal(60_000, running, now = 110_000))
        assertEquals(null, millisUntilGoal(60_000, running.copy(runningSince = null), now = 110_000))
        assertEquals(null, millisUntilGoal(15_000, running, now = 110_000)) // déjà atteint
        assertEquals(null, millisUntilGoal(null, running, now = 110_000))
    }
}
