package com.fixbyte.floatingvolume

import android.media.AudioManager

/** A user-facing Android audio stream. Keep all volume operations routed through this model. */
enum class AudioStream(
    val streamType: Int,
    val label: String,
    val shortLabel: String,
    val symbol: String,
) {
    MEDIA(AudioManager.STREAM_MUSIC, "Multimedia", "MEDIA", "♫"),
    RING(AudioManager.STREAM_RING, "Tono de llamada", "TONO", "⌕"),
    NOTIFICATION(AudioManager.STREAM_NOTIFICATION, "Notificaciones", "NOTIF", "●"),
    ALARM(AudioManager.STREAM_ALARM, "Alarma", "ALARMA", "◷"),
    SYSTEM(AudioManager.STREAM_SYSTEM, "Sistema", "SISTEMA", "⚙"),
    VOICE_CALL(AudioManager.STREAM_VOICE_CALL, "Llamada", "LLAMADA", "☎");

    companion object {
        fun fromName(name: String?): AudioStream =
            entries.firstOrNull { it.name.equals(name, ignoreCase = true) } ?: MEDIA

        fun fromStreamType(type: Int): AudioStream? =
            entries.firstOrNull { it.streamType == type }
    }
}
