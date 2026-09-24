package com.fixbyte.floatingvolume.style

import android.animation.Keyframe
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.view.animation.LinearInterpolator
import android.widget.TextView
import com.fixbyte.floatingvolume.WidgetSettings

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

// ── Glacier (Aurora on Ice) ───────────────────────────────────────────────────
// Frozen crystal with a living surface: deep arctic blue → glacial cyan with an
// aurora tint (mint/violet) drifting through it, a rotating white "light glint"
// border, and a periodic bright flash — like sunlight catching a shard of ice.

class GlacierStyleApplier : ButtonStyleApplier {

    private var animator: ValueAnimator? = null
    private var plusBg:  GradientDrawable? = null
    private var minusBg: GradientDrawable? = null
    private var plusBorder:  RotatingBorderDrawable? = null
    private var minusBorder: RotatingBorderDrawable? = null
    private var plusBtn_:  View? = null
    private var minusBtn_: View? = null
    private var plusLabel_:  TextView? = null
    private var minusLabel_: TextView? = null

    override fun apply(
        plusBtn: View, minusBtn: View,
        plusLabel: TextView, minusLabel: TextView,
        dp: (Number) -> Int,
    ) {
        val bg1 = GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            intArrayOf(Color.parseColor("#0B2E4F"), Color.parseColor("#38B6D4"))
        ).apply { shape = GradientDrawable.RECTANGLE; cornerRadius = dp(dynamicCornerDp).toFloat() }

        val bg2 = GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            intArrayOf(Color.parseColor("#38B6D4"), Color.parseColor("#0A1B3F"))
        ).apply { shape = GradientDrawable.RECTANGLE; cornerRadius = dp(dynamicCornerDp).toFloat() }

        // Rotating white/cyan glint — light travelling around the ice edge
        val glowWidth = dp(2f).toFloat() * WidgetSettings.creativeGlowIntensity * 1.2f
        val glintColors = intArrayOf(
            Color.WHITE, Color.TRANSPARENT,
            Color.parseColor("#7FF6FF"), Color.TRANSPARENT, Color.WHITE
        )
        val border1 = RotatingBorderDrawable(glowWidth, dp(dynamicCornerDp).toFloat(), glintColors)
        val border2 = RotatingBorderDrawable(glowWidth, dp(dynamicCornerDp).toFloat(), glintColors)

        plusBtn.background  = android.graphics.drawable.LayerDrawable(arrayOf(bg1, border1))
        minusBtn.background = android.graphics.drawable.LayerDrawable(arrayOf(bg2, border2))
        plusBtn.elevation  = dp(8).toFloat()
        minusBtn.elevation = dp(8).toFloat()
        plusLabel.setTextColor(Color.parseColor("#E3FCFF"))
        minusLabel.setTextColor(Color.parseColor("#E3FCFF"))

        plusBg = bg1; minusBg = bg2
        plusBorder = border1; minusBorder = border2
        plusBtn_ = plusBtn; minusBtn_ = minusBtn
        plusLabel_ = plusLabel; minusLabel_ = minusLabel
    }

    override fun startAnimation() {
        val bg1 = plusBg   ?: return
        val bg2 = minusBg  ?: return
        val b1  = plusBorder  ?: return
        val b2  = minusBorder ?: return
        val p   = plusBtn_  ?: return
        val m   = minusBtn_ ?: return
        val pl  = plusLabel_  ?: return
        val ml  = minusLabel_ ?: return

        val animSpeed = WidgetSettings.creativeAnimSpeed.takeIf { it > 0 } ?: 1f
        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration    = (6_000L / animSpeed).toLong()
            repeatCount = ValueAnimator.INFINITE
            repeatMode  = ValueAnimator.RESTART
            addUpdateListener { anim ->
                val t = anim.animatedValue as Float
                b1.rotation = t * 360f
                b2.rotation = -t * 360f   // opposite directions: two shards of light

                // Aurora drift: cyan surface tinted mint → violet and back
                val wave  = (Math.sin(t * Math.PI * 2) * 0.5 + 0.5).toFloat()
                val deep  = lerpColor(0xFF0B2E4F.toInt(), 0xFF14104F.toInt(), wave)
                val cyan  = lerpColor(0xFF38B6D4.toInt(), 0xFF52E5C4.toInt(), wave)  // cyan → mint
                val tint  = lerpColor(0xFF38B6D4.toInt(), 0xFF7C6BE8.toInt(), wave)  // cyan → violet
                bg1.colors = intArrayOf(deep, cyan)
                bg2.colors = intArrayOf(tint, lerpColor(0xFF0A1B3F.toInt(), 0xFF071A2E.toInt(), wave))

                // Periodic ice-glint flash on the labels (sun catching the shard)
                val flash = if (t > 0.46f && t < 0.54f)
                    1f - (Math.abs(t - 0.5f) / 0.04f) else 0f
                val label = lerpColor(0xFFE3FCFF.toInt(), 0xFFFFFFFF.toInt(), flash)
                pl.setTextColor(label)
                ml.setTextColor(label)

                p.invalidate()
                m.invalidate()
            }
            start()
        }
    }

    override fun stopAnimation() { animator?.cancel(); animator = null }
}

