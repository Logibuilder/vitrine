package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.domain.usecase.ReconstructTimersUseCase
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class TimerUseCasesTest {

    private lateinit var clock: FakeClock
    private lateinit var tasks: FakeTaskRepository
    private lateinit var timers: FakeTimerRepository
    private lateinit var notifier: FakeTimerNotifier
    private lateinit var alarms: FakeGoalAlarmScheduler
    private lateinit var start: StartTimerUseCase
    private lateinit var pause: PauseTimerUseCase
    private lateinit var stop: StopTimerUseCase
    private var taskId = 0L

    @Before
    fun setUp() = runBlocking {
        clock = FakeClock(time = 1_000_000L)
        tasks = FakeTaskRepository()
        timers = FakeTimerRepository()
        notifier = FakeTimerNotifier()
        alarms = FakeGoalAlarmScheduler()
        pause = PauseTimerUseCase(timers, notifier, alarms, clock)
        start = StartTimerUseCase(tasks, timers, pause, notifier, alarms, clock)
        stop = StopTimerUseCase(timers, notifier, alarms, clock)
        taskId = tasks.addTask("Révisions", clock.now())
    }

    @Test
    fun `lancer un chrono enregistre l'heure de depart et affiche la notification`() = runBlocking {
        start(taskId)
        val state = timers.getState(taskId)!!
        assertEquals(1_000_000L, state.runningSince)
        assertTrue(notifier.shown.containsKey(taskId))
    }

    @Test
    fun `la pause cumule le temps et cree une session`() = runBlocking {
        start(taskId)
        clock.time += 90_000 // 1 min 30
        pause(taskId)

        val state = timers.getState(taskId)!!
        assertFalse(state.isRunning)
        assertEquals(90_000L, state.accumulatedMillis)
        assertEquals(1, timers.sessions.size)
        assertFalse(notifier.shown.containsKey(taskId))
    }

    @Test
    fun `relancer apres une pause reprend ou on en etait`() = runBlocking {
        start(taskId)
        clock.time += 60_000
        pause(taskId)
        clock.time += 600_000 // 10 min de pause : ne comptent pas
        start(taskId)
        clock.time += 30_000

        assertEquals(90_000L, timers.getState(taskId)!!.elapsedAt(clock.now()))
    }

    @Test
    fun `arreter remet a zero mais garde le temps dans l'historique`() = runBlocking {
        start(taskId)
        clock.time += 45_000
        stop(taskId)

        assertNull(timers.getState(taskId))
        assertEquals(45_000L, timers.sessions.sumOf { it.durationMillis })
        assertFalse(notifier.shown.containsKey(taskId))
    }

    @Test
    fun `le chrono continue de compter sans que rien ne tourne`() = runBlocking {
        start(taskId)
        clock.time += 3 * 3_600_000L // téléphone éteint pendant 3 h
        assertEquals(3 * 3_600_000L, timers.getState(taskId)!!.elapsedAt(clock.now()))
    }

    @Test
    fun `apres un redemarrage les notifications des chronos en cours reviennent`() = runBlocking {
        start(taskId)
        notifier.shown.clear() // le redémarrage efface les notifications
        ReconstructTimersUseCase(tasks, timers, notifier, alarms, clock)()
        assertTrue(notifier.shown.containsKey(taskId))
    }

    @Test
    fun `un seul chrono a la fois - lancer une tache met l'autre en pause`() = runBlocking {
        val otherId = tasks.addTask("Sport", clock.now())
        start(taskId)
        clock.time += 120_000 // 2 min sur « Révisions »
        start(otherId)

        val first = timers.getState(taskId)!!
        assertFalse(first.isRunning)
        assertEquals(120_000L, first.accumulatedMillis) // le temps est gardé
        assertTrue(timers.getState(otherId)!!.isRunning)
        assertEquals(listOf(otherId), timers.getRunningStates().map { it.taskId })
        assertEquals(setOf(otherId), notifier.shown.keys) // une seule notification
    }

    @Test
    fun `lancer deux fois ne remet pas l'heure de depart a jour`() = runBlocking {
        start(taskId)
        clock.time += 5_000
        start(taskId)
        assertEquals(1_000_000L, timers.getState(taskId)!!.runningSince)
    }
}
