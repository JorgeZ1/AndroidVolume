package com.fixbyte.floatingvolume

import io.flutter.plugin.common.EventChannel

/** Publishes completed native changes, including selections made in the overlay. */
class SettingsStreamHandler : EventChannel.StreamHandler {
    private var sink: EventChannel.EventSink? = null
    private val listener: () -> Unit = { sink?.success(WidgetSettings.snapshot()) }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        dispose()
        sink = events
        WidgetSettings.addListener(listener)
        events.success(WidgetSettings.snapshot())
    }

    override fun onCancel(arguments: Any?) = dispose()

    fun dispose() {
        WidgetSettings.removeListener(listener)
        sink = null
    }
}
