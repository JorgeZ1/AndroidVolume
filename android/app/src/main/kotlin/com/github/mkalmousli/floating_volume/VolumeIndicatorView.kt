package com.github.mkalmousli.floating_volume

import android.animation.Keyframe
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.animation.LinearInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Small floating volume indicator shown beside the buttons when volume changes.
 * Automatically adapts its visual style to [WidgetSettings.style].
 */
class VolumeIndicatorView(context: Context) : LinearLayout(context) {

    private fun dp(v: Number) = (v.toFloat() * resources.displayMetrics.density).toInt()

    // ── Drawables ────────────────────────────────────────────────────────────

    private val cardBg  = GradientDrawable().apply {
        shape        = GradientDrawable.RECTANGLE
        cornerRadius = dp(18).toFloat()
    }
    private val trackBg = GradientDrawable().apply {
        shape        = GradientDrawable.RECTANGLE
        cornerRadius = dp(4).toFloat()
    }
    private val fillBg  = GradientDrawable().apply {
        shape        = GradientDrawable.RECTANGLE
        cornerRadius = dp(4).toFloat()
    }

    // ── Child views ───────────────────────────────────────────────────────────

    private val numberLabel = TextView(context).apply {
        textSize = 11f
        typeface = Typeface.DEFAULT_BOLD
        gravity  = Gravity.CENTER
    }

    private val trackView = android.view.View(context).apply { background = trackBg }
    private val fillView  = android.view.View(context).apply { background = fillBg }

    private val iconLabel = TextView(context).apply {
        text     = "VOL"
        textSize = 10f
        typeface = Typeface.DEFAULT_BOLD
        gravity  = Gravity.CENTER
    }

    // ── State ─────────────────────────────────────────────────────────────────

    private var currentFraction = 0f
    private var fillAnimator: ValueAnimator? = null
    private var sparkleAnimator: ValueAnimator? = null
    private var animatedBorder: com.github.mkalmousli.floating_volume.style.RotatingBorderDrawable? = null

    override fun dispatchDraw(canvas: android.graphics.Canvas) {
        super.dispatchDraw(canvas)
        animatedBorder?.let {
            it.setBounds(0, 0, width, height)
            it.draw(canvas)
        }
    }

    companion object {
        // Match these with showVolumeIndicator() in FloatingVolumeService
        const val VIEW_W_DP = 48
        const val VIEW_H_DP = 160
        private const val TRACK_H_DP = 72
    }

    init {
        orientation = VERTICAL
        gravity     = Gravity.CENTER_HORIZONTAL
        background  = cardBg
        setPadding(dp(4), dp(8), dp(4), dp(8))
        elevation   = 0f  // no shadow — keep it clean

        val w = dp(32)

        addView(numberLabel, LayoutParams(w, LayoutParams.WRAP_CONTENT))
        addView(android.view.View(context), LayoutParams(w, dp(6))) // spacer

        // Track + fill stacked in a FrameLayout
        val trackFrame = FrameLayout(context)
        val trackW = dp(8)
        val trackH = dp(TRACK_H_DP)

        trackFrame.addView(trackView, FrameLayout.LayoutParams(trackW, trackH).also {
            it.gravity = Gravity.CENTER_HORIZONTAL
        })
        trackFrame.addView(fillView, FrameLayout.LayoutParams(trackW, 0).also {
            it.gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
        })

        addView(trackFrame, LayoutParams(w, trackH))

        addView(android.view.View(context), LayoutParams(w, dp(6))) // spacer
        addView(iconLabel, LayoutParams(w, LayoutParams.WRAP_CONTENT))

        applyStyle()
    }

    // ── Public API ────────────────────────────────────────────────────────────

    fun update(volume: Int, maxVolume: Int) {
        currentFraction = if (maxVolume > 0) volume / maxVolume.toFloat() else 0f
        numberLabel.text = volume.toString()
        updateFill()
    }

