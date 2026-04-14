package com.github.mkalmousli.floating_volume

import android.content.SharedPreferences

/** Singleton that holds live widget settings and notifies listeners on change. */
object WidgetSettings {

    enum class ColorMode { AUTO, BLUE, DARK }

    enum class Style {
        ANDROID, ANDROID_12, IOS, MIUI, SAMSUNG_ONE_UI, RGB_AURORA, RGB_NEON, COSMIC, LAVA;

        companion object {
            fun fromName(name: String): Style = when (name) {
                "android12"    -> ANDROID_12
                "ios"          -> IOS
                "miui"         -> MIUI
                "samsungOneUi" -> SAMSUNG_ONE_UI
                "rgbAurora"    -> RGB_AURORA
                "rgbNeon"      -> RGB_NEON
                "cosmic"       -> COSMIC
                "lava"         -> LAVA
                else           -> ANDROID
            }
        }
    }

    var colorMode: ColorMode = ColorMode.AUTO
        set(value) { field = value; dispatch() }

    var opacity: Float = 1f
        set(value) { field = value; dispatch() }

    var style: Style = Style.ANDROID
        set(value) { field = value; dispatch() }

    private val listeners = mutableListOf<() -> Unit>()

    fun addListener(l: () -> Unit)    { listeners.add(l) }
    fun removeListener(l: () -> Unit) { listeners.remove(l) }
    private fun dispatch()            { listeners.forEach { it() } }

    // ── Persistence ───────────────────────────────────────────────────────────

    private const val KEY_COLOR_MODE = "widget_color_mode"
    private const val KEY_OPACITY    = "widget_opacity"
    private const val KEY_STYLE      = "widget_style"

    fun load(prefs: SharedPreferences) {
        colorMode = ColorMode.entries.getOrElse(prefs.getInt(KEY_COLOR_MODE, 0)) { ColorMode.AUTO }
        opacity   = prefs.getFloat(KEY_OPACITY, 1f)
        style     = Style.entries.getOrElse(prefs.getInt(KEY_STYLE, 0)) { Style.ANDROID }
    }

    fun save(prefs: SharedPreferences) {
        prefs.edit()
            .putInt(KEY_COLOR_MODE, colorMode.ordinal)
            .putFloat(KEY_OPACITY,  opacity)
            .putInt(KEY_STYLE,      style.ordinal)
            .apply()
    }
}
