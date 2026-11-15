package com.example.vitrine.data.local.db.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.example.vitrine.domain.model.Task

@Entity(tableName = "tasks")
data class TaskEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0L,
    val name: String,
    val createdAt: Long,
    /**
     * Ajouté en version 2 de la base (voir AppDatabase.MIGRATION_1_2). La colonne accepte NULL
     * pour les tâches créées avant : elles prennent alors l'objectif par défaut.
     */
    val goalMillis: Long? = Task.DEFAULT_GOAL_MILLIS,
)

fun TaskEntity.toDomain() = Task(
    id = id,
    name = name,
    createdAt = createdAt,
    goalMillis = goalMillis ?: Task.DEFAULT_GOAL_MILLIS,
)
