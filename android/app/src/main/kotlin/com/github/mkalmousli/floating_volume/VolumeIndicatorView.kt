package com.github.mkalmousli.floating_volume

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

/**
 * A small floating volume indicator that appears beside the main widget.
 * Shows a vertical fill bar + current volume number + stream icon.
 */
class VolumeIndicatorView(context: Context) : LinearLayout(context) {

    private fun dp(v: Number) = (v.toFloat() * resources.displayMetrics.density).toInt()

    // ── Drawables ────────────────────────────────────────────────────────────

    private val cardBg = GradientDrawable().apply {
        shape  = GradientDrawable.RECTANGLE
        cornerRadius = dp(20).toFloat()
    }

    private val trackBg = GradientDrawable().apply {
        shape  = GradientDrawable.RECTANGLE
        cornerRadius = dp(3).toFloat()
    }

    private val fillBg = GradientDrawable().apply {
        shape  = GradientDrawable.RECTANGLE
        cornerRadius = dp(3).toFloat()
    }

    // ── Child views ───────────────────────────────────────────────────────────

    private val numberLabel = TextView(context).apply {
        textSize = 13f
        typeface = Typeface.DEFAULT_BOLD
        gravity  = Gravity.CENTER
    }

    /** Invisible spacer track; fill is overlaid on top */
    private val trackView = android.view.View(context).apply {
        background = trackBg
    }

    private val fillView = android.view.View(context)

    private val iconLabel = TextView(context).apply {
        text     = "♪"
        textSize = 14f
        gravity  = Gravity.CENTER
    }

    // ── State ─────────────────────────────────────────────────────────────────

    private var currentFraction = 0f   // 0..1

    init {
        orientation = VERTICAL
        gravity     = Gravity.CENTER_HORIZONTAL
        background  = cardBg
        setPadding(dp(8), dp(10), dp(8), dp(10))

        val w = dp(44)

        addView(numberLabel, LayoutParams(w, LayoutParams.WRAP_CONTENT))
        addView(android.view.View(context), LayoutParams(w, dp(6))) // spacer

        // Track + fill stacked in a FrameLayout
        val trackFrame = FrameLayout(context)
        val trackW = dp(4)  // thinner track
        val trackH = dp(80)

        trackView.background = trackBg
        trackFrame.addView(trackView, FrameLayout.LayoutParams(trackW, trackH).also {
            it.gravity = Gravity.CENTER_HORIZONTAL
        })

        fillView.background = fillBg
        trackFrame.addView(fillView, FrameLayout.LayoutParams(trackW, 0).also {
            it.gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
        })

        addView(trackFrame, LayoutParams(w, trackH))

        addView(android.view.View(context), LayoutParams(w, dp(6))) // spacer
        addView(iconLabel, LayoutParams(w, LayoutParams.WRAP_CONTENT))

        applyTheme()
    }

    // ── Public API ────────────────────────────────────────────────────────────

    fun update(volume: Int, maxVolume: Int) {
        currentFraction = if (maxVolume > 0) volume / maxVolume.toFloat() else 0f
        numberLabel.text = volume.toString()

        // Update fill height inside its FrameLayout parent
        val lp = fillView.layoutParams as FrameLayout.LayoutParams
        lp.height = (dp(80) * currentFraction).toInt().coerceAtLeast(dp(2))
        fillView.layoutParams = lp
        fillView.requestLayout()
    }

    fun applyTheme() {
        val isDark = resources.configuration.uiMode and
                Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES

        val cardColor  = if (isDark) Color.parseColor("#1C1C1E") else Color.WHITE
        val trackColor = if (isDark) Color.parseColor("#3A3A3C") else Color.parseColor("#E0E0E0")
        val fillColor  = Color.parseColor("#2979FF")
        val textColor  = if (isDark) Color.WHITE else Color.parseColor("#2979FF")
        val iconAlpha  = if (isDark) 180 else 160

        cardBg.setColor(cardColor)
        trackBg.setColor(trackColor)
        fillBg.setColor(fillColor)
        numberLabel.setTextColor(textColor)
        iconLabel.setTextColor(applyAlpha(textColor, iconAlpha))

        // Subtle elevation shadow via outline provider is not needed — card bg is enough
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        applyTheme()
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun applyAlpha(color: Int, alpha: Int): Int {
        return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
    }
}
