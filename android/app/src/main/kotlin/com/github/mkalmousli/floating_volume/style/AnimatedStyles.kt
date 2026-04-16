package com.github.mkalmousli.floating_volume.style

import android.animation.Keyframe
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.view.animation.LinearInterpolator
import android.widget.TextView
import com.github.mkalmousli.floating_volume.WidgetSettings

private val dynamicCornerDp: Float
    get() = WidgetSettings.buttonSize * WidgetSettings.buttonCornerRadius

// ── RGB Aurora ───────────────────────────────────────────────────────────────
// Continuously rotates hue across the full spectrum (3 s cycle).

class RgbAuroraStyleApplier : ButtonStyleApplier {

    private var animator: ValueAnimator? = null
    private var plusBg:  GradientDrawable? = null
    private var minusBg: GradientDrawable? = null

    override fun apply(
        plusBtn: View, minusBtn: View,
        plusLabel: TextView, minusLabel: TextView,
        dp: (Number) -> Int,
    ) {
        val bg1 = GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            intArrayOf(Color.parseColor("#FF0080"), Color.parseColor("#7B00FF"))
        ).apply { shape = GradientDrawable.RECTANGLE; cornerRadius = dp(dynamicCornerDp).toFloat() }

        val bg2 = GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            intArrayOf(Color.parseColor("#7B00FF"), Color.parseColor("#00C9FF"))
        ).apply { shape = GradientDrawable.RECTANGLE; cornerRadius = dp(dynamicCornerDp).toFloat() }

        plusBtn.background  = bg1;  plusBtn.elevation  = dp(3).toFloat()
        minusBtn.background = bg2;  minusBtn.elevation = dp(3).toFloat()
        plusLabel.setTextColor(Color.WHITE)
        minusLabel.setTextColor(Color.WHITE)

        plusBg  = bg1
        minusBg = bg2
    }

    override fun startAnimation() {
        val bg1 = plusBg  ?: return
        val bg2 = minusBg ?: return

        animator = ValueAnimator.ofFloat(0f, 360f).apply {
            duration     = 7_000L
            repeatCount  = ValueAnimator.INFINITE
            repeatMode   = ValueAnimator.RESTART
            interpolator = LinearInterpolator()
            addUpdateListener { anim ->
                val hue = anim.animatedValue as Float
                val c1  = hsvColor(hue, 0.9f, 1f)
                val c2  = hsvColor((hue + 120) % 360, 0.9f, 1f)
                val c3  = hsvColor((hue + 240) % 360, 0.9f, 1f)
                bg1.colors = intArrayOf(c1, c2)
                bg2.colors = intArrayOf(c2, c3)
            }
            start()
        }
    }

    override fun stopAnimation() { animator?.cancel(); animator = null }
}

// ── RGB Neon (Cyberpunk) ─────────────────────────────────────────────────────
// Pulses border + text between cyan and magenta (2 s cycle, reverse).

class RgbNeonStyleApplier : ButtonStyleApplier {

    private var animator:  ValueAnimator? = null
    private var plusBg:    android.graphics.drawable.GradientDrawable? = null
    private var minusBg:   android.graphics.drawable.GradientDrawable? = null
    private var plusBorder: RotatingBorderDrawable? = null
    private var minusBorder: RotatingBorderDrawable? = null
    private var plusLbl:   TextView? = null
    private var minusLbl:  TextView? = null
    private var plusBtnView: View? = null
    private var minusBtnView: View? = null

