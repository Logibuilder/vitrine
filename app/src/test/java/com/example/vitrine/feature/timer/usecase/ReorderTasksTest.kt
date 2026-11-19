package com.example.vitrine.feature.timer.usecase

import com.example.vitrine.domain.model.moved
import com.example.vitrine.domain.model.orderedBy
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test

class ReorderTasksTest {

    @Test
    fun `deplacer vers le bas decale les taches intermediaires`() {
        assertEquals(listOf(2L, 3L, 1L, 4L), listOf(1L, 2L, 3L, 4L).moved(fromId = 1, toId = 3))
    }

    @Test
    fun `deplacer vers le haut`() {
        assertEquals(listOf(4L, 1L, 2L, 3L), listOf(1L, 2L, 3L, 4L).moved(fromId = 4, toId = 1))
    }

    @Test
    fun `identifiant inconnu - ordre inchange`() {
        assertEquals(listOf(1L, 2L), listOf(1L, 2L).moved(fromId = 9, toId = 1))
    }

    @Test
    fun `l'ordre voulu s'applique et les nouvelles taches vont a la fin`() {
        val shown = listOf(1L, 2L, 3L, 4L).orderedBy(listOf(3L, 1L, 2L)) { it }
        assertEquals(listOf(3L, 1L, 2L, 4L), shown)
    }

    @Test
    fun `le use case enregistre l'ordre`() = runBlocking {
        val tasks = FakeTaskRepository()
        val a = tasks.addTask("A", 0)
        val b = tasks.addTask("B", 0)
        val c = tasks.addTask("C", 0)
        ReorderTasksUseCase(tasks)(listOf(c, a, b))
        val names = (tasks.observeTasks() as MutableStateFlow).value.map { it.name }
        assertEquals(listOf("C", "A", "B"), names)
    }

    @Test
    fun `une seule tache - rien a enregistrer`() = runBlocking {
        val tasks = FakeTaskRepository()
        val a = tasks.addTask("A", 0)
        ReorderTasksUseCase(tasks)(listOf(a))
        assertEquals(1, (tasks.observeTasks() as MutableStateFlow).value.size)
    }
}