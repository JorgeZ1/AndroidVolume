package com.fixbyte.floatingvolume

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.view.MotionEvent
import android.view.View
import kotlin.math.roundToInt

/** Self-drawn vertical volume bar. It renders consistently inside an overlay on OEM Android skins. */
class VerticalVolumeBarView(context: Context) : View(context) {
    private fun dp(v: Float) = v * resources.displayMetrics.density
    private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(75, 255, 255, 255) }
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(41, 121, 255) }
    private val thumbPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    private var level = 0
    private var maximum = 1
    var onUserLevelChanged: ((Int) -> Unit)? = null
    var onInteractionStarted: (() -> Unit)? = null
    var onInteractionFinished: (() -> Unit)? = null

    fun update(volume: Int, max: Int, enabled: Boolean) {
        maximum = max.coerceAtLeast(1)
        level = volume.coerceIn(0, maximum)
        alpha = if (enabled) 1f else 0.35f
        isEnabled = enabled
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val trackWidth = dp(8f)
        val left = (width - trackWidth) / 2f
        val top = dp(10f)
        val bottom = height - dp(10f)
        val radius = trackWidth / 2f
        val track = RectF(left, top, left + trackWidth, bottom)
        canvas.drawRoundRect(track, radius, radius, trackPaint)

        val fraction = level / maximum.toFloat()
        val fillTop = bottom - (bottom - top) * fraction
        canvas.drawRoundRect(RectF(left, fillTop, left + trackWidth, bottom), radius, radius, fillPaint)
        val thumbRadius = dp(6f)
        canvas.drawCircle(width / 2f, fillTop.coerceIn(top, bottom), thumbRadius, thumbPaint)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (!isEnabled) return false
        when (event.action) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE, MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                val top = dp(10f)
                val bottom = height - dp(10f)
                val fraction = (1f - (event.y - top) / (bottom - top).coerceAtLeast(1f)).coerceIn(0f, 1f)
                val newLevel = (fraction * maximum).roundToInt()
                if (newLevel != level) {
                    level = newLevel
                    invalidate()
                    onUserLevelChanged?.invoke(newLevel)
                }
                if (event.action == MotionEvent.ACTION_DOWN) {
                    parent?.requestDisallowInterceptTouchEvent(true)
                    onInteractionStarted?.invoke()
                }
                if (event.action == MotionEvent.ACTION_UP || event.action == MotionEvent.ACTION_CANCEL) {
                    parent?.requestDisallowInterceptTouchEvent(false)
                    onInteractionFinished?.invoke()
                }
            }
        }
        return true
    }
}
