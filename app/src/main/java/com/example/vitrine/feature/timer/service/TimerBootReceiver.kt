package com.example.vitrine.feature.timer.service

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.example.vitrine.domain.usecase.ReconstructTimersUseCase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * Après un redémarrage du téléphone (ou une mise à jour de l'application), notifications et alarmes
 * ont disparu : on les remet pour les chronos qui tournent encore.
 * Même chose quand l'utilisateur autorise les alarmes exactes : les alarmes sont reprogrammées à l'heure exacte.
 */
class TimerBootReceiver : BroadcastReceiver(), KoinComponent {

    private val reconstructTimers: ReconstructTimersUseCase by inject()

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in HANDLED_ACTIONS) return

        val pending = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                reconstructTimers()
            } finally {
                pending.finish()
            }
        }
    }

    private companion object {
        val HANDLED_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED,
        )
    }
}