// ── Matrix (Digital Rain) ─────────────────────────────────────────────────────
// Terminal-green on black: phosphor glow pulses like a CRT, with occasional
// brighter "data burst" flashes on the border.

class MatrixStyleApplier : ButtonStyleApplier {

    private var animator: ValueAnimator? = null
    private var plusBg:  GradientDrawable? = null
    private var minusBg: GradientDrawable? = null
    private var plusLabel_:  TextView? = null
    private var minusLabel_: TextView? = null
    private var borderPx = 2

    override fun apply(
        plusBtn: View, minusBtn: View,
        plusLabel: TextView, minusLabel: TextView,
        dp: (Number) -> Int,
    ) {
        borderPx = dp(1.5f)
        fun bg() = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(dynamicCornerDp).toFloat()
            setColor(Color.parseColor("#020A02"))
            setStroke(borderPx, Color.parseColor("#00FF41"))
        }
        val bg1 = bg(); val bg2 = bg()

        plusBtn.background  = bg1;  plusBtn.elevation  = dp(4).toFloat()
        minusBtn.background = bg2;  minusBtn.elevation = dp(4).toFloat()
        plusLabel.setTextColor(Color.parseColor("#00FF41"))
        minusLabel.setTextColor(Color.parseColor("#00FF41"))
        plusLabel.typeface  = android.graphics.Typeface.MONOSPACE
        minusLabel.typeface = android.graphics.Typeface.MONOSPACE

        plusBg = bg1; minusBg = bg2
        plusLabel_ = plusLabel; minusLabel_ = minusLabel
    }

    override fun startAnimation() {
        val bg1 = plusBg  ?: return
        val bg2 = minusBg ?: return
        val pl  = plusLabel_  ?: return
        val ml  = minusLabel_ ?: return

        val animSpeed = WidgetSettings.creativeAnimSpeed.takeIf { it > 0 } ?: 1f
        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration    = (1_800L / animSpeed).toLong()
            repeatCount = ValueAnimator.INFINITE
            repeatMode  = ValueAnimator.RESTART
            addUpdateListener { anim ->
                val t = anim.animatedValue as Float
                // Phosphor pulse with a sharp "data burst" at the cycle start
                val pulse = (Math.sin(t * Math.PI * 2) * 0.5 + 0.5).toFloat()
                val burst = if (t < 0.08f) 1f else 0f
                val green = lerpColor(0xFF007718.toInt(), 0xFF00FF41.toInt(),
                    (pulse * 0.7f + burst * 0.3f).coerceIn(0f, 1f))
                bg1.setStroke(borderPx, green)
                bg2.setStroke(borderPx, green)
                pl.setTextColor(green)
                ml.setTextColor(green)
            }
            start()
        }
    }

    override fun stopAnimation() { animator?.cancel(); animator = null }
}

