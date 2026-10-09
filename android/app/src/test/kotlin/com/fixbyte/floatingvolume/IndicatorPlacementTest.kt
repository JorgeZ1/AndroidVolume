package com.fixbyte.floatingvolume

import org.junit.Assert.*
import org.junit.Test

class IndicatorPlacementTest {
    private fun place(bounds: OverlayRect, buttons: OverlayRect, width: Int = 36,
                      height: Int = 135, gap: Int = 10) =
        IndicatorPlacement.calculate(bounds, buttons, width, height, gap, 8, 24)

    private fun assertSafe(bounds: OverlayRect, controls: OverlayRect, result: OverlayRect) {
        assertTrue(result.left >= bounds.left + 8 && result.right <= bounds.right - 8)
        assertTrue(result.top >= bounds.top + 8 && result.bottom <= bounds.bottom - 8)
        assertTrue(result.right <= controls.left || result.left >= controls.right)
    }

    @Test fun portraitPositionsAreSymmetric() {
        val bounds = OverlayRect(0, 24, 360, 752)
        val left = OverlayRect(0, 200, 44, 298)
        val right = OverlayRect(316, 200, 360, 298)
        val a = place(bounds, left)!!
        val b = place(bounds, right)!!
        assertEquals(54, a.left)
        assertEquals(270, b.left)
        assertEquals(a.top, b.top)
        assertSafe(bounds, left, a)
        assertSafe(bounds, right, b)
    }

    @Test fun landscapeNavigationAndCutoutDoNotShiftGap() {
        val bounds = OverlayRect(30, 24, 732, 340)
        val buttons = OverlayRect(688, 100, 732, 198)
        val result = place(bounds, buttons)!!
        assertEquals(10, buttons.left - result.right)
        assertSafe(bounds, buttons, result)
    }

    @Test fun oversizedIndicatorIsTemporarilyClamped() {
        val bounds = OverlayRect(0, 0, 200, 120)
        val buttons = OverlayRect(0, 20, 100, 110)
        val result = place(bounds, buttons, 100, 300, 50)!!
        assertEquals(92, result.width)
        assertEquals(104, result.height)
        assertSafe(bounds, buttons, result)
    }

    @Test fun zeroGapStillDoesNotOverlap() {
        val bounds = OverlayRect(0, 0, 360, 780)
        val buttons = OverlayRect(316, 200, 360, 298)
        val result = place(bounds, buttons, gap = 0)!!
        assertEquals(buttons.left, result.right)
        assertSafe(bounds, buttons, result)
    }

    @Test fun impossibleSlotDoesNotCoverButtons() {
        assertNull(place(OverlayRect(0, 0, 100, 100), OverlayRect(10, 10, 90, 90)))
    }

    @Test fun staleCoordinatesDuringRotationStayInsideNewBounds() {
        val bounds = OverlayRect(0, 24, 360, 752)
        val oldControls = OverlayRect(688, 100, 732, 198)
        assertSafe(bounds, oldControls, place(bounds, oldControls)!!)
    }

    @Test fun screenMatrixNeverOverlapsOrExceedsSafeBounds() {
        for ((w, h) in listOf(360 to 780, 780 to 360, 320 to 480, 480 to 320, 800 to 1280)) {
            for (inset in listOf(0, 24, 48)) for (size in listOf(36, 44, 80, 100)) {
                val bounds = OverlayRect(inset, 24, w - inset, h - 24)
                for (right in listOf(false, true)) for (gap in listOf(0, 10, 50)) {
                    val x = if (right) bounds.right - size else bounds.left
                    val buttons = OverlayRect(x, 40, x + size, 40 + size * 2 + 10)
                    val result = place(bounds, buttons, 100, 300, gap) ?: continue
                    assertSafe(bounds, buttons, result)
                }
            }
        }
    }
}
