package com.example.vitrine.data.local.db

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.example.vitrine.data.local.db.entity.TaskEntity
import com.example.vitrine.data.local.db.entity.TimerSessionEntity
import com.example.vitrine.data.local.db.entity.TimerStateEntity

/**
 * Base de données locale de l'application.
 * Version 1 : tâches, sessions terminées et chronos en cours.
 * Version 2 : objectif de temps par tâche (colonne tasks.goalMillis).
 * Version 3 : ordre des tâches choisi par l'utilisateur (colonne tasks.position).
 *
 * Pour chaque changement de schéma : 1) modifier l'entité, 2) monter `version`,
 * 3) écrire la Migration(n, n+1), 4) l'ajouter dans addMigrations().
 * Penser à ajouter une migration (et à monter la version) à chaque changement de schéma.
 */
@Database(
    entities = [TaskEntity::class, TimerSessionEntity::class, TimerStateEntity::class],
    version = 3,
    exportSchema = false,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun taskDao(): TaskDao
    abstract fun timerSessionDao(): TimerSessionDao
    abstract fun timerStateDao(): TimerStateDao

    companion object {
        /** Garde les tâches et l'historique existants : on ajoute seulement la colonne de l'objectif. */
        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE tasks ADD COLUMN goalMillis INTEGER")
            }
        }

        /**
         * Ajoute le rang des tâches, puis donne à chaque tâche existante son identifiant comme rang :
         * l'ordre affiché avant la mise à jour (ordre de création) est conservé.
         */
        val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE tasks ADD COLUMN position INTEGER NOT NULL DEFAULT 0")
                db.execSQL("UPDATE tasks SET position = id")
            }
        }

        fun create(context: Context): AppDatabase =
            Room.databaseBuilder(context, AppDatabase::class.java, "vitrine.db")
                .addMigrations(MIGRATION_1_2, MIGRATION_2_3)
                .build()
    }
}