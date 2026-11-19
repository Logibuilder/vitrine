package com.example.vitrine.data.local.db.entity

import androidx.room.ColumnInfo
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
    /**
     * Rang de la tâche dans la liste (1 = en haut). Ajouté en version 3 de la base
     * (voir AppDatabase.MIGRATION_2_3). La valeur par défaut doit être la même ici et dans la migration.
     */
    @ColumnInfo(defaultValue = "0")
    val position: Long = 0L,
)

fun TaskEntity.toDomain() = Task(
    id = id,
    name = name,
    createdAt = createdAt,
    goalMillis = goalMillis ?: Task.DEFAULT_GOAL_MILLIS,
)