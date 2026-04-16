package com.github.mkalmousli.floating_volume

import android.content.SharedPreferences

/** Singleton that holds live widget settings and notifies listeners on change. */
object WidgetSettings {

    enum class ColorMode { AUTO, BLUE, DARK }

    enum class Style {
        ANDROID, ANDROID_12, IOS, MIUI, SAMSUNG_ONE_UI, RGB_AURORA, RGB_NEON, COSMIC, LAVA, CARDS;

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
                "cards"        -> CARDS
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

    var isPinned: Boolean = false
        set(value) { field = value; dispatch() }

    var buttonSize: Int = 52
        set(value) { field = value; dispatch() }
    var buttonCornerRadius: Float = 0.5f   // 0 = square, 1 = fully rounded
        set(value) { field = value; dispatch() }
    var buttonGap: Int = 10
        set(value) { field = value; dispatch() }

    var indicatorOpacity: Float = 1f
        set(value) { field = value; dispatch() }
    var indicatorHeight: Int = 160
        set(value) { field = value; dispatch() }
    var indicatorWidth: Int = 48
        set(value) { field = value; dispatch() }
    var indicatorGap: Int = 10
        set(value) { field = value; dispatch() }
    var indicatorHideDelay: Int = 1800
        set(value) { field = value; dispatch() }
    var indicatorAnimation: String = "fade"
        set(value) { field = value; dispatch() }
    
    var useSystemVolume: Boolean = false
        set(value) { field = value; dispatch() }

    private val listeners = mutableListOf<() -> Unit>()

    fun addListener(l: () -> Unit)    { listeners.add(l) }
    fun removeListener(l: () -> Unit) { listeners.remove(l) }
    private fun dispatch()            { listeners.forEach { it() } }

    // ── Persistence ───────────────────────────────────────────────────────────

    private const val KEY_COLOR_MODE = "widget_color_mode"
    private const val KEY_OPACITY    = "widget_opacity"
    private const val KEY_STYLE      = "widget_style"
    private const val KEY_PINNED     = "widget_pinned"
    private const val KEY_BTN_SIZE     = "widget_btn_size"
    private const val KEY_BTN_CORNER   = "widget_btn_corner"
    private const val KEY_BTN_GAP      = "widget_btn_gap"
    private const val KEY_IND_OPACITY  = "widget_ind_opacity"
    private const val KEY_IND_HEIGHT   = "widget_ind_height"
    private const val KEY_IND_WIDTH    = "widget_ind_width"
    private const val KEY_IND_GAP      = "widget_ind_gap"
    private const val KEY_IND_DELAY    = "widget_ind_delay"
    private const val KEY_IND_ANIM     = "widget_ind_anim"
    private const val KEY_USE_SYS_VOL  = "widget_use_sys_vol"

    fun load(prefs: SharedPreferences) {
        colorMode = ColorMode.entries.getOrElse(prefs.getInt(KEY_COLOR_MODE, 0)) { ColorMode.AUTO }
        opacity   = prefs.getFloat(KEY_OPACITY, 1f)
        style     = Style.entries.getOrElse(prefs.getInt(KEY_STYLE, 0)) { Style.ANDROID }
        isPinned  = prefs.getBoolean(KEY_PINNED, false)
        buttonSize           = prefs.getInt(KEY_BTN_SIZE, 52)
        buttonCornerRadius   = prefs.getFloat(KEY_BTN_CORNER, 0.5f)
        buttonGap            = prefs.getInt(KEY_BTN_GAP, 10)
        indicatorOpacity     = prefs.getFloat(KEY_IND_OPACITY, 1f)
        indicatorHeight      = prefs.getInt(KEY_IND_HEIGHT, 160)
        indicatorWidth       = prefs.getInt(KEY_IND_WIDTH, 48)
        indicatorGap         = prefs.getInt(KEY_IND_GAP, 10)
        indicatorHideDelay   = prefs.getInt(KEY_IND_DELAY, 1800)
        indicatorAnimation   = prefs.getString(KEY_IND_ANIM, "fade") ?: "fade"
        useSystemVolume      = prefs.getBoolean(KEY_USE_SYS_VOL, false)
    }

    fun save(prefs: SharedPreferences) {
        prefs.edit()
            .putInt(KEY_COLOR_MODE,  colorMode.ordinal)
            .putFloat(KEY_OPACITY,   opacity)
            .putInt(KEY_STYLE,       style.ordinal)
            .putBoolean(KEY_PINNED,  isPinned)
            .putInt(KEY_BTN_SIZE,    buttonSize)
            .putFloat(KEY_BTN_CORNER, buttonCornerRadius)
            .putInt(KEY_BTN_GAP,     buttonGap)
            .putFloat(KEY_IND_OPACITY, indicatorOpacity)
            .putInt(KEY_IND_HEIGHT,  indicatorHeight)
            .putInt(KEY_IND_WIDTH,   indicatorWidth)
            .putInt(KEY_IND_GAP,     indicatorGap)
            .putInt(KEY_IND_DELAY,   indicatorHideDelay)
            .putString(KEY_IND_ANIM, indicatorAnimation)
            .putBoolean(KEY_USE_SYS_VOL, useSystemVolume)
            .apply()
    }
}
