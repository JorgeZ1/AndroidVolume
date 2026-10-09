package com.fixbyte.floatingvolume

import android.os.SystemClock
import android.content.pm.ApplicationInfo
import com.google.firebase.FirebaseApp
import com.google.firebase.crashlytics.FirebaseCrashlytics
import com.google.firebase.perf.FirebasePerformance

/** Only bounded technical context. No text, files, account IDs or screen capture. */
object TechnicalMonitoring {
    @Volatile var enabledOverride: Boolean? = null
    private val journal = DiagnosticJournal()
    private val eventTimes = mutableMapOf<String, Long>()
    private val events = setOf("service_created", "orientation_changed", "drag_started",
        "quick_menu_requested", "quick_menu_hidden", "service_foreground_ready", "service_destroyed",
        "native_monitoring_self_test", "volume_applied", "volume_mismatch")
    private fun crashlytics(): FirebaseCrashlytics? = runCatching {
        val context = FirebaseApp.getInstance().applicationContext
        val enabled = enabledOverride ?: ((context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) == 0)
        FirebaseCrashlytics.getInstance().takeIf { enabled }
    }.getOrNull()

    @Synchronized fun event(name: String) {
        if (name !in events) return
        val now = SystemClock.elapsedRealtime()
        if (eventTimes[name]?.let { now - it < 500 } == true) return
        eventTimes[name] = now
        runCatching { crashlytics()?.log(name) }
    }
    fun state(key: String, value: String) {
        if (!DiagnosticJournal.state(key, value)) return
        runCatching { crashlytics()?.setCustomKey(key, value) }
    }
    @Synchronized fun error(category: String, error: Throwable) {
        val safeCategory = DiagnosticJournal.category(category)
        val client = crashlytics() ?: return
        if (!journal.allowError(safeCategory)) return
        runCatching {
            // Do not forward arbitrary exception messages or chained causes.
            val safe = RuntimeException("$safeCategory:${error.javaClass.simpleName}")
            safe.stackTrace = error.stackTrace
            client.setCustomKey("diagnostic_schema", 1)
            client.setCustomKey("native_error_category", safeCategory)
            journal.snapshot().forEach { client.log(it) }
            client.recordException(safe)
        }
    }
    fun begin(operation: DiagnosticOperation): Long {
        if (crashlytics() == null) return 0
        return journal.begin(operation).also { id ->
            runCatching { crashlytics()?.log("op=${operation.name} phase=START id=$id") }
        }
    }
    fun finish(operation: DiagnosticOperation, id: Long, success: Boolean = true) {
        if (id == 0L) return
        journal.add(operation, if (success) DiagnosticPhase.SUCCESS else DiagnosticPhase.FAILURE, id)
        runCatching { crashlytics()?.log(journal.snapshot().last()) }
    }
    fun transition(operation: DiagnosticOperation, phase: DiagnosticPhase) {
        if (crashlytics() == null) return
        journal.add(operation, phase, 0)
        runCatching { crashlytics()?.log(journal.snapshot().last()) }
    }
    fun duration(name: String, milliseconds: Long) {
        if (name !in setOf("native_service_ready", "native_foreground_promotion") || crashlytics() == null) return
        runCatching {
            val trace = FirebasePerformance.getInstance().newTrace(name)
            trace.start()
            trace.putMetric("duration_ms", milliseconds.coerceIn(0, 600_000))
            trace.stop()
        }
    }
    fun volume(stream: String, before: Int, target: Int, actual: Int) {
        state("audio_stream", stream)
        state("volume_before", before.toString())
        state("volume_requested", target.toString())
        state("volume_actual", actual.toString())
        event(if (target == actual) "volume_applied" else "volume_mismatch")
    }
    fun measure(name: String, block: () -> Unit) {
        val trace = runCatching {
            FirebasePerformance.getInstance().takeIf { it.isPerformanceCollectionEnabled }
                ?.newTrace(name)?.also { it.start() }
        }.getOrNull()
        try { block() } finally { runCatching { trace?.stop() } }
    }
}
