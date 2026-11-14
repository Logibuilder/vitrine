package com.example.vitrine.domain.model

/**
 * Une tâche dont on mesure le temps (ex. « Révisions », « Sport »).
 *
 * @property goalMillis objectif de temps pour le chrono (ex. 25 min) ; null s'il n'y en a pas.
 *   Quand le chrono l'atteint, une alarme sonne ; le chrono, lui, continue de compter.
 */
data class Task(
    val id: Long,
    val name: String,
    val createdAt: Long,
    val goalMillis: Long? = null,
) {
    companion object {
        /** Un nom doit tenir sur une carte et dans une notification. */
        const val MAX_NAME_LENGTH = 40
    }
}

/**
 * Une tâche avec son chrono, prête à afficher.
 *
 * @property state chrono en cours ou en pause ; null s'il est à zéro.
 * @property sessionsMillis temps cumulé de toutes les sessions terminées.
 */
data class TaskTimer(
    val task: Task,
    val state: TimerState?,
    val sessionsMillis: Long,
) {
    val isRunning: Boolean get() = state?.isRunning == true

    /** Temps du chrono actuel (depuis la dernière remise à zéro). */
    fun currentMillis(now: Long): Long = state?.elapsedAt(now) ?: 0L

    /** Temps total passé sur la tâche, session en cours comprise. */
    fun totalMillis(now: Long): Long = sessionsMillis + (state?.runningPartAt(now) ?: 0L)
}

/**
 * Délai avant que le chrono atteigne l'objectif, s'il tourne.
 * Null s'il n'y a pas d'objectif, si le chrono est en pause, ou si l'objectif est déjà atteint :
 * dans ces cas, il n'y a pas d'alarme à programmer.
 */
fun millisUntilGoal(goalMillis: Long?, state: TimerState, now: Long): Long? {
    if (goalMillis == null || !state.isRunning) return null
    return (goalMillis - state.elapsedAt(now)).takeIf { it > 0 }
}

/**
 * Avancement vers l'objectif : 0 au départ, 1 à l'objectif, plus de 1 s'il est dépassé.
 * Null sans objectif.
 */
fun goalProgress(currentMillis: Long, goalMillis: Long?): Float? {
    if (goalMillis == null || goalMillis <= 0) return null
    return currentMillis.coerceAtLeast(0L).toFloat() / goalMillis
}
