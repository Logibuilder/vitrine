package com.example.vitrine.core.util

/** Source de l'heure (millisecondes depuis 1970), remplaçable dans les tests. */
fun interface Clock {
    fun now(): Long

    companion object {
        val System = Clock { java.lang.System.currentTimeMillis() }
    }
}
