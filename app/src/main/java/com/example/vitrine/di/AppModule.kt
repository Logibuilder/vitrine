package com.example.vitrine.di

import com.example.vitrine.feature.text.viewmodel.TextViewModel
import org.koin.core.module.dsl.viewModelOf
import org.koin.dsl.module

val appModule = module {
    viewModelOf(::TextViewModel)
}