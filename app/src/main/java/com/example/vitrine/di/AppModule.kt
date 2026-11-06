package com.example.vitrine.di

import com.example.vitrine.MainViewModel
import com.example.vitrine.feature.clock.usecase.GetCurrentTimeUseCase
import com.example.vitrine.feature.clock.viewmodel.ClockViewModel
import com.example.vitrine.feature.text.viewmodel.TextViewModel
import org.koin.core.module.dsl.viewModelOf
import org.koin.dsl.module

val appModule = module {
    viewModelOf(::MainViewModel)
    viewModelOf(::TextViewModel)

    // Horloge
    factory { GetCurrentTimeUseCase() }
    viewModelOf(::ClockViewModel)
}