    override fun apply(
        plusBtn: View, minusBtn: View,
        plusLabel: TextView, minusLabel: TextView,
        dp: (Number) -> Int,
    ) {
        val cyan    = Color.parseColor("#00FFFF")
        val magenta = Color.parseColor("#FF00FF")

        val bg1 = android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.RECTANGLE
            cornerRadius = dp(dynamicCornerDp).toFloat()
            setColor(Color.BLACK)
        }
        val bg2 = android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.RECTANGLE
            cornerRadius = dp(dynamicCornerDp).toFloat()
            setColor(Color.BLACK)
        }

        val border1 = RotatingBorderDrawable(
            dp(2.5f).toFloat(), dp(dynamicCornerDp).toFloat(), intArrayOf(cyan, magenta, cyan)
        )
        val border2 = RotatingBorderDrawable(
            dp(2.5f).toFloat(), dp(dynamicCornerDp).toFloat(), intArrayOf(magenta, cyan, magenta)
        )

        plusBtn.background  = android.graphics.drawable.LayerDrawable(arrayOf(bg1, border1))
        minusBtn.background = android.graphics.drawable.LayerDrawable(arrayOf(bg2, border2))
        plusBtn.elevation  = dp(8).toFloat()
        minusBtn.elevation = dp(8).toFloat()

        plusLabel.setTextColor(cyan)
        minusLabel.setTextColor(magenta)

        plusBg  = bg1;   minusBg  = bg2
        plusBorder = border1; minusBorder = border2
        plusLbl = plusLabel; minusLbl = minusLabel
        plusBtnView = plusBtn; minusBtnView = minusBtn
    }

    override fun startAnimation() {
        val b1   = plusBorder ?: return
        val b2   = minusBorder ?: return
        val lbl1 = plusLbl  ?: return
        val lbl2 = minusLbl ?: return
        val pBtn = plusBtnView ?: return
        val mBtn = minusBtnView ?: return

        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration    = 2_500L
            repeatCount = ValueAnimator.INFINITE
            repeatMode  = ValueAnimator.RESTART
            addUpdateListener { anim ->
                val t = anim.animatedValue as Float
                b1.rotation = t * 360f
                b2.rotation = 360f - (t * 360f) // opposite direction

                val pingPong = (Math.sin(t * Math.PI * 2) * 0.5 + 0.5).toFloat()
                val cyan    = lerpColor(0xFF00FFFF.toInt(), 0xFF00B4FF.toInt(), pingPong)
                val magenta = lerpColor(0xFFFF00FF.toInt(), 0xFFFF0090.toInt(), pingPong)
                
                lbl1.setTextColor(cyan)
                lbl2.setTextColor(magenta)
                pBtn.invalidate()
                mBtn.invalidate()
            }
            start()
        }
    }

    override fun stopAnimation() { animator?.cancel(); animator = null }
}

// ── Cosmic (Space) ───────────────────────────────────────────────────────────
// Deep-space gradient that slowly morphs between space-blue → purple → gold.
// No overlay view — pure animated GradientDrawable, no full-screen bugs.

class CosmicStyleApplier : ButtonStyleApplier {

    private var animator:  ValueAnimator? = null
    private var plusBg:    android.graphics.drawable.GradientDrawable? = null
    private var minusBg:   android.graphics.drawable.GradientDrawable? = null
    private var plusBorder: RotatingBorderDrawable? = null
    private var minusBorder: RotatingBorderDrawable? = null
    private var plusBtn_:  View? = null
    private var minusBtn_: View? = null

    override fun apply(
        plusBtn: View, minusBtn: View,
        plusLabel: TextView, minusLabel: TextView,
        dp: (Number) -> Int,
    ) {
        val bg1 = android.graphics.drawable.GradientDrawable(
            android.graphics.drawable.GradientDrawable.Orientation.TL_BR,
            intArrayOf(Color.parseColor("#0D1B69"), Color.parseColor("#9B5DE5"))
        ).apply { shape = android.graphics.drawable.GradientDrawable.RECTANGLE; cornerRadius = dp(dynamicCornerDp).toFloat() }

        val bg2 = android.graphics.drawable.GradientDrawable(
            android.graphics.drawable.GradientDrawable.Orientation.TL_BR,
            intArrayOf(Color.parseColor("#9B5DE5"), Color.parseColor("#FFD700"))
        ).apply { shape = android.graphics.drawable.GradientDrawable.RECTANGLE; cornerRadius = dp(dynamicCornerDp).toFloat() }

        val borderColors = intArrayOf(
            Color.parseColor("#9B5DE5"), Color.TRANSPARENT, Color.parseColor("#FFD700"), Color.TRANSPARENT, Color.parseColor("#9B5DE5")
        )
        val border1 = RotatingBorderDrawable(dp(2f).toFloat(), dp(dynamicCornerDp).toFloat(), borderColors)
        val border2 = RotatingBorderDrawable(dp(2f).toFloat(), dp(dynamicCornerDp).toFloat(), borderColors)

        plusBtn.background  = android.graphics.drawable.LayerDrawable(arrayOf(bg1, border1))
        minusBtn.background = android.graphics.drawable.LayerDrawable(arrayOf(bg2, border2))
        
        plusBtn.elevation  = dp(10).toFloat()
        minusBtn.elevation = dp(10).toFloat()
        plusLabel.setTextColor(Color.WHITE)
        minusLabel.setTextColor(Color.WHITE)

        plusBg    = bg1;  minusBg   = bg2
        plusBorder = border1; minusBorder = border2
        plusBtn_  = plusBtn; minusBtn_ = minusBtn
    }

