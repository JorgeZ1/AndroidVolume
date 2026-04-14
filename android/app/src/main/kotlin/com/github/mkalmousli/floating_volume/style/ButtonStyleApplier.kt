package com.github.mkalmousli.floating_volume.style

import android.view.View
import android.widget.TextView

/**
 * Contract for each visual style of the floating volume buttons.
 *
 * [apply]          — set colors, shapes, elevations (called once on style change).
 * [startAnimation] — kick off any looping ValueAnimator (no-op by default).
 * [stopAnimation]  — cancel animators and release resources (no-op by default).
 */
interface ButtonStyleApplier {
    fun apply(
        plusBtn:    View,
        minusBtn:   View,
        plusLabel:  TextView,
        minusLabel: TextView,
        dp: (Number) -> Int,
    )

    fun startAnimation() {}
    fun stopAnimation()  {}
}
