package com.example.vitrine.domain.alarm

/**
 * Programme l'alarme « objectif atteint » d'une tâche.
 * Interface du domaine : l'implémentation Android (AlarmManager) est dans feature/timer/service.
 */
interface GoalAlarmScheduler {
    /** Programme (ou reprogramme) l'alarme de la tâche à l'heure [triggerAtMillis]. */
    fun schedule(taskId: Long, triggerAtMillis: Long)

    fun cancel(taskId: Long)
}