    /** Call whenever [WidgetSettings] changes (color mode, style, opacity). */
    fun applyStyle() {
        stopFillAnimation()

        val isDark = resources.configuration.uiMode and
                Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES

        when (WidgetSettings.style) {
            WidgetSettings.Style.ANDROID       -> applyAndroid(isDark)
            WidgetSettings.Style.ANDROID_12    -> applyAndroid12()
            WidgetSettings.Style.IOS           -> applyIos()
            WidgetSettings.Style.MIUI          -> applyMiui()
            WidgetSettings.Style.SAMSUNG_ONE_UI -> applyOneUi()
            WidgetSettings.Style.RGB_AURORA    -> applyRgbAurora()
            WidgetSettings.Style.RGB_NEON      -> applyRgbNeon()
            WidgetSettings.Style.COSMIC        -> applyCosmic()
            WidgetSettings.Style.LAVA          -> applyLava()
            WidgetSettings.Style.CARDS         -> applyCards(isDark)
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        applyStyle()
    }

    // ── Style implementations ─────────────────────────────────────────────────

    private fun applyAndroid(isDark: Boolean) {
        val card  = if (isDark) Color.parseColor("#1C1C1E") else Color.WHITE
        val track = if (isDark) Color.parseColor("#3A3A3C") else Color.parseColor("#E0E0E0")
        val fill  = Color.parseColor("#2979FF")
        val text  = if (isDark) Color.WHITE else Color.parseColor("#2979FF")
        apply(card, track, fill, text)
    }

    private fun applyAndroid12() {
        apply(
            card  = Color.parseColor("#2979FF"),
            track = Color.parseColor("#1555CC"),
            fill  = Color.WHITE,
            text  = Color.WHITE,
        )
        fillBg.cornerRadius  = dp(4).toFloat()
        trackBg.cornerRadius = dp(4).toFloat()
    }

    private fun applyIos() {
        // Translucent frosted-glass look
        cardBg.setColor(Color.argb(55, 255, 255, 255))
        cardBg.setStroke(dp(1), Color.argb(70, 255, 255, 255))
        trackBg.setColor(Color.argb(50, 255, 255, 255))
        fillBg.setColor(Color.WHITE)
        numberLabel.setTextColor(Color.WHITE)
        iconLabel.setTextColor(Color.argb(180, 255, 255, 255))
    }

    private fun applyMiui() {
        val orange = Color.parseColor("#FF6900")
        cardBg.setColor(Color.argb(40, 30, 30, 30))
        cardBg.setStroke(dp(1), Color.argb(160, 255, 105, 0))
        trackBg.setColor(Color.argb(50, 255, 255, 255))
        fillBg.setColor(orange)
        numberLabel.setTextColor(orange)
        iconLabel.setTextColor(Color.argb(180, 255, 105, 0))
    }

    private fun applyOneUi() {
        val teal = Color.parseColor("#1DB3A8")
        cardBg.setColor(Color.argb(50, 20, 20, 25))
        cardBg.setStroke(0, Color.TRANSPARENT)
        trackBg.setColor(Color.argb(60, 255, 255, 255))
        fillBg.setColor(teal)
        numberLabel.setTextColor(teal)
        iconLabel.setTextColor(Color.argb(180, 29, 179, 168))
    }

    private fun applyRgbAurora() {
        cardBg.setColor(Color.parseColor("#12001A"))
        cardBg.setStroke(0, Color.TRANSPARENT)
        trackBg.setColor(Color.argb(60, 255, 255, 255))
        fillBg.setColor(Color.parseColor("#7B00FF"))
        numberLabel.setTextColor(Color.WHITE)
        iconLabel.setTextColor(Color.argb(200, 255, 255, 255))

        // Animate fill through rainbow hues
        fillAnimator = ValueAnimator.ofFloat(0f, 360f).apply {
            duration     = 7_000L
            repeatCount  = ValueAnimator.INFINITE
            repeatMode   = ValueAnimator.RESTART
            interpolator = LinearInterpolator()
            addUpdateListener { anim ->
                val hue = anim.animatedValue as Float
                fillBg.setColor(Color.HSVToColor(floatArrayOf(hue, 0.9f, 1f)))
            }
            start()
        }
    }

    private fun applyRgbNeon() {
        cardBg.setColor(Color.BLACK)
        cardBg.setStroke(0, Color.TRANSPARENT)
        trackBg.setColor(Color.argb(40, 255, 255, 255))
        fillBg.setColor(Color.parseColor("#00FFFF"))
        numberLabel.setTextColor(Color.parseColor("#00FFFF"))
        iconLabel.setTextColor(Color.argb(200, 0, 255, 255))

        val cyan    = Color.parseColor("#00FFFF")
        val magenta = Color.parseColor("#FF00FF")

        animatedBorder = com.github.mkalmousli.floating_volume.style.RotatingBorderDrawable(
            dp(2).toFloat(), dp(18).toFloat(), intArrayOf(cyan, magenta, cyan)
        )

        // Pulse fill and label, and rotate border
        fillAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration    = 2_500L
            repeatCount = ValueAnimator.INFINITE
            repeatMode  = ValueAnimator.RESTART
            addUpdateListener { anim ->
                val t       = anim.animatedValue as Float
                animatedBorder?.rotation = t * 360f

                // Pulse the inner colors back and forth using sine
                val pingPong = (Math.sin(t * Math.PI * 2) * 0.5 + 0.5).toFloat()
                val currentCyan    = lerpColor(0xFF00FFFF.toInt(), 0xFF00B4FF.toInt(), pingPong)
                val currentMagenta = lerpColor(0xFFFF00FF.toInt(), 0xFFFF0090.toInt(), pingPong)
                
                fillBg.setColor(currentMagenta)
                numberLabel.setTextColor(currentCyan)
                iconLabel.setTextColor(withAlpha(currentCyan, 200))
                invalidate()
            }
            start()
        }
    }

