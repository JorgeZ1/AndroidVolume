package com.github.mkalmousli.floating_volume

import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.view.*
import android.widget.FrameLayout
import androidx.core.view.updateLayoutParams
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.math.roundToInt

class CoolSlider(context: Context) : FrameLayout(context) {

    enum class Orientation { Vertical, Horizontal }

    private val scope = CoroutineScope(Dispatchers.Main.immediate + SupervisorJob())

    val max = MutableStateFlow(100)
    val min = MutableStateFlow(0)
    val value = MutableStateFlow(50)
    val isEnabled = MutableStateFlow(true)
    val orientation = MutableStateFlow(Orientation.Vertical)

    private val density get() = resources.displayMetrics.density
    private val trackThickness get() = (4 * density).toInt()
    private val thumbDiameter get() = (22 * density).toInt()

    // Gray background track
    private val trackView = View(context).apply {
        background = GradientDrawable().apply {
            setColor(0xFFE0E0E0.toInt())
            cornerRadius = 100f
        }
    }

    // Blue fill (grows from bottom for vertical)
    private val fillView = View(context).apply {
        background = GradientDrawable().apply {
            setColor(0xFF2979FF.toInt())
            cornerRadius = 100f
        }
    }

    // Blue circular thumb
    private val thumbView = View(context).apply {
        background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(0xFF2979FF.toInt())
        }
        elevation = 6 * resources.displayMetrics.density
    }

    init {
        // Track — full height, centered horizontally
        addView(
            trackView,
            LayoutParams(trackThickness, LayoutParams.MATCH_PARENT).apply {
                gravity = Gravity.CENTER_HORIZONTAL
            },
        )

        // Fill — bottom-anchored, same width as track
        addView(
            fillView,
            LayoutParams(trackThickness, 0).apply {
                gravity = Gravity.CENTER_HORIZONTAL or Gravity.BOTTOM
            },
        )

        // Thumb — positioned programmatically via translationY
        addView(
            thumbView,
            LayoutParams(thumbDiameter, thumbDiameter).apply {
                gravity = Gravity.CENTER_HORIZONTAL or Gravity.TOP
            },
        )

        setOnTouchListener { _, event ->
            if (!isEnabled.value || event == null) return@setOnTouchListener false

            when (event.action) {
                MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                    val size = if (orientation.value == Orientation.Horizontal) width else height
                    val pos = if (orientation.value == Orientation.Horizontal) event.x else event.y
                    val clamped = pos.coerceIn(0f, size.toFloat())

                    val fraction = when (orientation.value) {
                        Orientation.Horizontal -> clamped / size
                        Orientation.Vertical -> 1f - (clamped / size)
                    }

                    val newVal = (min.value + fraction * (max.value - min.value)).roundToInt()
                    value.value = newVal
                    true
                }
                MotionEvent.ACTION_UP -> {
                    performClick()
                    true
                }
                else -> false
            }
        }

        addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ -> updateProgress() }

        scope.launch {
            combine(value, min, max) { _, _, _ -> }.collectLatest {
                updateProgress()
            }
        }
    }

    private fun updateProgress() {
        val range = max.value - min.value
        if (range <= 0 || width == 0 || height == 0) return

        val fraction = ((value.value - min.value).toFloat() / range).coerceIn(0f, 1f)

        if (orientation.value == Orientation.Vertical) {
            val total = height
            val fillHeight = (total * fraction).toInt()

            fillView.updateLayoutParams<LayoutParams> {
                height = fillHeight
                width = trackThickness
            }

            // Thumb sits at the top edge of the fill
            val thumbTop = (total - fillHeight - thumbDiameter / 2f)
                .coerceIn(0f, (total - thumbDiameter).toFloat())
            thumbView.translationY = thumbTop
        } else {
            val total = width
            val fillWidth = (total * fraction).toInt()

            fillView.updateLayoutParams<LayoutParams> {
                width = fillWidth
                height = trackThickness
            }

            val thumbLeft = (fillWidth - thumbDiameter / 2f)
                .coerceIn(0f, (total - thumbDiameter).toFloat())
            thumbView.translationX = thumbLeft
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        scope.cancel()
    }
}
