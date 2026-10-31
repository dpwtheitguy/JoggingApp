package com.joggingapp.runprogram

object ProgressPolicy {
    data class Cursor(val next: Int, val replay: List<Int>)
    fun complete(cursor: Cursor, index: Int, mode: String): Cursor = when (mode) {
        "normal" -> cursor.copy(next = if (cursor.next == index) index + 1 else cursor.next)
        "week" -> Cursor(if (cursor.next == index) index + 1 else cursor.next,
            if (cursor.replay.firstOrNull() == index) cursor.replay.drop(1) else cursor.replay)
        else -> cursor
    }
    fun repeatWeek(next: Int, total: Int): List<Int> {
        require(total > 0 && total % 3 == 0 && next in 0..total)
        val first = (if (next > 0 && next % 3 == 0) next - 1 else next).coerceAtMost(total - 1) / 3 * 3
        return (first..first + 2).toList()
    }
}
