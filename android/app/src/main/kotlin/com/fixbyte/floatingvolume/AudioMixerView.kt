package com.fixbyte.floatingvolume

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.TextView

/** A compact vertical mixer: one upright bar per Android audio stream. */
class AudioMixerView(
    context: Context,
    private val onVolumeChanged: (AudioStream, Int) -> Unit,
    private val onStreamSelected: (AudioStream) -> Unit,
    private val onInteractionStarted: () -> Unit,
    private val onInteractionFinished: () -> Unit,
) : LinearLayout(context) {
    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()
    private val values = mutableMapOf<AudioStream, TextView>()
    private val sliders = mutableMapOf<AudioStream, VerticalVolumeBarView>()
    private val columns = mutableMapOf<AudioStream, LinearLayout>()

    init {
        orientation = VERTICAL
        setPadding(dp(10), dp(10), dp(10), dp(12))
        background = GradientDrawable().apply {
            cornerRadius = dp(18).toFloat()
            setColor(Color.argb(242, 27, 27, 32))
            setStroke(dp(1), Color.argb(50, 255, 255, 255))
        }
        elevation = dp(12).toFloat()

        addView(TextView(context).apply {
            text = NativeLanguage.text(context, "Volume mixer", "Mezclador de volumen")
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            textSize = 14f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(6))
        }, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))

        val bars = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER
        }
        // Fixed-width columns stay readable on compact phones and landscape.
        // The row scrolls rather than compressing the six controls into unusable slivers.
        AudioStream.entries.forEach { bars.addView(createColumn(it), LayoutParams(dp(44), dp(190))) }
        addView(HorizontalScrollView(context).apply {
            isHorizontalScrollBarEnabled = false
            addView(bars, LayoutParams(LayoutParams.WRAP_CONTENT, dp(190)))
        }, LayoutParams(LayoutParams.MATCH_PARENT, dp(190)))
    }

    private fun createColumn(stream: AudioStream): LinearLayout = LinearLayout(context).apply {
        orientation = VERTICAL
        gravity = Gravity.CENTER_HORIZONTAL
        setPadding(dp(1), 0, dp(1), 0)

        val value = TextView(context).apply {
            text = "—"
            textSize = 10f
            gravity = Gravity.CENTER
            setTextColor(Color.LTGRAY)
        }
        val slider = VerticalVolumeBarView(context).apply {
            contentDescription = NativeLanguage.text(context, "${stream.label} volume", "Volumen de ${stream.localizedLabel(context)}")
            onUserLevelChanged = { level -> onVolumeChanged(stream, level) }
            onInteractionStarted = this@AudioMixerView.onInteractionStarted
            onInteractionFinished = this@AudioMixerView.onInteractionFinished
        }
        val icon = TextView(context).apply {
            text = stream.symbol
            textSize = 17f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setOnClickListener { onStreamSelected(stream) }
        }
        val name = TextView(context).apply {
            text = stream.localizedShortLabel(context)
            textSize = 7f
            gravity = Gravity.CENTER
            maxLines = 1
            setTextColor(Color.LTGRAY)
            setOnClickListener { onStreamSelected(stream) }
        }
        addView(value, LayoutParams(LayoutParams.MATCH_PARENT, dp(18)))
        addView(slider, LayoutParams(dp(30), dp(132)))
        addView(icon, LayoutParams(LayoutParams.MATCH_PARENT, dp(22)))
        addView(name, LayoutParams(LayoutParams.MATCH_PARENT, dp(16)))
        values[stream] = value
        sliders[stream] = slider
        columns[stream] = this
    }

    fun update(stream: AudioStream, volume: Int, max: Int, enabled: Boolean = true) {
        val slider = sliders[stream] ?: return
        slider.update(volume, max, enabled)
        values[stream]?.text = if (enabled) "$volume" else "—"
        columns[stream]?.alpha = if (enabled) 1f else 0.38f
    }
}
