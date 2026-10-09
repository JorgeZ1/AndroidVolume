package com.fixbyte.floatingvolume

import org.junit.Assert.*
import org.junit.Test

class DiagnosticJournalTest {
    @Test fun boundedHistoryAndLocalIds() {
        val journal = DiagnosticJournal { 100L }
        for (id in 1L..100L) assertEquals(id, journal.begin(DiagnosticOperation.OVERLAY_ADD))
        assertEquals(30, journal.snapshot().size)
        assertTrue(journal.snapshot().first().contains("id=71"))
    }
    @Test fun repeatedErrorsHaveCooldownAndBoundedMemory() {
        var now = 0L
        val journal = DiagnosticJournal { now }
        assertTrue(journal.allowError("overlay"))
        assertFalse(journal.allowError("overlay"))
        now = 60_000L
        assertTrue(journal.allowError("overlay"))
        for (id in 0..64) journal.allowError("c$id")
        assertTrue(journal.allowError("c0"))
    }
    @Test fun privacyAllowlistRejectsArbitraryTextAndIdentifiers() {
        assertFalse(DiagnosticJournal.state("email", "email@example.com"))
        assertFalse(DiagnosticJournal.state("widget_style", "private_report"))
        assertFalse(DiagnosticJournal.state("window_kind", "https://example.com"))
        assertFalse(DiagnosticJournal.state("volume_actual", "-100"))
        assertTrue(DiagnosticJournal.state("volume_confirmed", "3"))
        assertTrue(DiagnosticJournal.state("widget_style", "ANDROID_12"))
        assertTrue(DiagnosticJournal.state("activity_state", "paused"))
        assertEquals("native_error", DiagnosticJournal.category("private error text"))
    }
    @Test fun snapshotsDoNotExposeMutableHistory() {
        val journal = DiagnosticJournal { 0 }
        journal.begin(DiagnosticOperation.SNAP)
        val copy = journal.snapshot().toMutableList()
        copy.clear()
        assertEquals(1, journal.snapshot().size)
    }
}
