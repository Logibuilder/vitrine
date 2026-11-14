package com.example.vitrine.domain.notification

import com.example.vitrine.domain.model.Task
import com.example.vitrine.domain.model.TimerState

/**
 * Affiche ou retire la notification d'un chrono en cours.
 * Interface du domaine : les use cases ne dépendent pas d'Android ; l'implémentation est dans feature/timer/service.
 */
interface TimerNotifier {
    /** Notification persistante avec le temps qui défile (compteur système, sans réveiller l'app). */
    fun showRunning(task: Task, state: TimerState)

    fun cancel(taskId: Long)

    /** Notification sonore « objectif atteint » ; le chrono, lui, continue. */
    fun showGoalReached(task: Task)
}
