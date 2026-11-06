package com.example.vitrine.core.util

import kotlinx.coroutines.flow.take
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test

class TickerTest {

    @Test
    fun `emet tout de suite puis a chaque periode`() = runBlocking {
        val times = ArrayDeque(listOf(1_005L, 1_010L, 1_020L))
        val ticks = tickerFlow(periodMillis = 10L, now = { times.removeFirst() })
            .take(3)
            .toList()
        assertEquals(listOf(1_005L, 1_010L, 1_020L), ticks)
    }
}
