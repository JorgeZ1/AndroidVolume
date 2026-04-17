package com.fixbyte.floatingvolume.bloc

import android.content.Context
import android.content.Intent
import android.os.Build
import com.fixbyte.floatingvolume.Const
import com.fixbyte.floatingvolume.FloatingVolumeService
import com.fixbyte.floatingvolume.inMain
import com.fixbyte.floatingvolume.sharedPrefs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
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
        val scope = CoroutineScope(Dispatchers.Main)
        val intent = Intent(context, FloatingVolumeService::class.java)

        event.collect {
            when (it) {
                is Event.Start -> {
                    if (_state.value is State.On) {
                        return@collect
                    }

                    scope.inMain {
                        // Use startForegroundService on Android O+ so the OS guarantees
                        // a 5-second window before requiring startForeground() to be called.
                        // This prevents ForegroundServiceDidNotStartInTimeException on
                        // aggressive OEM skins like MIUI, ColorOS and One UI.
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            context.startForegroundService(intent)
                        } else {
                            context.startService(intent)
                        }
                    }.join()

                    persistState(context, true)
                    _state.emit(State.On)
                }
                is Event.Stop -> {
                    if (_state.value is State.Off) {
                        return@collect
                    }

                    scope.inMain {
                        context.stopService(intent)
                    }.join()

                    persistState(context, false)
                    _state.emit(State.Off)
                }
                is Event.Toggle -> {
                    val newEvent = if (_state.value is State.On) {
                        Event.Stop
                    } else {
                        Event.Start
                    }

                    event.emit(newEvent)
                }
            }
        }
    }


}
