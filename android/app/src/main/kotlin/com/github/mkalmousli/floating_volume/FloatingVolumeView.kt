package com.github.mkalmousli.floating_volume

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView

class FloatingVolumeView(context: Context) : LinearLayout(context) {

    private fun dp(v: Number) = (v.toFloat() * resources.displayMetrics.density).toInt()

    private val plusBg  = GradientDrawable().apply { shape = GradientDrawable.OVAL }
    private val minusBg = GradientDrawable().apply { shape = GradientDrawable.OVAL }

    private val plusLabel  = buildLabel("+")
    private val minusLabel = buildLabel("−")

    private val plusBtn  = buildCircle(plusBg,  plusLabel)
    private val minusBtn = buildCircle(minusBg, minusLabel)

    val handleIv: View get() = this

    init {
        orientation = VERTICAL
        gravity     = Gravity.CENTER_HORIZONTAL
        setBackgroundColor(Color.TRANSPARENT)

        val size = dp(52)   // smaller than before (was 64)
        val gap  = dp(10)

        addView(plusBtn,  LayoutParams(size, size))
        addView(View(context).apply { setBackgroundColor(Color.TRANSPARENT) }, LayoutParams(size, gap))
        addView(minusBtn, LayoutParams(size, size))

        applyTheme()
    }

    // ── Theme ─────────────────────────────────────────────────────────────────

    private fun isSystemNight() =
        resources.configuration.uiMode and
        Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES

    fun applyTheme() {
        val (circleBg, iconColor) = when (WidgetSettings.colorMode) {
            WidgetSettings.ColorMode.BLUE -> Color.parseColor("#2979FF") to Color.WHITE
            WidgetSettings.ColorMode.DARK -> Color.parseColor("#1C1C1E") to Color.WHITE
            WidgetSettings.ColorMode.AUTO -> if (isSystemNight())
                Color.parseColor("#2C2C2E") to Color.WHITE
            else
                Color.WHITE to Color.parseColor("#2979FF")
        }

        listOf(plusBg, minusBg).forEach { it.setColor(circleBg) }
        listOf(plusLabel, minusLabel).forEach { it.setTextColor(iconColor) }

        val elev = dp(if (isSystemNight() || WidgetSettings.colorMode == WidgetSettings.ColorMode.DARK) 3 else 5)
        listOf(plusBtn, minusBtn).forEach { it.elevation = elev.toFloat() }

        alpha = WidgetSettings.opacity
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (WidgetSettings.colorMode == WidgetSettings.ColorMode.AUTO) applyTheme()
    }

    // ── Flash animation ───────────────────────────────────────────────────────

    fun flashButton(isPlus: Boolean) {
        val target = if (isPlus) plusBtn else minusBtn
        AnimatorSet().apply {
            playSequentially(
                ObjectAnimator.ofFloat(target, "scaleX", 1f, 0.82f).setDuration(70),
                ObjectAnimator.ofFloat(target, "scaleX", 0.82f, 1f).setDuration(110),
            )
            start()
        }
        AnimatorSet().apply {
            playSequentially(
                ObjectAnimator.ofFloat(target, "scaleY", 1f, 0.82f).setDuration(70),
                ObjectAnimator.ofFloat(target, "scaleY", 0.82f, 1f).setDuration(110),
            )
            start()
        }
    }

    // ── Builders ──────────────────────────────────────────────────────────────

    private fun buildLabel(sym: String) = TextView(context).apply {
        text        = sym
        textSize    = 24f
        typeface    = Typeface.DEFAULT_BOLD
        gravity     = Gravity.CENTER
        layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
    }

    private fun buildCircle(bg: GradientDrawable, label: TextView) =
        LinearLayout(context).apply {
            gravity    = Gravity.CENTER
            background = bg
            elevation  = dp(5).toFloat()
            addView(label)
        }
}