    override fun startAnimation() {
        val bg1 = plusBg   ?: return
        val bg2 = minusBg  ?: return
        val b1  = plusBorder ?: return
        val b2  = minusBorder ?: return
        val p   = plusBtn_ ?: return
        val m   = minusBtn_?: return

        // Morph gradient colors + pulse elevation + rotate borders together
        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration    = 3_000L
            repeatCount = ValueAnimator.INFINITE
            repeatMode  = ValueAnimator.RESTART
            addUpdateListener { anim ->
                val t       = anim.animatedValue as Float
                b1.rotation = t * 360f
                b2.rotation = t * 360f

                val pingPong = (Math.sin(t * Math.PI * 2) * 0.5 + 0.5).toFloat()
                val spBlue  = lerpColor(0xFF0D1B69.toInt(), 0xFF1A0A3F.toInt(), pingPong)
                val purple  = lerpColor(0xFF9B5DE5.toInt(), 0xFF5B10A0.toInt(), pingPong)
                val gold    = lerpColor(0xFFFFD700.toInt(), 0xFFFF8C00.toInt(), pingPong)
                bg1.colors  = intArrayOf(spBlue, purple)
                bg2.colors  = intArrayOf(purple, gold)
                val elev    = 8f + pingPong * 6f   // 8 → 14 dp equivalent
                p.elevation = elev
                m.elevation = elev
                p.invalidate()
                m.invalidate()
            }
            start()
        }
    }

    override fun stopAnimation() { animator?.cancel(); animator = null }
}

// ── Lava ─────────────────────────────────────────────────────────────────────
// Flickering molten-lava gradient: dark crimson → lava orange → bright fire tip.
// Fast flicker (800 ms) simulates heat shimmer.

class LavaStyleApplier : ButtonStyleApplier {

    private var animator: ValueAnimator? = null
    private var plusBg:  GradientDrawable? = null
    private var minusBg: GradientDrawable? = null

    override fun apply(
        plusBtn: View, minusBtn: View,
        plusLabel: TextView, minusLabel: TextView,
        dp: (Number) -> Int,
    ) {
        val bg1 = GradientDrawable(
            GradientDrawable.Orientation.BOTTOM_TOP,
            intArrayOf(Color.parseColor("#3D0000"), Color.parseColor("#FF4500"))
        ).apply { shape = GradientDrawable.RECTANGLE; cornerRadius = dp(dynamicCornerDp).toFloat() }

        val bg2 = GradientDrawable(
            GradientDrawable.Orientation.BOTTOM_TOP,
            intArrayOf(Color.parseColor("#FF4500"), Color.parseColor("#FFD700"))
        ).apply { shape = GradientDrawable.RECTANGLE; cornerRadius = dp(dynamicCornerDp).toFloat() }

        plusBtn.background  = bg1;  plusBtn.elevation  = dp(6).toFloat()
        minusBtn.background = bg2;  minusBtn.elevation = dp(4).toFloat()
        plusLabel.setTextColor(Color.WHITE)
        minusLabel.setTextColor(Color.WHITE)

        plusBg  = bg1
        minusBg = bg2
    }

    override fun startAnimation() {
        val bg1 = plusBg  ?: return
        val bg2 = minusBg ?: return

        // Heartbeat: quick double-pump then rest
        val kf0 = Keyframe.ofFloat(0f,    0f)
        val kf1 = Keyframe.ofFloat(0.12f, 1f)    // first beat peak
        val kf2 = Keyframe.ofFloat(0.24f, 0.3f)  // valley between beats
        val kf3 = Keyframe.ofFloat(0.36f, 0.75f) // second beat
        val kf4 = Keyframe.ofFloat(0.50f, 0f)    // return to rest
        val kf5 = Keyframe.ofFloat(1f,    0f)    // rest period
        val pvh = PropertyValuesHolder.ofKeyframe("t", kf0, kf1, kf2, kf3, kf4, kf5)

        animator = ValueAnimator.ofPropertyValuesHolder(pvh).apply {
            duration    = 2_800L
            repeatCount = ValueAnimator.INFINITE
            repeatMode  = ValueAnimator.RESTART
            addUpdateListener { anim ->
                val t      = anim.animatedValue as Float
                val dark   = lerpColor(0xFF3D0000.toInt(), 0xFF6B0000.toInt(), t)
                val mid    = lerpColor(0xFFFF4500.toInt(), 0xFFFF6A00.toInt(), t)
                val bright = lerpColor(0xFFFF8C00.toInt(), 0xFFFFD700.toInt(), t)
                bg1.colors = intArrayOf(dark, mid)
                bg2.colors = intArrayOf(mid, bright)
            }
            start()
        }
    }

    override fun stopAnimation() { animator?.cancel(); animator = null }
}

// ── Utilities ─────────────────────────────────────────────────────────────────

private fun hsvColor(hue: Float, saturation: Float, value: Float): Int =
    Color.HSVToColor(floatArrayOf(hue, saturation, value))

internal fun lerpColor(from: Int, to: Int, t: Float): Int {
    val r = (Color.red(from)   + t * (Color.red(to)   - Color.red(from))).toInt()
    val g = (Color.green(from) + t * (Color.green(to) - Color.green(from))).toInt()
    val b = (Color.blue(from)  + t * (Color.blue(to)  - Color.blue(from))).toInt()
    return Color.rgb(r, g, b)
}
