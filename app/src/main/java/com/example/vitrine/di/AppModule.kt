package com.example.vitrine.di

import com.example.vitrine.MainViewModel
import com.example.vitrine.core.hardware.CameraTorchController
import com.example.vitrine.core.hardware.TorchController
import com.example.vitrine.core.util.Clock
import com.example.vitrine.data.local.db.AppDatabase
import com.example.vitrine.data.repository.TaskRepositoryImpl
import com.example.vitrine.data.repository.TimerRepositoryImpl
import com.example.vitrine.domain.alarm.GoalAlarmScheduler
import com.example.vitrine.domain.repository.TaskRepository
import com.example.vitrine.domain.repository.TimerRepository
import com.example.vitrine.domain.usecase.ReconstructTimersUseCase
import com.example.vitrine.feature.clock.usecase.GetCurrentTimeUseCase
import com.example.vitrine.feature.clock.viewmodel.ClockViewModel
import com.example.vitrine.feature.flashlight.usecase.SetScreenBrightnessUseCase
import com.example.vitrine.feature.flashlight.viewmodel.FlashlightViewModel
import com.example.vitrine.feature.text.viewmodel.TextViewModel
import com.example.vitrine.feature.timer.service.AndroidGoalAlarmScheduler
import com.example.vitrine.feature.timer.service.AndroidTimerNotifier
import com.example.vitrine.domain.notification.TimerNotifier
import com.example.vitrine.feature.timer.usecase.AddTaskUseCase
import com.example.vitrine.feature.timer.usecase.DeleteTaskUseCase
import com.example.vitrine.feature.timer.usecase.NotifyGoalReachedUseCase
import com.example.vitrine.feature.timer.usecase.ObserveTaskTimersUseCase
import com.example.vitrine.feature.timer.usecase.PauseTimerUseCase
import com.example.vitrine.feature.timer.usecase.StartTimerUseCase
import com.example.vitrine.feature.timer.usecase.StopTimerUseCase
import com.example.vitrine.feature.timer.usecase.UpdateTaskUseCase
import com.example.vitrine.feature.timer.viewmodel.TimerViewModel
import org.koin.android.ext.koin.androidContext
import org.koin.core.module.dsl.factoryOf
import org.koin.core.module.dsl.viewModelOf
import org.koin.dsl.module

val appModule = module {
    single { Clock.System }

    // Base de données Room
    single { AppDatabase.create(androidContext()) }
    single { get<AppDatabase>().taskDao() }
    single { get<AppDatabase>().timerSessionDao() }
    single { get<AppDatabase>().timerStateDao() }

    viewModelOf(::MainViewModel)
    viewModelOf(::TextViewModel)

    // Horloge
    factory { GetCurrentTimeUseCase() }
    viewModelOf(::ClockViewModel)

    // Lampe : un seul contrôleur de flash pour toute l'application
    single<TorchController> { CameraTorchController(androidContext()) }
    factory { SetScreenBrightnessUseCase() }
    viewModelOf(::FlashlightViewModel)

    // Chronos par tâche
    single<TaskRepository> { TaskRepositoryImpl(get()) }
    single<TimerRepository> { TimerRepositoryImpl(get(), get()) }
    single<TimerNotifier> { AndroidTimerNotifier(androidContext()) }
    single<GoalAlarmScheduler> { AndroidGoalAlarmScheduler(androidContext()) }
    factoryOf(::ObserveTaskTimersUseCase)
    factoryOf(::AddTaskUseCase)
    factoryOf(::StartTimerUseCase)
    factoryOf(::PauseTimerUseCase)
    factoryOf(::StopTimerUseCase)
    factoryOf(::UpdateTaskUseCase)
    factoryOf(::DeleteTaskUseCase)
    factoryOf(::NotifyGoalReachedUseCase)
    factoryOf(::ReconstructTimersUseCase)
    viewModelOf(::TimerViewModel)
}
