package com.example.vitrine.data.local.db.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.PrimaryKey
import com.example.vitrine.domain.model.TimerState

/** Une ligne par tâche dont le chrono n'est pas à zéro (en cours ou en pause). */
@Entity(
    tableName = "timer_states",
    foreignKeys = [
        ForeignKey(
            entity = TaskEntity::class,
            parentColumns = ["id"],
            childColumns = ["taskId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
)
data class TimerStateEntity(
    @PrimaryKey val taskId: Long,
    val accumulatedMillis: Long,
    val runningSince: Long?,
)

fun TimerStateEntity.toDomain() = TimerState(
    taskId = taskId,
    accumulatedMillis = accumulatedMillis,
    runningSince = runningSince,
)

fun TimerState.toEntity() = TimerStateEntity(
    taskId = taskId,
    accumulatedMillis = accumulatedMillis,
    runningSince = runningSince,
)
