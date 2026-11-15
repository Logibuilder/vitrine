package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.domain.usecase.ReconstructTimersUseCase
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** Objectif de temps : alarme programmée, annulée, reprogrammée ; notification au bon moment. */
class GoalUseCasesTest {

    private val minute = 60_000L

    private lateinit var clock: FakeClock
    private lateinit var tasks: FakeTaskRepository
    private lateinit var timers: FakeTimerRepository
    private lateinit var notifier: FakeTimerNotifier
    private lateinit var alarms: FakeGoalAlarmScheduler
    private lateinit var start: StartTimerUseCase
    private lateinit var pause: PauseTimerUseCase
    private lateinit var stop: StopTimerUseCase
    private lateinit var update: UpdateTaskUseCase
    private lateinit var goalReached: NotifyGoalReachedUseCase
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
        update = UpdateTaskUseCase(tasks, timers, notifier, alarms, clock)
        goalReached = NotifyGoalReachedUseCase(tasks, timers, notifier, alarms, clock)
        taskId = tasks.addTask("Révisions", clock.now())
        tasks.updateTask(taskId, "Révisions", 25 * minute)
    }

    @Test
    fun `lancer programme l'alarme a l'heure de l'objectif`() = runBlocking {
        start(taskId)
        assertEquals(clock.now() + 25 * minute, alarms.alarms[taskId])
    }

    @Test
    fun `apres une pause l'alarme tient compte du temps deja fait`() = runBlocking {
        start(taskId)
        clock.time += 10 * minute
        pause(taskId)
        assertNull(alarms.alarms[taskId]) // en pause : pas d'alarme
        clock.time += 60 * minute
        start(taskId)
        assertEquals(clock.now() + 15 * minute, alarms.alarms[taskId])
    }

    @Test
    fun `arreter annule l'alarme`() = runBlocking {
        start(taskId)
        stop(taskId)
        assertTrue(alarms.alarms.isEmpty())
    }

    @Test
    fun `une nouvelle tache a l'objectif par defaut de 25 min`() = runBlocking {
        val id = AddTaskUseCase(tasks, clock)("Sport")!!
        assertEquals(25 * minute, tasks.getTask(id)!!.goalMillis)
        start(id)
        assertEquals(clock.now() + 25 * minute, alarms.alarms[id])
    }

    @Test
    fun `objectif deja depasse au lancement - pas d'alarme`() = runBlocking {
        start(taskId)
        clock.time += 30 * minute
        pause(taskId)
        start(taskId)
        assertNull(alarms.alarms[taskId])
    }

    @Test
    fun `modifier l'objectif d'un chrono en cours reprogramme l'alarme et renomme la notification`() = runBlocking {
        start(taskId)
        clock.time += 5 * minute
        update(taskId, "Maths", 45 * minute)
        assertEquals(clock.now() + 40 * minute, alarms.alarms[taskId])
        assertEquals("Maths", notifier.shownNames[taskId])
    }

    @Test
    fun `reduire l'objectif sous le temps deja fait annule l'alarme`() = runBlocking {
        start(taskId)
        clock.time += 20 * minute
        update(taskId, "Révisions", 10 * minute)
        assertNull(alarms.alarms[taskId])
    }

    @Test
    fun `objectif nul ramene au minimum d'une minute`() = runBlocking {
        update(taskId, "Révisions", 0)
        assertEquals(minute, tasks.getTask(taskId)!!.goalMillis)
    }

    @Test
    fun `nom vide refuse`() = runBlocking {
        update(taskId, "   ", 10 * minute)
        assertEquals("Révisions", tasks.getTask(taskId)!!.name)
    }

    @Test
    fun `l'alarme sonne a l'objectif - notification`() = runBlocking {
        start(taskId)
        clock.time += 25 * minute
        goalReached(taskId)
        assertEquals(listOf(taskId), notifier.goalsReached)
    }

    @Test
    fun `alarme perimee - objectif allonge entre-temps - on reprogramme sans notifier`() = runBlocking {
        start(taskId)
        tasks.updateTask(taskId, "Révisions", 60 * minute) // modifié sans passer par le use case
        clock.time += 25 * minute
        goalReached(taskId)
        assertTrue(notifier.goalsReached.isEmpty())
        assertEquals(clock.now() + 35 * minute, alarms.alarms[taskId])
    }

    @Test
    fun `alarme alors que le chrono est en pause - rien`() = runBlocking {
        start(taskId)
        pause(taskId)
        goalReached(taskId)
        assertTrue(notifier.goalsReached.isEmpty())
    }

    @Test
    fun `supprimer la tache arrete tout`() = runBlocking {
        start(taskId)
        DeleteTaskUseCase(stop, tasks)(taskId)
        assertNull(tasks.getTask(taskId))
        assertTrue(alarms.alarms.isEmpty())
        assertFalse(notifier.shown.containsKey(taskId))
    }

    @Test
    fun `apres un redemarrage l'alarme est reprogrammee`() = runBlocking {
        start(taskId)
        clock.time += 10 * minute
        alarms.alarms.clear() // le redémarrage efface les alarmes
        ReconstructTimersUseCase(tasks, timers, notifier, alarms, clock)()
        assertEquals(clock.now() + 15 * minute, alarms.alarms[taskId])
    }

    @Test
    fun `l'objectif choisi a la creation est garde et sert a l'alarme`() = runBlocking {
        val id = AddTaskUseCase(tasks, clock)("Lecture", 45 * minute)!!
        assertEquals(45 * minute, tasks.getTask(id)!!.goalMillis)
        start(id)
        assertEquals(clock.now() + 45 * minute, alarms.alarms[id])
    }

    @Test
    fun `objectif nul a la creation ramene au minimum`() = runBlocking {
        val id = AddTaskUseCase(tasks, clock)("Pause", 0)!!
        assertEquals(minute, tasks.getTask(id)!!.goalMillis)
    }

    @Test
    fun `ajouter une tache - nom nettoye et limite`() = runBlocking {
        val add = AddTaskUseCase(tasks, clock)
        assertNull(add("   "))
        val id = add("  " + "a".repeat(60) + "  ")!!
        assertEquals(40, tasks.getTask(id)!!.name.length)
    }
}
