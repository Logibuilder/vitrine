package com.example.vitrine.feature.timer.ui

import android.Manifest
import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.vitrine.core.navigation.AppDestination
import com.example.vitrine.feature.timer.ui.home.TimerHomeScreen
import com.example.vitrine.feature.timer.viewmodel.TimerViewModel
import org.koin.androidx.compose.koinViewModel

/**
 * Point d'entrée de la feature chronos : relie l'écran au ViewModel.
 * Seules les autorisations système restent ici (c'est de l'UI Android) :
 * - notifications : demandées au premier lancement d'un chrono (Android 13+) ;
 * - alarmes exactes : vérifiées à chaque retour sur l'écran (Android 12+), avec un lien vers le réglage.
 * Sans elles, les chronos fonctionnent : la notification manque, ou l'alarme peut être un peu retardée.
 */
@Composable
fun TimerScreen(
    onNavigate: (AppDestination) -> Unit,
    viewModel: TimerViewModel = koinViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current

    // Notifications
    var permissionAsked by rememberSaveable { mutableStateOf(false) }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) viewModel.onNotificationPermissionGranted()
    }

    fun askNotificationPermissionOnce() {
        if (permissionAsked || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (!granted) {
            permissionAsked = true
            permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    // Alarmes exactes : revérifiées au retour du réglage système
    var exactAlarmAllowed by remember { mutableStateOf(context.canScheduleExactAlarms()) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) {
        exactAlarmAllowed = context.canScheduleExactAlarms()
    }

    TimerHomeScreen(
        state = state,
        onNewTaskNameChange = viewModel::onNewTaskNameChange,
        onAddTask = viewModel::addTask,
        onToggle = { item ->
            if (!item.isRunning) askNotificationPermissionOnce()
            viewModel.toggle(item)
        },
        onReset = viewModel::reset,
        onUpdate = viewModel::updateTask,
        onDelete = viewModel::delete,
        exactAlarmAllowed = exactAlarmAllowed,
        onAllowExactAlarm = { context.openExactAlarmSettings() },
        onNavigate = onNavigate,
    )
}

private fun Context.canScheduleExactAlarms(): Boolean =
    Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
        getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

/** Ouvre le réglage « Alarmes et rappels » de l'application (Android 12+). */
private fun Context.openExactAlarmSettings() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
    startActivity(
        Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName"))
    )
}
