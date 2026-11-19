package com.example.vitrine.domain.model

/**
 * Une tâche dont on mesure le temps (ex. « Révisions », « Sport »).
 *
 * @property goalMillis objectif de temps du chrono (ex. 25 min). Chaque tâche en a un :
 *   [DEFAULT_GOAL_MILLIS] à la création, modifiable ensuite.
 *   Quand le chrono l'atteint, une alarme sonne ; le chrono, lui, continue de compter.
 */
data class Task(
    val id: Long,
    val name: String,
    val createdAt: Long,
    val goalMillis: Long = DEFAULT_GOAL_MILLIS,
) {
    companion object {
        /** Un nom doit tenir sur une carte et dans une notification. */
        const val MAX_NAME_LENGTH = 40

        /** Objectif d'une nouvelle tâche : 25 minutes. */
        const val DEFAULT_GOAL_MILLIS = 25 * 60_000L

        /** Objectif minimal : 1 minute (un objectif nul n'aurait pas de sens). */
        const val MIN_GOAL_MILLIS = 60_000L
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
 * Null si le chrono est en pause ou si l'objectif est déjà atteint :
 * dans ces cas, il n'y a pas d'alarme à programmer.
 */
fun millisUntilGoal(goalMillis: Long, state: TimerState, now: Long): Long? {
    if (!state.isRunning) return null
    return (goalMillis - state.elapsedAt(now)).takeIf { it > 0 }
}

/** Avancement vers l'objectif : 0 au départ, 1 à l'objectif, plus de 1 s'il est dépassé. */
fun goalProgress(currentMillis: Long, goalMillis: Long): Float =
    currentMillis.coerceAtLeast(0L).toFloat() / goalMillis.coerceAtLeast(Task.MIN_GOAL_MILLIS)

/**
 * Ordre obtenu en déplaçant [fromId] à la place de [toId] (les éléments entre les deux se décalent).
 * Renvoie la liste inchangée si l'un des deux identifiants est absent.
 */
fun List<Long>.moved(fromId: Long, toId: Long): List<Long> {
    val from = indexOf(fromId)
    val to = indexOf(toId)
    if (from < 0 || to < 0 || from == to) return this
    return toMutableList().apply { add(to, removeAt(from)) }
}

/**
 * Applique un ordre voulu à une liste : les éléments connus de [order] d'abord, dans cet ordre ;
 * les autres (nouvelles tâches) ensuite, dans leur ordre d'origine.
 */
fun <T> List<T>.orderedBy(order: List<Long>, id: (T) -> Long): List<T> {
    if (order.isEmpty()) return this
    val rank = order.withIndex().associate { (index, value) -> value to index }
    return sortedBy { rank[id(it)] ?: Int.MAX_VALUE } // tri stable
}