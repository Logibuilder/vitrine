package com.example.vitrine.core.util

/**
 * Temps d'un chrono : « 04:07 » sous une heure, « 1:04:07 » au-delà.
 * Les secondes sont tronquées (un chrono n'affiche pas 1 s avant qu'elle soit écoulée).
 */
fun formatStopwatch(millis: Long): String {
    val totalSeconds = millis.coerceAtLeast(0L) / 1_000
    val hours = totalSeconds / 3_600
    val minutes = (totalSeconds % 3_600) / 60
    val seconds = totalSeconds % 60
    return if (hours > 0) {
        "$hours:${minutes.twoDigits()}:${seconds.twoDigits()}"
    } else {
        "${minutes.twoDigits()}:${seconds.twoDigits()}"
    }
}

/** Temps total, lisible d'un coup d'œil : « 3 h 12 min », « 12 min », « 45 s ». */
fun formatTotal(millis: Long): String {
    val totalSeconds = millis.coerceAtLeast(0L) / 1_000
    val hours = totalSeconds / 3_600
    val minutes = (totalSeconds % 3_600) / 60
    return when {
        hours > 0 && minutes > 0 -> "$hours h $minutes min"
        hours > 0 -> "$hours h"
        minutes > 0 -> "$minutes min"
        else -> "$totalSeconds s"
    }
}

private fun Long.twoDigits(): String = toString().padStart(2, '0')
