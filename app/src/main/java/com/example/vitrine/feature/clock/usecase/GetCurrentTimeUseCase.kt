package com.example.vitrine.feature.clock.usecase

import com.example.vitrine.core.util.tickerFlow
import java.text.DateFormatSymbols
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine

/**
 * Heure prête à afficher.
 *
 * @property hours heures : « 09 » en 24 h, « 9 » en 12 h.
 * @property period « AM » / « PM » (selon la langue) en 12 h, null en 24 h.
 * @property date date du jour, ex. « Vendredi 6 novembre ».
 * @property hourOfDay, minuteOfHour, secondOfMinute valeurs numériques, pour placer les aiguilles.
 */
data class ClockTime(
    val hours: String,
    val minutes: String,
    val seconds: String,
    val period: String?,
    val date: String,
    val hourOfDay: Int,
    val minuteOfHour: Int,
    val secondOfMinute: Int,
) {
    val hoursMinutes: String get() = "$hours:$minutes"
}

/**
 * Fournit l'heure courante, mise à jour chaque seconde, au format 12 h ou 24 h.
 * N'utilise que java.util (Calendar, SimpleDateFormat) : compatible minSdk 24 sans désucrage.
 */
class GetCurrentTimeUseCase(
    private val ticker: () -> Flow<Long> = { tickerFlow() },
    private val now: () -> Long = System::currentTimeMillis,
    private val timeZone: () -> TimeZone = { TimeZone.getDefault() },
    private val locale: () -> Locale = { Locale.getDefault() },
) {
    /** Flux de l'heure ; se reformate aussitôt quand [use24Hour] change. */
    operator fun invoke(use24Hour: Flow<Boolean>): Flow<ClockTime> =
        combine(ticker(), use24Hour) { millis, h24 -> format(millis, h24) }

    /** Heure de cet instant, pour un premier affichage sans attendre le flux. */
    fun current(use24Hour: Boolean): ClockTime = format(now(), use24Hour)

    private fun format(millis: Long, use24Hour: Boolean) =
        formatClockTime(millis, use24Hour, timeZone(), locale())
}

/** Mise en forme pure, testable sans Android. */
internal fun formatClockTime(
    millis: Long,
    use24Hour: Boolean,
    timeZone: TimeZone,
    locale: Locale,
): ClockTime {
    val calendar = Calendar.getInstance(timeZone, locale).apply { timeInMillis = millis }

    val hours = if (use24Hour) {
        calendar.get(Calendar.HOUR_OF_DAY).toString().padStart(2, '0')
    } else {
        // Calendar.HOUR va de 0 à 11 : minuit et midi s'affichent « 12 »
        calendar.get(Calendar.HOUR).let { if (it == 0) 12 else it }.toString()
    }
    val period = if (use24Hour) null else {
        DateFormatSymbols.getInstance(locale).amPmStrings[calendar.get(Calendar.AM_PM)]
    }
    val date = SimpleDateFormat("EEEE d MMMM", locale)
        .apply { this.timeZone = timeZone }
        .format(Date(millis))
        .replaceFirstChar { it.titlecase(locale) }

    val minute = calendar.get(Calendar.MINUTE)
    val second = calendar.get(Calendar.SECOND)

    return ClockTime(
        hours = hours,
        minutes = minute.toString().padStart(2, '0'),
        seconds = second.toString().padStart(2, '0'),
        period = period,
        date = date,
        hourOfDay = calendar.get(Calendar.HOUR_OF_DAY),
        minuteOfHour = minute,
        secondOfMinute = second,
    )
}
