package com.example.vitrine.data.local.db.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.example.vitrine.domain.model.TimerSession

@Entity(
    tableName = "timer_sessions",
    foreignKeys = [
        ForeignKey(
            entity = TaskEntity::class,
            parentColumns = ["id"],
            childColumns = ["taskId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("taskId")],
)
data class TimerSessionEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0L,
    val taskId: Long,
    val startedAt: Long,
    val endedAt: Long,
)

fun TimerSession.toEntity() = TimerSessionEntity(
    id = id,
    taskId = taskId,
    startedAt = startedAt,
    endedAt = endedAt,
)
