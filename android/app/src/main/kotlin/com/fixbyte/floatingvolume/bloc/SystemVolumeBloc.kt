package com.fixbyte.floatingvolume.bloc

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.util.Log
import com.fixbyte.floatingvolume.AudioStream
import com.fixbyte.floatingvolume.WidgetSettings
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.callbackFlow

/**
 * Single source of truth for the selected audio stream. Android broadcasts all
 * stream changes; callers can therefore refresh linked OEM streams too.
 */
object SystemVolumeBloc {
    private val _state = MutableStateFlow<State>(State.Uninitialized)
    val state = _state.asStateFlow()
    val event = MutableSharedFlow<Event>()

    sealed class State {
        object Uninitialized : State()
        data class Initialized(val stream: AudioStream, val volume: Int, val maxVolume: Int) : State()
    }

    sealed class Event {
        data class SetVolume(val volume: Int) : Event()
        data class SelectStream(val stream: AudioStream) : Event()
        object Mute : Event()
    }

    private fun selected() = WidgetSettings.selectedAudioStream

    private suspend fun emitCurrent(audio: AudioManager, stream: AudioStream = selected()) {
        _state.emit(State.Initialized(stream, audio.getStreamVolume(stream.streamType), audio.getStreamMaxVolume(stream.streamType)))
    }

    suspend fun initialize(context: Context) {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        emitCurrent(audio)
        Log.d("SystemVolumeBloc", "Initialized stream=${selected()} volume=${audio.getStreamVolume(selected().streamType)}")
    }

    suspend fun observeSystemVolume(context: Context) {
        val flow = callbackFlow {
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    val type = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_TYPE", -1)
                    val stream = AudioStream.fromStreamType(type) ?: return
                    trySend(stream)
                }
            }
            context.registerReceiver(receiver, IntentFilter("android.media.VOLUME_CHANGED_ACTION"))
            awaitClose { context.unregisterReceiver(receiver) }
        }
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        flow.collect { changed ->
            if (changed == selected()) emitCurrent(audio, changed)
        }
    }

    suspend fun handleEvents(context: Context) {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        event.collect { event ->
            when (event) {
                is Event.SelectStream -> emitCurrent(audio, event.stream)
                is Event.SetVolume -> {
                    val stream = selected()
                    val target = event.volume.coerceIn(0, audio.getStreamMaxVolume(stream.streamType))
                    try {
                        audio.setStreamVolume(stream.streamType, target, AudioManager.FLAG_PLAY_SOUND)
                        emitCurrent(audio, stream)
                    } catch (error: SecurityException) {
                        Log.w("SystemVolumeBloc", "Volume change blocked for $stream", error)
                    }
                }
                Event.Mute -> {
                    val stream = selected()
                    try {
                        audio.setStreamVolume(stream.streamType, 0, AudioManager.FLAG_PLAY_SOUND)
                        emitCurrent(audio, stream)
                    } catch (error: SecurityException) {
                        Log.w("SystemVolumeBloc", "Mute blocked for $stream", error)
                    }
                }
            }
        }
    }
}
