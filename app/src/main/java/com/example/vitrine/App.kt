package com.example.vitrine

import android.app.Application
import com.example.vitrine.di.appModule
import com.example.vitrine.domain.usecase.ReconstructTimersUseCase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.koin.android.ext.android.get
import org.koin.android.ext.koin.androidContext
import org.koin.android.ext.koin.androidLogger
import org.koin.core.context.startKoin

class App : Application() {

    /** Travail de fond lié à la vie de l'application (pas à un écran). */
    private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onCreate() {
        super.onCreate()
        startKoin {
            androidLogger()
            androidContext(this@App)
            modules(appModule)
        }

        // Si une notification de chrono a été balayée ou perdue, on la remet au lancement
        val reconstructTimers: ReconstructTimersUseCase = get()
        appScope.launch { reconstructTimers() }
    }
}