// ── Palm silhouette (used by Retrowave) ──────────────────────────────────────
// Classic synthwave postcard element: a dark palm tree shadow leaning over the
// sunset. Drawn as a curved trunk + five fronds, normalized to the view bounds.

internal class PalmShadowDrawable(
    private val color: Int,
    private val mirror: Boolean = false,
) : android.graphics.drawable.Drawable() {

    private val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
        style     = android.graphics.Paint.Style.STROKE
        strokeCap = android.graphics.Paint.Cap.ROUND
    }

    override fun draw(canvas: android.graphics.Canvas) {
        val b = bounds
        val w = b.width().toFloat()
        val h = b.height().toFloat()
        if (w <= 0f || h <= 0f) return

        paint.color = color
        canvas.save()
        if (mirror) canvas.scale(-1f, 1f, b.exactCenterX(), b.exactCenterY())

        fun x(f: Float) = b.left + w * f
        fun y(f: Float) = b.top + h * f

        // Trunk: tapered filled shape leaning right, wider at the base
        paint.style = android.graphics.Paint.Style.FILL
        val trunk = android.graphics.Path().apply {
            moveTo(x(0.27f), y(0.95f))
            quadTo(x(0.33f), y(0.62f), x(0.49f), y(0.41f))   // left edge up
            lineTo(x(0.545f), y(0.445f))                     // crown width
            quadTo(x(0.39f), y(0.66f), x(0.345f), y(0.95f))  // right edge down
            close()
        }
        canvas.drawPath(trunk, paint)

        // Fronds: filled leaf shapes (lens-like petals) fanning out from the
        // crown, tips drooping downward like real palm leaves.
        val cx = x(0.52f); val cy = y(0.42f)
        fun leaf(
            tipX: Float, tipY: Float,      // leaf tip (droops below its arc)
            upX: Float, upY: Float,        // upper edge control (the arch)
            dnX: Float, dnY: Float,        // lower edge control (belly)
        ) {
            val p = android.graphics.Path()
            p.moveTo(cx, cy)
            p.quadTo(x(upX), y(upY), x(tipX), y(tipY))
            p.quadTo(x(dnX), y(dnY), cx, cy)
            p.close()
            canvas.drawPath(p, paint)
        }
        leaf(0.08f, 0.46f, 0.24f, 0.20f, 0.30f, 0.40f)  // left, deep droop
        leaf(0.14f, 0.22f, 0.28f, 0.14f, 0.34f, 0.30f)  // upper-left arch
        leaf(0.46f, 0.06f, 0.42f, 0.14f, 0.56f, 0.16f)  // top spike
        leaf(0.90f, 0.20f, 0.72f, 0.10f, 0.68f, 0.28f)  // upper-right arch
        leaf(0.96f, 0.46f, 0.80f, 0.20f, 0.72f, 0.40f)  // right, deep droop

        // Coconuts at the crown for definition
        canvas.drawCircle(x(0.485f), y(0.475f), w * 0.035f, paint)
        canvas.drawCircle(x(0.555f), y(0.475f), w * 0.035f, paint)

        canvas.restore()
    }

    override fun setAlpha(alpha: Int) { paint.alpha = alpha }
    override fun setColorFilter(colorFilter: android.graphics.ColorFilter?) {
        paint.colorFilter = colorFilter
    }
    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = android.graphics.PixelFormat.TRANSLUCENT
}

// ── Retrowave (Synthwave Sunset) ─────────────────────────────────────────────
// 80s sunset: deep violet → hot pink → orange, slowly breathing between dusk
// palettes, with a rotating pink/cyan glow border.

class RetrowaveStyleApplier : ButtonStyleApplier {

