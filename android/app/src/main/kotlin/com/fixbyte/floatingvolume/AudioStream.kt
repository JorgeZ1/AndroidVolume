package com.fixbyte.floatingvolume

import android.media.AudioManager
import android.content.Context

/** A user-facing Android audio stream. Keep all volume operations routed through this model. */
enum class AudioStream(
    val streamType: Int,
    val label: String,
    val shortLabel: String,
    val symbol: String,
) {
    MEDIA(AudioManager.STREAM_MUSIC, "Media", "MEDIA", "♫"),
    RING(AudioManager.STREAM_RING, "Ringtone", "RING", "⌕"),
    NOTIFICATION(AudioManager.STREAM_NOTIFICATION, "Notifications", "NOTIF", "●"),
    ALARM(AudioManager.STREAM_ALARM, "Alarm", "ALARM", "◷"),
    SYSTEM(AudioManager.STREAM_SYSTEM, "System", "SYSTEM", "⚙"),
    VOICE_CALL(AudioManager.STREAM_VOICE_CALL, "Voice call", "CALL", "☎");

    fun localizedLabel(context: Context): String = if (NativeLanguage.isSpanish(context)) {
        when (this) {
            MEDIA -> "Multimedia"
            RING -> "Tono de llamada"
            NOTIFICATION -> "Notificaciones"
            ALARM -> "Alarma"
            SYSTEM -> "Sistema"
            VOICE_CALL -> "Llamada"
        }
    } else label

    fun localizedShortLabel(context: Context): String = if (NativeLanguage.isSpanish(context)) {
        when (this) {
            RING -> "TONO"
            ALARM -> "ALARMA"
            SYSTEM -> "SISTEMA"
            VOICE_CALL -> "LLAMADA"
            else -> shortLabel
        }
    } else shortLabel

    companion object {
        fun fromName(name: String?): AudioStream =
            entries.firstOrNull { it.name.equals(name, ignoreCase = true) } ?: MEDIA

        fun fromStreamType(type: Int): AudioStream? =
            entries.firstOrNull { it.streamType == type }
    }
}
