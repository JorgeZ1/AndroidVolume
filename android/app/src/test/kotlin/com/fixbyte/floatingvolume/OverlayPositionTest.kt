package com.fixbyte.floatingvolume

import org.junit.Assert.assertEquals
import org.junit.Test

class OverlayPositionTest {
    @Test fun snappingWithoutRotationDoesNotMoveVertically() {
        for (y in 16..1084) {
            assertEquals(y, OverlayPosition.rotatedY(y, 1280, 1280, 180, 16))
        }
    }

    @Test fun repeatedRotationDoesNotAccumulateDrift() {
        for (initial in listOf(16, 250, 786, 1084)) {
            var y = initial
            repeat(100) {
                y = OverlayPosition.rotatedY(y, 1280, 720, 180, 16)
                y = OverlayPosition.rotatedY(y, 720, 1280, 180, 16)
            }
            assertEquals(initial.toDouble(), y.toDouble(), 1.0)
        }
    }

    @Test fun positionsOutsideBoundsAreClamped() {
        assertEquals(16, OverlayPosition.rotatedY(-100, 1280, 720, 180, 16))
        assertEquals(524, OverlayPosition.rotatedY(2000, 1280, 720, 180, 16))
        assertEquals(16, OverlayPosition.rotatedY(2000, 1280, 100, 180, 16))
    }
}
