package com.fixbyte.floatingvolume

import android.content.Context

object NativeLanguage {
    fun isSpanish(context: Context): Boolean {
        val preference = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        ).getString("flutter.app_language", "system")
        return when (preference) {
            "spanish" -> true
            "english" -> false
            else -> context.resources.configuration.locales[0].language == "es"
        }
    }

    fun text(context: Context, english: String, spanish: String): String =
        if (isSpanish(context)) spanish else english
}
