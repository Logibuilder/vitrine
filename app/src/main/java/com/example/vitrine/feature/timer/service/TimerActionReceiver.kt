package com.example.vitrine.feature.timer.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.example.vitrine.feature.timer.service.TimerNotifications.ACTION_PAUSE
import com.example.vitrine.feature.timer.service.TimerNotifications.ACTION_STOP
import com.example.vitrine.feature.timer.service.TimerNotifications.EXTRA_TASK_ID
import com.example.vitrine.feature.timer.usecase.PauseTimerUseCase
import com.example.vitrine.feature.timer.usecase.StopTimerUseCase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/** Reçoit les boutons Pause et Arrêter de la notification, même application fermée. */
class TimerActionReceiver : BroadcastReceiver(), KoinComponent {

    private val pauseTimer: PauseTimerUseCase by inject()
    private val stopTimer: StopTimerUseCase by inject()

    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getLongExtra(EXTRA_TASK_ID, -1L).takeIf { it >= 0 } ?: return
        val action = intent.action ?: return

        // L'écriture en base est asynchrone : on garde le récepteur en vie jusqu'à la fin
        val pending = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                when (action) {
                    ACTION_PAUSE -> pauseTimer(taskId)
                    ACTION_STOP -> stopTimer(taskId)
                }
            } finally {
                pending.finish()
            }
        }
    }
}
