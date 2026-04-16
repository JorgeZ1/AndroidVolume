package com.github.mkalmousli.floating_volume.style

import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.SweepGradient
import android.graphics.drawable.Drawable

/**
 * A custom Drawable that draws a rotating gradient border (a "snake" or "running" effect).
 * Perfect for RGB Neon and Cosmic styles to give them more personality.
 */
class RotatingBorderDrawable(
    private val strokePx: Float,
    private val cornerRadius: Float,
    private val colors: IntArray
) : Drawable() {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = strokePx
    }

    private val matrix = Matrix()
    private var sweepGradient: SweepGradient? = null

    var rotation: Float = 0f
        set(value) {
            field = value
            invalidateSelf()
        }

    override fun onBoundsChange(bounds: Rect) {
        super.onBoundsChange(bounds)
        if (bounds.width() > 0 && bounds.height() > 0) {
            sweepGradient = SweepGradient(bounds.exactCenterX(), bounds.exactCenterY(), colors, null)
            paint.shader = sweepGradient
        }
    }

    override fun draw(canvas: Canvas) {
        val bounds = bounds
        sweepGradient?.let {
            matrix.setRotate(rotation, bounds.exactCenterX(), bounds.exactCenterY())
            it.setLocalMatrix(matrix)
        }

        val inset = strokePx / 2f
        canvas.drawRoundRect(
            bounds.left + inset, bounds.top + inset,
            bounds.right - inset, bounds.bottom - inset,
            cornerRadius, cornerRadius, paint
        )
    }

    override fun setAlpha(alpha: Int) {
        paint.alpha = alpha
    }

    override fun setColorFilter(colorFilter: ColorFilter?) {
        paint.colorFilter = colorFilter
    }

    @Deprecated("Deprecated in Java", ReplaceWith("PixelFormat.TRANSLUCENT", "android.graphics.PixelFormat"))
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT
}
