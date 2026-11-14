package com.example.vitrine.domain.model

/**
 * Chrono d'une tâche, enregistré pour survivre à la fermeture de l'application et au redémarrage.
 * On ne stocke pas un compteur qui avance, mais une heure de départ : le temps écoulé se recalcule
 * à tout moment, même si rien n'a tourné entre-temps.
 *
 * @property accumulatedMillis temps déjà compté avant la dernière pause.
 * @property runningSince heure de (re)démarrage si le chrono tourne, null s'il est en pause.
 */
data class TimerState(
    val taskId: Long,
    val accumulatedMillis: Long = 0L,
    val runningSince: Long? = null,
) {
    val isRunning: Boolean get() = runningSince != null

    /** Part de temps de la session en cours (0 en pause). Jamais négative, même si l'heure recule. */
    fun runningPartAt(now: Long): Long = runningSince?.let { (now - it).coerceAtLeast(0L) } ?: 0L

    /** Temps total affiché par le chrono à l'instant [now]. */
    fun elapsedAt(now: Long): Long = accumulatedMillis + runningPartAt(now)
}
