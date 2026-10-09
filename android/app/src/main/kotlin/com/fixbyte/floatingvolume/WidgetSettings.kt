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
        set(value) { if (field != value) { field = value; dispatch() } }

    var opacity: Float = 0.70f
        set(value) { if (field != value) { field = value; dispatch() } }

    var style: Style = Style.ANDROID
        set(value) { if (field != value) { field = value; dispatch() } }

    var isPinned: Boolean = false
        set(value) { if (field != value) { field = value; dispatch() } }

    var buttonSize: Int = 44
        set(value) { if (field != value) { field = value; dispatch() } }
    var buttonCornerRadius: Float = 0.5f   // 0 = square, 0.5 = fully rounded
        set(value) { if (field != value) { field = value; dispatch() } }
    var buttonGap: Int = 10
        set(value) { if (field != value) { field = value; dispatch() } }

    var indicatorOpacity: Float = 0.85f
        set(value) { if (field != value) { field = value; dispatch() } }
    var indicatorHeight: Int = 135
        set(value) { if (field != value) { field = value; dispatch() } }
    var indicatorWidth: Int = 36
        set(value) { if (field != value) { field = value; dispatch() } }
    var indicatorGap: Int = 10
        set(value) { if (field != value) { field = value; dispatch() } }
    var indicatorHideDelay: Int = 1800
        set(value) { if (field != value) { field = value; dispatch() } }
    var indicatorAnimation: String = "fade"
        set(value) { if (field != value) { field = value; dispatch() } }
    var useSystemVolume: Boolean = false
        set(value) { if (field != value) { field = value; dispatch() } }

    /** Stream controlled by the main +/- buttons and the compact indicator. */
    var selectedAudioStream: AudioStream = AudioStream.MEDIA
        set(value) { if (field != value) { field = value; dispatch() } }
    var showAudioMixer: Boolean = true
        set(value) { if (field != value) { field = value; dispatch() } }
    var autoPeekEnabled: Boolean = true
        set(value) { if (field != value) { field = value; dispatch() } }
    var autoPeekDelay: Int = 1800
        set(value) { if (field != value) { field = value; dispatch() } }
    var peekSize: Int = 20
        set(value) { if (field != value) { field = value; dispatch() } }

    var creativeAnimSpeed: Float = 1.0f
        set(value) { if (field != value) { field = value; dispatch() } }

    var creativeGlowIntensity: Float = 1.0f
        set(value) { if (field != value) { field = value; dispatch() } }

    /** How many volume levels a single +/- tap moves. */
    var volumeStep: Int = 1
        set(value) { if (field != value) { field = value; dispatch() } }
    /** Vibrate on +/- tap. */
    var hapticFeedback: Boolean = false
        set(value) { if (field != value) { field = value; dispatch() } }
    /** Show the numeric volume level on the indicator. */
    var showIndicatorNumber: Boolean = true
        set(value) { if (field != value) { field = value; dispatch() } }
    /** Show the bottom label/icon (VOL / speaker) on the indicator. */
    var showIndicatorIcon: Boolean = true
        set(value) { if (field != value) { field = value; dispatch() } }

    private val listeners = mutableListOf<() -> Unit>()
    private var batchDepth = 0
    private var pendingDispatch = false
    private var revision = 0L

    fun addListener(l: () -> Unit)    { listeners.add(l) }
    fun removeListener(l: () -> Unit) { listeners.remove(l) }
    private fun dispatch() {
        if (batchDepth > 0) { pendingDispatch = true; return }
        revision++
        listeners.toList().forEach { it() }
    }

    private fun batch(block: () -> Unit) {
        batchDepth++
        try { block() } finally {
            batchDepth--
            if (batchDepth == 0 && pendingDispatch) {
                pendingDispatch = false
                dispatch()
            }
        }
    }

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

    private fun cornerKey(style: Style) = "${KEY_BTN_CORNER}_${style.name}"

    fun defaultCornerRadius(style: Style): Float = when (style) {
        Style.MIUI -> 0.2f
        Style.SAMSUNG_ONE_UI -> 0.3f
        Style.CARDS -> 0.25f
        else -> 0.5f
    }

    fun selectStyle(newStyle: Style, prefs: SharedPreferences) {
        buttonCornerRadius = prefs.getFloat(cornerKey(newStyle), defaultCornerRadius(newStyle))
            .coerceIn(0f, 0.5f)
        style = newStyle
    }

    fun load(prefs: SharedPreferences, legacy: SharedPreferences? = null) {
        val values = SettingsContract.persisted(prefs.all, legacy?.all ?: emptyMap<String, Any>())
        batch {
            applySnapshot(values)
            if ((prefs.all["widget_settings_schema"] as? Number)?.toInt()?.let { it >= 1 } != true) {
                save(prefs)
                prefs.edit().putInt("widget_settings_schema", 1).apply()
            }
        }
    }

    /** Read-only: no preference writes, reloads, or overlay notifications. */
    fun snapshot(): Map<String, Any> = mapOf(
        "colorMode" to colorMode.name.lowercase(), "opacity" to opacity.toDouble(),
        "style" to SettingsContract.styleName(style.ordinal), "isPinned" to isPinned,
        "buttonSize" to buttonSize, "buttonCornerRadius" to buttonCornerRadius.toDouble(),
        "buttonGap" to buttonGap, "indicatorOpacity" to indicatorOpacity.toDouble(),
        "indicatorHeight" to indicatorHeight, "indicatorWidth" to indicatorWidth,
        "indicatorGap" to indicatorGap, "indicatorHideDelay" to indicatorHideDelay,
        "indicatorAnimation" to indicatorAnimation, "useSystemVolume" to useSystemVolume,
        "selectedAudioStream" to selectedAudioStream.name, "showAudioMixer" to showAudioMixer,
        "autoPeekEnabled" to autoPeekEnabled, "autoPeekDelay" to autoPeekDelay,
        "peekSize" to peekSize, "creativeAnimSpeed" to creativeAnimSpeed.toDouble(),
        "creativeGlowIntensity" to creativeGlowIntensity.toDouble(), "volumeStep" to volumeStep,
        "hapticFeedback" to hapticFeedback, "showIndicatorNumber" to showIndicatorNumber,
        "showIndicatorIcon" to showIndicatorIcon, "revision" to revision,
    )

    fun update(changes: Map<String, Any?>, prefs: SharedPreferences): Map<String, Any> {
        require(changes.keys.all { key -> SettingsContract.specs.any { it.name == key } })
        batch {
            val merged = (snapshot() + changes).toMutableMap()
            if (changes.containsKey("style") && !changes.containsKey("buttonCornerRadius")) {
                val nextStyle = Style.fromName(SettingsContract.normalize(merged)["style"] as String)
                merged["buttonCornerRadius"] = (prefs.all[cornerKey(nextStyle)] as? Number)?.toDouble()
                    ?: defaultCornerRadius(nextStyle).toDouble()
            }
            applySnapshot(SettingsContract.normalize(merged))
            save(prefs)
        }
        return snapshot()
    }

    fun restore(section: String, prefs: SharedPreferences): Map<String, Any> =
        update(SettingsContract.defaults(section, SettingsContract.styleName(style.ordinal)), prefs)

    private fun applySnapshot(values: Map<String, Any>) {
        colorMode = ColorMode.valueOf((values.getValue("colorMode") as String).uppercase())
        opacity = (values.getValue("opacity") as Number).toFloat()
        style = Style.fromName(values.getValue("style") as String)
        isPinned = values.getValue("isPinned") as Boolean
        buttonSize = (values.getValue("buttonSize") as Number).toInt()
        buttonCornerRadius = (values.getValue("buttonCornerRadius") as Number).toFloat()
        buttonGap = (values.getValue("buttonGap") as Number).toInt()
        indicatorOpacity = (values.getValue("indicatorOpacity") as Number).toFloat()
        indicatorHeight = (values.getValue("indicatorHeight") as Number).toInt()
        indicatorWidth = (values.getValue("indicatorWidth") as Number).toInt()
        indicatorGap = (values.getValue("indicatorGap") as Number).toInt()
        indicatorHideDelay = (values.getValue("indicatorHideDelay") as Number).toInt()
        indicatorAnimation = values.getValue("indicatorAnimation") as String
        useSystemVolume = values.getValue("useSystemVolume") as Boolean
        selectedAudioStream = AudioStream.fromName(values.getValue("selectedAudioStream") as String)
        showAudioMixer = values.getValue("showAudioMixer") as Boolean
        autoPeekEnabled = values.getValue("autoPeekEnabled") as Boolean
        autoPeekDelay = (values.getValue("autoPeekDelay") as Number).toInt()
        peekSize = (values.getValue("peekSize") as Number).toInt()
        creativeAnimSpeed = (values.getValue("creativeAnimSpeed") as Number).toFloat()
        creativeGlowIntensity = (values.getValue("creativeGlowIntensity") as Number).toFloat()
        volumeStep = (values.getValue("volumeStep") as Number).toInt()
        hapticFeedback = values.getValue("hapticFeedback") as Boolean
        showIndicatorNumber = values.getValue("showIndicatorNumber") as Boolean
        showIndicatorIcon = values.getValue("showIndicatorIcon") as Boolean
    }

    fun save(prefs: SharedPreferences) {
        prefs.edit()
            .putInt(KEY_COLOR_MODE,  colorMode.ordinal)
            .putFloat(KEY_OPACITY,   opacity)
            .putInt(KEY_STYLE,       style.ordinal)
            .putBoolean(KEY_PINNED,  isPinned)
            .putInt(KEY_BTN_SIZE,    buttonSize)
            .putFloat(KEY_BTN_CORNER, buttonCornerRadius)
            .putFloat(cornerKey(style), buttonCornerRadius)
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
