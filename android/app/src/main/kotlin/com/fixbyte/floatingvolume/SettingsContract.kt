package com.fixbyte.floatingvolume

/** Pure persistence/channel contract, shared by startup migration and writes. */
object SettingsContract {
    data class Spec(val name: String, val key: String, val default: Any,
                    val min: Double? = null, val max: Double? = null)

    // Stored ordinals belong to the Kotlin enum, never to Dart's enum.
    private val storedStyles = listOf("android", "android12", "ios", "miui", "samsungOneUi",
        "rgbAurora", "rgbNeon", "cosmic", "lava", "cards", "glacier", "matrix", "retrowave")
    private val styles = storedStyles.filter { it != "cards" }
    private val colors = listOf("auto", "blue", "dark")
    private val streams = listOf("MEDIA", "RING", "NOTIFICATION", "ALARM", "SYSTEM", "VOICE_CALL")
    fun styleName(ordinal: Int): String = storedStyles.getOrElse(ordinal) { "android" }
    val specs = listOf(
        Spec("colorMode", "widget_color_mode", "auto"),
        Spec("opacity", "widget_opacity", 0.70, 0.0, 1.0),
        Spec("style", "widget_style", "android"),
        Spec("isPinned", "widget_pinned", false),
        Spec("buttonSize", "widget_btn_size", 44, 36.0, 72.0),
        Spec("buttonCornerRadius", "widget_btn_corner", 0.5, 0.0, 0.5),
        Spec("buttonGap", "widget_btn_gap", 10, 0.0, 40.0),
        Spec("indicatorOpacity", "widget_ind_opacity", 0.85, 0.2, 1.0),
        Spec("indicatorHeight", "widget_ind_height", 135, 100.0, 300.0),
        Spec("indicatorWidth", "widget_ind_width", 36, 24.0, 100.0),
        Spec("indicatorGap", "widget_ind_gap", 10, 0.0, 50.0),
        Spec("indicatorHideDelay", "widget_ind_delay", 1800, 500.0, 4000.0),
        Spec("indicatorAnimation", "widget_ind_anim", "fade"),
        Spec("useSystemVolume", "widget_use_sys_vol", false),
        Spec("selectedAudioStream", "widget_audio_stream", "MEDIA"),
        Spec("showAudioMixer", "widget_show_mixer", true),
        Spec("autoPeekEnabled", "widget_auto_peek", true),
        Spec("autoPeekDelay", "widget_peek_delay", 1800, 1000.0, 30000.0),
        Spec("peekSize", "widget_peek_size", 20, 16.0, 28.0),
        Spec("creativeAnimSpeed", "widget_crt_speed", 1.0, 0.5, 2.0),
        Spec("creativeGlowIntensity", "widget_crt_glow", 1.0, 0.2, 3.0),
        Spec("volumeStep", "widget_vol_step", 1, 1.0, 5.0),
        Spec("hapticFeedback", "widget_haptic", false),
        Spec("showIndicatorNumber", "widget_ind_number", true),
        Spec("showIndicatorIcon", "widget_ind_icon", true),
    )

    fun defaultCorner(style: String): Double = when (style) {
        "miui" -> 0.2
        "samsungOneUi" -> 0.3
        else -> 0.5
    }

    fun normalize(values: Map<String, Any?>): Map<String, Any> = specs.associate { spec ->
        val raw = values[spec.name]
        val value: Any = when (spec.name) {
            "style" -> (if (raw is Number) storedStyles.getOrNull(raw.toInt()) else raw as? String)
                ?.takeIf { it in styles } ?: "android"
            "colorMode" -> (if (raw is Number) colors.getOrNull(raw.toInt()) else raw as? String)
                ?.takeIf { it in colors } ?: "auto"
            "selectedAudioStream" -> (raw as? String)?.uppercase()?.takeIf { it in streams } ?: "MEDIA"
            "indicatorAnimation" -> (raw as? String)?.takeIf { it.isNotBlank() } ?: "fade"
            else -> when (spec.default) {
                is Boolean -> raw as? Boolean ?: spec.default
                is Number -> {
                    val number = (raw as? Number)?.toDouble() ?: (raw as? String)
                        ?.removePrefix("VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu")?.toDoubleOrNull()
                    val bounded = (number?.takeIf { it.isFinite() } ?: (spec.default as Number).toDouble())
                        .coerceIn(spec.min!!, spec.max!!)
                    if (spec.default is Int) bounded.toInt() else bounded
                }
                else -> spec.default
            }
        }
        spec.name to value
    }

    fun persisted(native: Map<String, *>, legacy: Map<String, *>): Map<String, Any> {
        val values = specs.associate { spec ->
            spec.name to if (native.containsKey(spec.key)) native[spec.key] else legacy["flutter.${spec.key}"]
        }.toMutableMap()
        val normalized = normalize(values)
        val style = normalized.getValue("style") as String
        val ordinal = storedStyles.indexOf(style)
        val suffix = listOf("ANDROID", "ANDROID_12", "IOS", "MIUI", "SAMSUNG_ONE_UI", "RGB_AURORA",
            "RGB_NEON", "COSMIC", "LAVA", "CARDS", "GLACIER", "MATRIX", "RETROWAVE")[ordinal]
        val cornerKey = "widget_btn_corner_$suffix"
        values["buttonCornerRadius"] = when {
            native.containsKey(cornerKey) -> native[cornerKey]
            values["buttonCornerRadius"] != null -> values["buttonCornerRadius"]
            else -> defaultCorner(style)
        }
        return normalize(values)
    }

    fun defaults(section: String, style: String): Map<String, Any> {
        val names = when (section) {
            "buttons" -> listOf("opacity", "buttonSize", "buttonCornerRadius", "buttonGap", "volumeStep",
                "hapticFeedback", "autoPeekEnabled", "autoPeekDelay", "peekSize")
            "audio" -> listOf("selectedAudioStream", "showAudioMixer")
            "indicator" -> listOf("showIndicatorNumber", "showIndicatorIcon", "indicatorOpacity",
                "indicatorHeight", "indicatorWidth", "indicatorGap", "indicatorHideDelay", "indicatorAnimation")
            "creative" -> listOf("creativeAnimSpeed", "creativeGlowIntensity")
            "all" -> return listOf("buttons", "audio", "indicator", "creative")
                .flatMap { defaults(it, style).entries }.associate { it.toPair() }
            else -> throw IllegalArgumentException("Unknown settings section")
        }
        return specs.filter { it.name in names }.associate {
            it.name to if (it.name == "buttonCornerRadius") defaultCorner(style) else it.default
        }
    }
}
