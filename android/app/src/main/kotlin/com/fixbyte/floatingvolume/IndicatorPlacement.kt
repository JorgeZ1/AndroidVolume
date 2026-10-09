package com.fixbyte.floatingvolume

/** All coordinates are screen coordinates, with exclusive right/bottom edges. */
internal data class OverlayRect(val left: Int, val top: Int, val right: Int, val bottom: Int) {
    val width get() = right - left
    val height get() = bottom - top
}

internal object IndicatorPlacement {
    /** Returns null rather than cover the controls when no usable side remains. */
    fun calculate(
        available: OverlayRect,
        controls: OverlayRect,
        requestedWidth: Int,
        requestedHeight: Int,
        requestedGap: Int,
        margin: Int,
        minimumWidth: Int,
    ): OverlayRect? {
        val left = available.left + margin
        val right = available.right - margin
        val top = available.top + margin
        val bottom = available.bottom - margin
        if (right <= left || bottom <= top) return null
        // Old overlay coordinates can briefly outlive a rotation's new bounds.
        val rightStart = controls.right.coerceAtLeast(left)
        val leftEnd = controls.left.coerceAtMost(right)
        val rightRoom = (right - rightStart).coerceAtLeast(0)
        val leftRoom = (leftEnd - left).coerceAtLeast(0)
        val preferRight = controls.left + controls.width / 2 < available.left + available.width / 2
        val desiredWidth = requestedWidth.coerceAtLeast(minimumWidth)
        val placeRight = when {
            preferRight && rightRoom >= desiredWidth -> true
            !preferRight && leftRoom >= desiredWidth -> false
            rightRoom >= desiredWidth -> true
            leftRoom >= desiredWidth -> false
            else -> rightRoom >= leftRoom
        }
        val room = if (placeRight) rightRoom else leftRoom
        if (room < minimumWidth) return null
        val width = desiredWidth.coerceAtMost(room)
        val height = requestedHeight.coerceIn(1, bottom - top)
        val gap = requestedGap.coerceIn(0, room - width)
        val x = if (placeRight) rightStart + gap else leftEnd - gap - width
        val y = (controls.top + controls.height / 2 - height / 2).coerceIn(top, bottom - height)
        return OverlayRect(x, y, x + width, y + height)
    }
}
