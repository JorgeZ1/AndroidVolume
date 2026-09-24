package com.fixbyte.floatingvolume

import android.content.SharedPreferences

/** Singleton that holds live widget settings and notifies listeners on change. */
object WidgetSettings {

    enum class ColorMode { AUTO, BLUE, DARK }

    enum class Style {
        // New styles must be appended at the end: the selection is persisted by ordinal.
        ANDROID, ANDROID_12, IOS, MIUI, SAMSUNG_ONE_UI, RGB_AURORA, RGB_NEON, COSMIC, LAVA, CARDS,
        GLACIER, MATRIX, RETROWAVE;

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
                "glacier"      -> GLACIER
                "matrix"       -> MATRIX
                "retrowave"    -> RETROWAVE
                else           -> ANDROID
            }
        }
    }

    var colorMode: ColorMode = ColorMode.AUTO
        set(value) { field = value; dispatch() }

    var opacity: Float = 0.70f
        set(value) { field = value; dispatch() }

    var style: Style = Style.ANDROID
        set(value) { field = value; dispatch() }

    var isPinned: Boolean = false
        set(value) { field = value; dispatch() }

    var buttonSize: Int = 44
        set(value) { field = value; dispatch() }
    var buttonCornerRadius: Float = 0.5f   // 0 = square, 1 = fully rounded
        set(value) { field = value; dispatch() }
    var buttonGap: Int = 10
        set(value) { field = value; dispatch() }

    var indicatorOpacity: Float = 0.85f
        set(value) { field = value; dispatch() }
    var indicatorHeight: Int = 135
        set(value) { field = value; dispatch() }
    var indicatorWidth: Int = 36
        set(value) { field = value; dispatch() }
    var indicatorGap: Int = 10
        set(value) { field = value; dispatch() }
    var indicatorHideDelay: Int = 1800
        set(value) { field = value; dispatch() }
    var indicatorAnimation: String = "fade"
        set(value) { field = value; dispatch() }
    var useSystemVolume: Boolean = false
        set(value) { field = value; dispatch() }

    /** Stream controlled by the main +/- buttons and the compact indicator. */
    var selectedAudioStream: AudioStream = AudioStream.MEDIA
        set(value) { field = value; dispatch() }
    var showAudioMixer: Boolean = true
        set(value) { field = value; dispatch() }
    var autoPeekEnabled: Boolean = true
        set(value) { field = value; dispatch() }
    var autoPeekDelay: Int = 1800
        set(value) { field = value; dispatch() }
    var peekSize: Int = 16
        set(value) { field = value; dispatch() }

    var creativeAnimSpeed: Float = 1.0f
        set(value) { field = value; dispatch() }

    var creativeGlowIntensity: Float = 1.0f
        set(value) { field = value; dispatch() }

    /** How many volume levels a single +/- tap moves. */
    var volumeStep: Int = 1
        set(value) { field = value; dispatch() }
    /** Vibrate on +/- tap. */
    var hapticFeedback: Boolean = false
        set(value) { field = value; dispatch() }
    /** Show the numeric volume level on the indicator. */
    var showIndicatorNumber: Boolean = true
        set(value) { field = value; dispatch() }
    /** Show the bottom label/icon (VOL / speaker) on the indicator. */
    var showIndicatorIcon: Boolean = true
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
    private const val KEY_AUDIO_STREAM  = "widget_audio_stream"
    private const val KEY_SHOW_MIXER    = "widget_show_mixer"
    private const val KEY_AUTO_PEEK     = "widget_auto_peek"
    private const val KEY_PEEK_DELAY    = "widget_peek_delay"
    private const val KEY_PEEK_SIZE     = "widget_peek_size"
    private const val KEY_CRT_SPEED    = "widget_crt_speed"
    private const val KEY_CRT_GLOW     = "widget_crt_glow"
    private const val KEY_VOL_STEP     = "widget_vol_step"
    private const val KEY_HAPTIC       = "widget_haptic"
    private const val KEY_IND_NUMBER   = "widget_ind_number"
    private const val KEY_IND_ICON     = "widget_ind_icon"

    fun load(prefs: SharedPreferences) {
        colorMode = ColorMode.entries.getOrElse(prefs.getInt(KEY_COLOR_MODE, 0)) { ColorMode.AUTO }
        opacity   = prefs.getFloat(KEY_OPACITY, 0.70f)
        style     = Style.entries.getOrElse(prefs.getInt(KEY_STYLE, 0)) { Style.ANDROID }
        isPinned  = prefs.getBoolean(KEY_PINNED, false)
        buttonSize           = prefs.getInt(KEY_BTN_SIZE, 44)
        buttonCornerRadius   = prefs.getFloat(KEY_BTN_CORNER, 0.5f)
        buttonGap            = prefs.getInt(KEY_BTN_GAP, 10)
        indicatorOpacity     = prefs.getFloat(KEY_IND_OPACITY, 0.85f)
        indicatorHeight      = prefs.getInt(KEY_IND_HEIGHT, 135)
        indicatorWidth       = prefs.getInt(KEY_IND_WIDTH, 36)
        indicatorGap         = prefs.getInt(KEY_IND_GAP, 10)
        indicatorHideDelay   = prefs.getInt(KEY_IND_DELAY, 1800)
        indicatorAnimation   = prefs.getString(KEY_IND_ANIM, "fade") ?: "fade"
        useSystemVolume      = prefs.getBoolean(KEY_USE_SYS_VOL, false)
        selectedAudioStream  = AudioStream.fromName(prefs.getString(KEY_AUDIO_STREAM, AudioStream.MEDIA.name))
        showAudioMixer       = prefs.getBoolean(KEY_SHOW_MIXER, true)
        autoPeekEnabled      = prefs.getBoolean(KEY_AUTO_PEEK, true)
        val storedPeekDelay  = prefs.getInt(KEY_PEEK_DELAY, 1800)
        // Earlier releases used the temporary-panel delay (4–5 s) for the buttons.
        // Migrate those shipped defaults to the compact indicator's 1.8 s behavior.
        autoPeekDelay        = if (storedPeekDelay == 4000 || storedPeekDelay == 5000) 1800
                               else storedPeekDelay.coerceIn(1000, 30000)
        peekSize             = prefs.getInt(KEY_PEEK_SIZE, 16).coerceIn(8, 24)
        creativeAnimSpeed    = prefs.getFloat(KEY_CRT_SPEED, 1.0f)
        creativeGlowIntensity= prefs.getFloat(KEY_CRT_GLOW, 1.0f)
        volumeStep           = prefs.getInt(KEY_VOL_STEP, 1)
        hapticFeedback       = prefs.getBoolean(KEY_HAPTIC, false)
        showIndicatorNumber  = prefs.getBoolean(KEY_IND_NUMBER, true)
        showIndicatorIcon    = prefs.getBoolean(KEY_IND_ICON, true)
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
            .putString(KEY_AUDIO_STREAM, selectedAudioStream.name)
            .putBoolean(KEY_SHOW_MIXER, showAudioMixer)
            .putBoolean(KEY_AUTO_PEEK, autoPeekEnabled)
            .putInt(KEY_PEEK_DELAY, autoPeekDelay)
            .putInt(KEY_PEEK_SIZE, peekSize)
            .putFloat(KEY_CRT_SPEED, creativeAnimSpeed)
            .putFloat(KEY_CRT_GLOW, creativeGlowIntensity)
            .putInt(KEY_VOL_STEP, volumeStep)
            .putBoolean(KEY_HAPTIC, hapticFeedback)
            .putBoolean(KEY_IND_NUMBER, showIndicatorNumber)
            .putBoolean(KEY_IND_ICON, showIndicatorIcon)
            .apply()
    }
}
