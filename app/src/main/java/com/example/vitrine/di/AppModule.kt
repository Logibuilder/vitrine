package com.example.vitrine.di

import com.example.vitrine.MainViewModel
import com.example.vitrine.core.hardware.CameraTorchController
import com.example.vitrine.core.hardware.TorchController
import com.example.vitrine.feature.clock.usecase.GetCurrentTimeUseCase
import com.example.vitrine.feature.clock.viewmodel.ClockViewModel
import com.example.vitrine.feature.flashlight.usecase.SetScreenBrightnessUseCase
import com.example.vitrine.feature.flashlight.viewmodel.FlashlightViewModel
import com.example.vitrine.feature.text.viewmodel.TextViewModel
import org.koin.android.ext.koin.androidContext
import org.koin.core.module.dsl.viewModelOf
import org.koin.dsl.module

val appModule = module {
    viewModelOf(::MainViewModel)
    viewModelOf(::TextViewModel)

    // Horloge
    factory { GetCurrentTimeUseCase() }
    viewModelOf(::ClockViewModel)

    // Lampe : un seul contrôleur de flash pour toute l'application
    single<TorchController> { CameraTorchController(androidContext()) }
    factory { SetScreenBrightnessUseCase() }
    viewModelOf(::FlashlightViewModel)
}