    private fun applyCosmic() {
        cardBg.setColor(Color.parseColor("#0D0221"))
        cardBg.setStroke(0, Color.TRANSPARENT)
        trackBg.setColor(Color.argb(60, 155, 93, 229))
        fillBg.setColor(Color.parseColor("#9B5DE5"))
        numberLabel.setTextColor(Color.parseColor("#FFD700"))
        iconLabel.setTextColor(Color.argb(200, 155, 93, 229))

        animatedBorder = com.github.mkalmousli.floating_volume.style.RotatingBorderDrawable(
            dp(2).toFloat(), dp(18).toFloat(), intArrayOf(
                Color.parseColor("#9B5DE5"), Color.TRANSPARENT, Color.parseColor("#FFD700"), Color.TRANSPARENT, Color.parseColor("#9B5DE5")
            )
        )

        // Rotate borderline and pulse fill between purple and gold
        fillAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration    = 3_000L
            repeatCount = ValueAnimator.INFINITE
            repeatMode  = ValueAnimator.RESTART
            addUpdateListener { anim ->
                val t = anim.animatedValue as Float
                animatedBorder?.rotation = t * 360f

                val pingPong = (Math.sin(t * Math.PI * 2) * 0.5 + 0.5).toFloat()
                fillBg.setColor(lerpColor(0xFF9B5DE5.toInt(), 0xFFFFD700.toInt(), pingPong))
                invalidate()
            }
            start()
        }
    }

    private fun applyLava() {
        cardBg.setColor(Color.parseColor("#1A0000"))
        cardBg.setStroke(dp(1), Color.parseColor("#FF4500"))
        trackBg.setColor(Color.argb(50, 100, 0, 0))
        fillBg.setColor(Color.parseColor("#FF4500"))
        numberLabel.setTextColor(Color.parseColor("#FFD700"))
        iconLabel.setTextColor(Color.argb(200, 255, 69, 0))

        // Heartbeat rhythm: quick double-pump then rest
        val kf0 = Keyframe.ofFloat(0f,    0f)
        val kf1 = Keyframe.ofFloat(0.12f, 1f)    // first beat peak
        val kf2 = Keyframe.ofFloat(0.24f, 0.3f)  // valley between beats
        val kf3 = Keyframe.ofFloat(0.36f, 0.75f) // second beat
        val kf4 = Keyframe.ofFloat(0.50f, 0f)    // return to rest
        val kf5 = Keyframe.ofFloat(1f,    0f)    // rest period
        val pvh = PropertyValuesHolder.ofKeyframe("t", kf0, kf1, kf2, kf3, kf4, kf5)

        fillAnimator = ValueAnimator.ofPropertyValuesHolder(pvh).apply {
            duration    = 2_800L
            repeatCount = ValueAnimator.INFINITE
            repeatMode  = ValueAnimator.RESTART
            addUpdateListener { anim ->
                val t = anim.animatedValue as Float
                fillBg.setColor(lerpColor(0xFFFF4500.toInt(), 0xFFFFD700.toInt(), t))
                cardBg.setStroke(dp(1), lerpColor(
                    Color.argb(160, 255, 69, 0),
                    Color.argb(255, 255, 180, 0), t))
            }
            start()
        }
    }

    private fun applyCards(isDark: Boolean) {
        val card  = if (isDark) Color.parseColor("#2C2C2E") else Color.WHITE
        val track = if (isDark) Color.parseColor("#48484A") else Color.parseColor("#E0E0E0")
        val fill  = if (isDark) Color.WHITE else Color.parseColor("#1A1A1A")
        val text  = if (isDark) Color.WHITE else Color.parseColor("#1A1A1A")
        apply(card, track, fill, text)
        cardBg.cornerRadius  = dp(12).toFloat()
        trackBg.cornerRadius = dp(4).toFloat()
        fillBg.cornerRadius  = dp(4).toFloat()
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun apply(card: Int, track: Int, fill: Int, text: Int) {
        cardBg.setColor(card)
        cardBg.setStroke(0, Color.TRANSPARENT)
        trackBg.setColor(track)
        fillBg.setColor(fill)
        numberLabel.setTextColor(text)
        iconLabel.setTextColor(withAlpha(text, 160))
    }

    private fun updateFill() {
        val lp = fillView.layoutParams as FrameLayout.LayoutParams
        lp.height = (dp(TRACK_H_DP) * currentFraction).toInt().coerceAtLeast(dp(2))
        fillView.layoutParams = lp
        fillView.requestLayout()
    }

    private fun stopFillAnimation() {
        fillAnimator?.cancel();   fillAnimator   = null
        sparkleAnimator?.cancel(); sparkleAnimator = null
        animatedBorder = null
    }

    private fun withAlpha(color: Int, alpha: Int) =
        Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))

    private fun lerpColor(from: Int, to: Int, t: Float): Int {
        val r = (Color.red(from)   + t * (Color.red(to)   - Color.red(from))).toInt()
        val g = (Color.green(from) + t * (Color.green(to) - Color.green(from))).toInt()
        val b = (Color.blue(from)  + t * (Color.blue(to)  - Color.blue(from))).toInt()
        return Color.rgb(r, g, b)
    }
}
