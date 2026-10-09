package com.fixbyte.floatingvolume.bloc

import android.content.Context
import android.content.Intent
import android.os.Build
import com.fixbyte.floatingvolume.ForegroundNotificationChannel
import com.fixbyte.floatingvolume.TechnicalMonitoring
import com.fixbyte.floatingvolume.DiagnosticOperation
import android.os.SystemClock
import com.fixbyte.floatingvolume.FloatingVolumeService
import com.fixbyte.floatingvolume.sharedPrefs
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

object ServiceStatusBloc {
    private val _state = MutableStateFlow<State>(State.Off)

    fun initializeState(context: Context) {
        val wasOn = wasEnabledBeforeReboot(context)
        _state.value = if (wasOn) State.On else State.Off
    }

    val state = _state.asStateFlow()


    val event =
        MutableSharedFlow<Event>()


    sealed class State {
        object On : State()
        object Off : State()
    }

    sealed class Event {
        object Start : Event()
        object Stop : Event()
        object Toggle : Event()
    }



    /** Key used to persist the service enabled state across reboots. */
    private const val KEY_SERVICE_ENABLED = "service_enabled"

    /**
     * Returns true if the service was enabled before the last reboot.
     * Used by [BootReceiver] to auto-restart the service.
     */
    fun wasEnabledBeforeReboot(context: Context): Boolean =
        context.sharedPrefs.getBoolean(KEY_SERVICE_ENABLED, false)

    private fun persistState(context: Context, on: Boolean) {
        context.sharedPrefs.edit().putBoolean(KEY_SERVICE_ENABLED, on).apply()
    }

    suspend fun registerEvents(context: Context) {
        val intent = Intent(context, FloatingVolumeService::class.java)

        event.collect {
            // Resolve Toggle in this collector, without recursively emitting to
            // the same unbuffered flow or launching a second event producer.
            val action = if (it is Event.Toggle) {
                if (_state.value is State.On) Event.Stop else Event.Start
            } else it
            when (action) {
                is Event.Start -> {
                    if (_state.value is State.On) {
                        return@collect
                    }

                    val operation = TechnicalMonitoring.begin(DiagnosticOperation.SERVICE_START)
                    val startedAt = SystemClock.elapsedRealtime()
                    try {
                        val ready = withContext(Dispatchers.Main.immediate) {
                            ForegroundNotificationChannel.ensure(context)
                            val signal = FloatingVolumeService.prepareStart()
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                context.startForegroundService(intent)
                            } else {
                                context.startService(intent)
                            }
                            signal
                        }
                        // Suspend the event collector, not the main thread. A queued
                        // Stop is processed only after onStartCommand has promoted us.
                        withTimeout(10_000L) { ready.await() }
                        TechnicalMonitoring.duration("native_service_ready", SystemClock.elapsedRealtime() - startedAt)
                        TechnicalMonitoring.finish(DiagnosticOperation.SERVICE_START, operation)
                        persistState(context, true)
                        _state.emit(State.On)
                    } catch (e: Exception) {
                        if (e is CancellationException && e !is kotlinx.coroutines.TimeoutCancellationException) throw e
                        persistState(context, false)
                        _state.emit(State.Off)
                        TechnicalMonitoring.error("service_start_failed", e)
                        TechnicalMonitoring.finish(DiagnosticOperation.SERVICE_START, operation, false)
                    }
                }
                is Event.Stop -> {
                    if (_state.value is State.Off) {
                        return@collect
                    }

                    val operation = TechnicalMonitoring.begin(DiagnosticOperation.SERVICE_STOP)
                    try {
                    withContext(Dispatchers.Main.immediate) {
                        context.stopService(intent)
                    }

                    persistState(context, false)
                    _state.emit(State.Off)
                    TechnicalMonitoring.finish(DiagnosticOperation.SERVICE_STOP, operation)
                    } catch (e: Exception) {
                        if (e is CancellationException) throw e
                        TechnicalMonitoring.finish(DiagnosticOperation.SERVICE_STOP, operation, false)
                        TechnicalMonitoring.error("service_stop_failed", e)
                    }
                }
                is Event.Toggle -> error("Toggle must be resolved before dispatch")
            }
        }
    }


}
