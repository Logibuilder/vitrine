package com.example.vitrine.core.util

import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

/**
 * Émet l'heure actuelle (en millisecondes) tout de suite, puis à chaque début de période.
 * Les émissions sont calées sur l'horloge : avec une période d'une seconde, la valeur change
 * pile au changement de seconde, et non une seconde après l'ouverture de l'écran.
 *
 * @param now source de l'heure, remplaçable dans les tests.
 */
fun tickerFlow(
    periodMillis: Long = 1_000L,
    now: () -> Long = System::currentTimeMillis,
): Flow<Long> = flow {
    require(periodMillis > 0) { "La période doit être positive" }
    while (true) {
        val current = now()
        emit(current)
        delay(periodMillis - current % periodMillis)
    }
}
