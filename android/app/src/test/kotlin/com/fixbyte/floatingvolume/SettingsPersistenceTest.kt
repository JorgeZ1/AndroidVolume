package com.fixbyte.floatingvolume

import android.content.SharedPreferences
import java.lang.reflect.Proxy
import org.junit.Assert.*
import org.junit.Test

class SettingsPersistenceTest {
    private fun prefs(values: MutableMap<String, Any>): SharedPreferences {
        return Proxy.newProxyInstance(SharedPreferences::class.java.classLoader,
            arrayOf(SharedPreferences::class.java)) { _, method, args ->
            val key = args?.getOrNull(0) as? String
            when (method.name) {
                "getAll" -> HashMap(values)
                "contains" -> values.containsKey(key)
                "getInt", "getLong", "getFloat", "getBoolean", "getString", "getStringSet" -> values[key] ?: args!![1]
                "edit" -> {
                    val pending = mutableMapOf<String, Any>()
                    lateinit var editor: SharedPreferences.Editor
                    editor = Proxy.newProxyInstance(SharedPreferences.Editor::class.java.classLoader,
                        arrayOf(SharedPreferences.Editor::class.java)) { _, editMethod, editArgs ->
                        when (editMethod.name) {
                            "apply", "commit" -> { values.putAll(pending); pending.clear(); if (editMethod.name == "commit") true else null }
                            else -> { pending[editArgs!![0] as String] = editArgs[1]; editor }
                        }
                    } as SharedPreferences.Editor
                    editor
                }
                else -> null
            }
        } as SharedPreferences
    }

    @Test fun upgradesPreserveNativeValuesAndReadDoesNotWriteOrNotify() {
        val native = mutableMapOf<String, Any>("widget_vol_step" to 3, "widget_btn_size" to 64,
            "widget_audio_stream" to "ALARM", "widget_peek_delay" to 5000,
            "widget_auto_peek" to false, "widget_ind_number" to false)
        val legacy = mutableMapOf<String, Any>("flutter.widget_vol_step" to 1,
            "flutter.widget_audio_stream" to "MEDIA", "flutter.widget_auto_peek" to true)
        val saved = prefs(native)
        repeat(4) {
            WidgetSettings.load(saved, prefs(legacy))
            assertEquals(3, WidgetSettings.volumeStep)
            assertEquals(64, WidgetSettings.buttonSize)
            assertEquals(AudioStream.ALARM, WidgetSettings.selectedAudioStream)
            assertEquals(5000, WidgetSettings.autoPeekDelay)
            assertFalse(WidgetSettings.autoPeekEnabled)
            assertFalse(WidgetSettings.showIndicatorNumber)
        }
        val before = HashMap(native)
        var notifications = 0
        val listener = { notifications++; Unit }
        WidgetSettings.addListener(listener)
        try { repeat(3) { WidgetSettings.snapshot() } } finally { WidgetSettings.removeListener(listener) }
        assertEquals(before, native)
        assertEquals(0, notifications)
    }

    @Test fun missingNativeKeysImportLegacyOnceIncludingEncodedDoubles() {
        val native = mutableMapOf<String, Any>()
        val legacy = mutableMapOf<String, Any>("flutter.widget_vol_step" to 4L,
            "flutter.widget_style" to "miui", "flutter.widget_peek_delay" to 12000L,
            "flutter.widget_crt_speed" to "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu1.5")
        WidgetSettings.load(prefs(native), prefs(legacy))
        assertEquals(4, WidgetSettings.volumeStep)
        assertEquals(1.5f, WidgetSettings.creativeAnimSpeed, 0.001f)
        assertEquals(0.2f, WidgetSettings.buttonCornerRadius, 0.001f)
        assertEquals(12000, WidgetSettings.autoPeekDelay)
        legacy["flutter.widget_vol_step"] = 5L
        WidgetSettings.load(prefs(native), prefs(legacy))
        assertEquals(4, WidgetSettings.volumeStep)
    }

    @Test fun sectionResetIsAtomicAndSurvivesStaleFlutterCopy() {
        val native = mutableMapOf<String, Any>()
        val saved = prefs(native)
        WidgetSettings.load(saved)
        WidgetSettings.update(mapOf("autoPeekEnabled" to false, "volumeStep" to 5,
            "selectedAudioStream" to "ALARM", "indicatorWidth" to 62), saved)
        val observed = mutableListOf<Map<String, Any>>()
        val listener = { observed.add(WidgetSettings.snapshot()); Unit }
        WidgetSettings.addListener(listener)
        try { WidgetSettings.restore("buttons", saved) } finally { WidgetSettings.removeListener(listener) }
        assertEquals(1, observed.size)
        assertEquals(true, observed.single()["autoPeekEnabled"])
        assertEquals(1, observed.single()["volumeStep"])
        WidgetSettings.load(saved, prefs(mutableMapOf("flutter.widget_auto_peek" to false)))
        assertTrue(WidgetSettings.autoPeekEnabled)
        assertEquals(AudioStream.ALARM, WidgetSettings.selectedAudioStream)
        assertEquals(62, WidgetSettings.indicatorWidth)
    }

    @Test fun normalizationPreventsInvalidStepsAndPreservesStyleCorners() {
        val native = mutableMapOf<String, Any>("widget_vol_step" to 50,
            "widget_btn_corner_MIUI" to 0.42f, "widget_btn_corner_SAMSUNG_ONE_UI" to 0.5f)
        val saved = prefs(native)
        WidgetSettings.load(saved)
        assertEquals(5, WidgetSettings.volumeStep)
        WidgetSettings.update(mapOf("volumeStep" to -3, "style" to "miui"), saved)
        assertEquals(1, WidgetSettings.volumeStep)
        assertEquals(0.42f, WidgetSettings.buttonCornerRadius, 0.001f)
        WidgetSettings.update(mapOf("style" to "samsungOneUi"), saved)
        assertEquals(0.5f, WidgetSettings.buttonCornerRadius, 0.001f)
        WidgetSettings.update(mapOf("style" to "miui"), saved)
        assertEquals(0.42f, WidgetSettings.buttonCornerRadius, 0.001f)
    }

    @Test fun enumOrdinalsAreDecodedUsingKotlinOrderAndEmptyPrefsUseDefaults() {
        val native = mutableMapOf<String, Any>("widget_style" to 10)
        WidgetSettings.load(prefs(native))
        assertEquals(WidgetSettings.Style.GLACIER, WidgetSettings.style)
        assertEquals("glacier", WidgetSettings.snapshot()["style"])
        WidgetSettings.load(prefs(mutableMapOf()))
        assertEquals(1, WidgetSettings.volumeStep)
        assertEquals(1800, WidgetSettings.autoPeekDelay)
    }
}