    private var animator: ValueAnimator? = null
    private var plusBg:  GradientDrawable? = null
    private var minusBg: GradientDrawable? = null
    private var plusBorder:  RotatingBorderDrawable? = null
    private var minusBorder: RotatingBorderDrawable? = null
    private var plusBtn_:  View? = null
    private var minusBtn_: View? = null

    override fun apply(
        plusBtn: View, minusBtn: View,
        plusLabel: TextView, minusLabel: TextView,
        dp: (Number) -> Int,
    ) {
        val bg1 = GradientDrawable(
            GradientDrawable.Orientation.BOTTOM_TOP,
            intArrayOf(Color.parseColor("#2B1055"), Color.parseColor("#FF2975"))
        ).apply { shape = GradientDrawable.RECTANGLE; cornerRadius = dp(dynamicCornerDp).toFloat() }

        val bg2 = GradientDrawable(
            GradientDrawable.Orientation.BOTTOM_TOP,
            intArrayOf(Color.parseColor("#FF2975"), Color.parseColor("#FF8C42"))
        ).apply { shape = GradientDrawable.RECTANGLE; cornerRadius = dp(dynamicCornerDp).toFloat() }

        val glowWidth = dp(2f).toFloat() * WidgetSettings.creativeGlowIntensity * 1.2f
        val borderColors = intArrayOf(
            Color.parseColor("#FF2975"), Color.TRANSPARENT,
            Color.parseColor("#00E5FF"), Color.TRANSPARENT, Color.parseColor("#FF2975")
        )
        val border1 = RotatingBorderDrawable(glowWidth, dp(dynamicCornerDp).toFloat(), borderColors)
        val border2 = RotatingBorderDrawable(glowWidth, dp(dynamicCornerDp).toFloat(), borderColors)

        // Palm tree shadow only on the lower (sunset) button — it contrasts
        // against the pink→orange gradient; the violet button stays clean.
        val palm = PalmShadowDrawable(Color.argb(150, 20, 4, 40), mirror = true)

        plusBtn.background  = android.graphics.drawable.LayerDrawable(arrayOf(bg1, border1))
        minusBtn.background = android.graphics.drawable.LayerDrawable(arrayOf(bg2, palm, border2))
        plusBtn.elevation  = dp(8).toFloat()
        minusBtn.elevation = dp(8).toFloat()
        plusLabel.setTextColor(Color.parseColor("#00E5FF"))
        minusLabel.setTextColor(Color.parseColor("#00E5FF"))

        plusBg = bg1; minusBg = bg2
        plusBorder = border1; minusBorder = border2
        plusBtn_ = plusBtn; minusBtn_ = minusBtn
    }

    override fun startAnimation() {
        val bg1 = plusBg   ?: return
        val bg2 = minusBg  ?: return
        val b1  = plusBorder  ?: return
        val b2  = minusBorder ?: return
        val p   = plusBtn_  ?: return
        val m   = minusBtn_ ?: return

        val animSpeed = WidgetSettings.creativeAnimSpeed.takeIf { it > 0 } ?: 1f
        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration    = (5_000L / animSpeed).toLong()
            repeatCount = ValueAnimator.INFINITE
            repeatMode  = ValueAnimator.RESTART
            addUpdateListener { anim ->
                val t = anim.animatedValue as Float
                b1.rotation = t * 360f
                b2.rotation = t * 360f

                val pingPong = (Math.sin(t * Math.PI * 2) * 0.5 + 0.5).toFloat()
                val violet = lerpColor(0xFF2B1055.toInt(), 0xFF4A1A7A.toInt(), pingPong)
                val pink   = lerpColor(0xFFFF2975.toInt(), 0xFFFF5FA2.toInt(), pingPong)
                val orange = lerpColor(0xFFFF8C42.toInt(), 0xFFFFB56B.toInt(), pingPong)
                bg1.colors = intArrayOf(violet, pink)
                bg2.colors = intArrayOf(pink, orange)
                p.invalidate()
                m.invalidate()
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
