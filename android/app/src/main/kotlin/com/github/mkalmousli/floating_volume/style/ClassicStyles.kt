package com.github.mkalmousli.floating_volume.style

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.widget.TextView
import com.github.mkalmousli.floating_volume.WidgetSettings

// ── Helpers ──────────────────────────────────────────────────────────────────

private fun ovalDrawable(color: Int) =
    GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(color) }

private fun roundRectDrawable(color: Int, cornerDp: Float, borderColor: Int = Color.TRANSPARENT, borderWidthPx: Int = 0) =
    GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        cornerRadius = cornerDp
        setColor(color)
        if (borderWidthPx > 0) setStroke(borderWidthPx, borderColor)
    }

private fun applyToButtons(
    plusBtn: View, minusBtn: View,
    plusLabel: TextView, minusLabel: TextView,
    bgDrawable: () -> GradientDrawable,
    iconColor: Int,
    elevPx: Int,
) {
    plusBtn.background  = bgDrawable()
    minusBtn.background = bgDrawable()
    plusBtn.elevation   = elevPx.toFloat()
    minusBtn.elevation  = elevPx.toFloat()
    plusLabel.setTextColor(iconColor)
    minusLabel.setTextColor(iconColor)
}

// ── Android (Standard) ───────────────────────────────────────────────────────

class AndroidStyleApplier(
    private val isNight: Boolean,
    private val colorMode: WidgetSettings.ColorMode,
) : ButtonStyleApplier {

    override fun apply(
        plusBtn: View, minusBtn: View,
        plusLabel: TextView, minusLabel: TextView,
        dp: (Number) -> Int,
    ) {
        val (circleBg, iconColor) = when (colorMode) {
            WidgetSettings.ColorMode.BLUE -> Color.parseColor("#2979FF") to Color.WHITE
            WidgetSettings.ColorMode.DARK -> Color.parseColor("#1C1C1E") to Color.WHITE
            WidgetSettings.ColorMode.AUTO ->
                if (isNight) Color.parseColor("#2C2C2E") to Color.WHITE
                else         Color.WHITE to Color.parseColor("#2979FF")
        }
        val elev = dp(if (isNight || colorMode == WidgetSettings.ColorMode.DARK) 3 else 5)
        applyToButtons(plusBtn, minusBtn, plusLabel, minusLabel,
            { ovalDrawable(circleBg) }, iconColor, elev)
    }
}

// ── Android 12 (Modern) ──────────────────────────────────────────────────────

class Android12StyleApplier : ButtonStyleApplier {

    override fun apply(
        plusBtn: View, minusBtn: View,
        plusLabel: TextView, minusLabel: TextView,
        dp: (Number) -> Int,
    ) {
        applyToButtons(plusBtn, minusBtn, plusLabel, minusLabel,
            { ovalDrawable(Color.parseColor("#2979FF")) }, Color.WHITE, dp(3))
    }
}

// ── iOS ──────────────────────────────────────────────────────────────────────

class IosStyleApplier : ButtonStyleApplier {

    override fun apply(
        plusBtn: View, minusBtn: View,
        plusLabel: TextView, minusLabel: TextView,
        dp: (Number) -> Int,
    ) {
        // Translucent frosted-glass look: white with low alpha + white border
        val glassBg = Color.argb(50, 255, 255, 255)
        val border  = Color.argb(80, 255, 255, 255)
        applyToButtons(plusBtn, minusBtn, plusLabel, minusLabel,
            { ovalDrawable(glassBg).also { it.setStroke(dp(1), border) } },
            Color.WHITE, dp(4))
    }
}

// ── MIUI (Xiaomi) ────────────────────────────────────────────────────────────

class MiuiStyleApplier : ButtonStyleApplier {

    override fun apply(
        plusBtn: View, minusBtn: View,
        plusLabel: TextView, minusLabel: TextView,
        dp: (Number) -> Int,
    ) {
        val orange    = Color.parseColor("#FF6900")
        val bgColor   = Color.argb(30, 255, 255, 255)
        val borderPx  = dp(2)
        val corner    = dp(14).toFloat()
        applyToButtons(plusBtn, minusBtn, plusLabel, minusLabel,
            { roundRectDrawable(bgColor, corner, orange, borderPx) },
            orange, dp(2))
    }
}

// ── Samsung One UI ───────────────────────────────────────────────────────────

class OneUiStyleApplier : ButtonStyleApplier {

    override fun apply(
        plusBtn: View, minusBtn: View,
        plusLabel: TextView, minusLabel: TextView,
        dp: (Number) -> Int,
    ) {
        val teal    = Color.parseColor("#1DB3A8")
        val bgColor = Color.argb(40, 29, 179, 168)   // teal with low alpha
        val corner  = dp(12).toFloat()
        applyToButtons(plusBtn, minusBtn, plusLabel, minusLabel,
            { roundRectDrawable(bgColor, corner) },
            teal, dp(3))
    }
}
