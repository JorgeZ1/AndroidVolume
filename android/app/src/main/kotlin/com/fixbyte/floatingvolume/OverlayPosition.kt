package com.fixbyte.floatingvolume

import kotlin.math.roundToInt

internal object OverlayPosition {
    /** Use the same margin-relative coordinate system before and after rotation. */
    fun rotatedY(y: Int, oldScreenHeight: Int, newScreenHeight: Int,
                 widgetHeight: Int, margin: Int): Int {
        val oldRange = (oldScreenHeight - widgetHeight - margin * 2).coerceAtLeast(1)
        val newRange = (newScreenHeight - widgetHeight - margin * 2).coerceAtLeast(0)
        val fraction = ((y - margin).toDouble() / oldRange).coerceIn(0.0, 1.0)
        return margin + (fraction * newRange).roundToInt()
    }
}
