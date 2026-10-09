package com.fixbyte.floatingvolume

enum class DiagnosticOperation { SERVICE_START, FOREGROUND, SERVICE_STOP, OVERLAY_ADD,
    OVERLAY_REMOVE, QUICK_MENU, SNAP, PEEK, ACTIVITY, CHANNEL }
enum class DiagnosticPhase { START, SUCCESS, FAILURE, CANCELLED }

/** No Android or Firebase dependency: privacy/bounds can be unit-tested. */
class DiagnosticJournal(private val clock: () -> Long = { System.nanoTime() / 1_000_000 }) {
    private val events = ArrayDeque<String>()
    private val errors = linkedMapOf<String, Long>()
    private var sequence = 0L
    @Synchronized fun begin(operation: DiagnosticOperation): Long = (++sequence).also {
        add(operation, DiagnosticPhase.START, it)
    }
    @Synchronized fun add(operation: DiagnosticOperation, phase: DiagnosticPhase, id: Long) {
        events.addLast("t=${clock()} op=${operation.name} phase=${phase.name} id=$id")
        while (events.size > 30) events.removeFirst()
    }
    @Synchronized fun snapshot(): List<String> = events.toList()
    @Synchronized fun allowError(category: String): Boolean {
        val now = clock()
        val previous = errors[category]
        if (previous != null && now - previous < 60_000) return false
        if (errors.size >= 64 && category !in errors) errors.remove(errors.keys.first())
        errors[category] = now
        return true
    }
    companion object {
        private val categories = setOf("service_start_failed", "service_stop_failed",
            "overlay_bad_token", "overlay_security", "overlay_state", "volume_security",
            "snap_detached", "snap_end_detached", "overlay_remove_failed", "native_self_test", "channel_stop_failed")
        fun category(value: String) = if (value in categories) value else "native_error"
        fun state(key: String, value: String): Boolean = when (key) {
            "service_active", "native_indicator", "auto_hide", "self_test",
            "window_attached", "window_removing" -> value == "true" || value == "false"
            "orientation", "volume_before", "volume_requested", "volume_actual", "volume_confirmed", "quick_menu_count",
            "foreground_ms", "native_operation_ms" -> value.toLongOrNull()?.let { it in 0..600_000 } == true
            "audio_stream" -> value in setOf("MEDIA", "RING", "NOTIFICATION", "ALARM", "SYSTEM", "VOICE_CALL")
            "widget_style" -> value in setOf("ANDROID", "ANDROID_12", "CARDS", "IOS", "MIUI", "SAMSUNG_ONE_UI",
                "RGB_AURORA", "RGB_NEON", "COSMIC", "LAVA", "GLACIER", "MATRIX", "RETROWAVE",
                "android", "android12", "ios", "miui", "samsungOneUi", "rgbAurora", "rgbNeon",
                "cosmic", "lava", "glacier", "matrix", "retrowave")
            "window_kind" -> value in setOf("controls", "indicator", "menu", "mixer", "unknown")
            "activity_state" -> value in setOf("created", "resumed", "paused", "destroyed")
            else -> false
        }
    }
}
