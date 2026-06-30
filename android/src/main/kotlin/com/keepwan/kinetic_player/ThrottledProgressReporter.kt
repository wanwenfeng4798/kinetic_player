package com.keepwan.kinetic_player

class ThrottledProgressReporter(
    private val minIntervalMs: Long = 250L,
    private val emit: (positionMs: Long, durationMs: Long) -> Unit,
) {
    private var lastEmitMs = 0L

    fun report(positionMs: Long, durationMs: Long, force: Boolean = false) {
        val now = System.currentTimeMillis()
        if (force || now - lastEmitMs >= minIntervalMs) {
            lastEmitMs = now
            emit(positionMs, durationMs)
        }
    }

    fun reset() {
        lastEmitMs = 0L
    }
}
