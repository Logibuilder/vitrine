package com.example.vitrine.domain.model

/** Une période de travail terminée sur une tâche : de [startedAt] à [endedAt]. */
data class TimerSession(
    val taskId: Long,
    val startedAt: Long,
    val endedAt: Long,
    val id: Long = 0L,
) {
    val durationMillis: Long get() = (endedAt - startedAt).coerceAtLeast(0L)
}
