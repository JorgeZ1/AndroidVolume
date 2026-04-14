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
import com.github.mkalmousli.floating_volume.style.ButtonStyleApplier
import com.github.mkalmousli.floating_volume.style.StyleFactory

class FloatingVolumeView(context: Context) : LinearLayout(context) {

    private fun dp(v: Number) = (v.toFloat() * resources.displayMetrics.density).toInt()

    private val plusLabel  = buildLabel("+")
    private val minusLabel = buildLabel("−")

    private val plusBtn  = buildButton(plusLabel)
    private val minusBtn = buildButton(minusLabel)

    val handleIv: View get() = this

    private var currentApplier: ButtonStyleApplier? = null

    init {
        orientation = VERTICAL
        gravity     = Gravity.CENTER_HORIZONTAL
        setBackgroundColor(Color.TRANSPARENT)

        val size = dp(52)
        val gap  = dp(10)

        addView(plusBtn,  LayoutParams(size, size))
        addView(View(context).apply { setBackgroundColor(Color.TRANSPARENT) }, LayoutParams(size, gap))
        addView(minusBtn, LayoutParams(size, size))

        applyTheme()
    }

    // ── Theme / Style ─────────────────────────────────────────────────────────

    private fun isSystemNight() =
        resources.configuration.uiMode and
        Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES

    fun applyTheme() {
        currentApplier?.stopAnimation()

        val applier = StyleFactory.create(
            style     = WidgetSettings.style,
            isNight   = isSystemNight(),
            colorMode = WidgetSettings.colorMode,
        )
        applier.apply(plusBtn, minusBtn, plusLabel, minusLabel, ::dp)
        applier.startAnimation()
        currentApplier = applier

        alpha = WidgetSettings.opacity
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (WidgetSettings.colorMode == WidgetSettings.ColorMode.AUTO) applyTheme()
    }

    // ── Flash animation on button press ───────────────────────────────────────

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
        text         = sym
        textSize     = 24f
        typeface     = Typeface.DEFAULT_BOLD
        gravity      = Gravity.CENTER
        layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
    }

    private fun buildButton(label: TextView) =
        LinearLayout(context).apply {
            gravity    = Gravity.CENTER
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL }
            elevation  = dp(5).toFloat()
            addView(label)
        }
}
