package com.joggingapp.runprogram

/** UI-independent engine. All times are monotonic milliseconds; callbacks never count time. */
class IntervalEngine(val intervals: List<Step>, elapsed: Long = 0, initialStatus: String = "paused", skipped: Long = 0) {
    data class Step(val activity: String, val seconds: Int)
    val total = intervals.sumOf { it.seconds.toLong() * 1000 }
    var skippedMs = skipped.coerceIn(0, total); private set
    var committed = elapsed.coerceIn(0, total - skippedMs); private set
    var status = initialStatus; private set
    private var anchor = 0L
    private var observed = committed + skippedMs
    private val emitted = mutableSetOf<String>()
    init { require(intervals.isNotEmpty() && intervals.all { it.seconds > 0 && it.activity in setOf("warmup", "run", "walk", "cooldown") }) }
    fun elapsed(now: Long): Long = (committed + if (status == "running") (now - anchor).coerceAtLeast(0) else 0).coerceAtMost(total - skippedMs)
    fun position(now: Long): Long = elapsed(now) + skippedMs
    fun indexAt(value: Long): Int {
        var sum = 0L
        intervals.forEachIndexed { index, step -> sum += step.seconds * 1000L; if (value < sum) return index }
        return intervals.lastIndex
    }
    fun remaining(now: Long): Long {
        val value = position(now)
        return (intervals.take(indexAt(value) + 1).sumOf { it.seconds * 1000L } - value).coerceAtLeast(0)
    }
    fun resume(now: Long): String {
        check(status == "paused" || status == "interrupted")
        status = "running"; anchor = now; observed = committed + skippedMs
        return intervals[indexAt(committed + skippedMs)].activity
    }
    fun pause(now: Long) { if (status == "running") { committed = elapsed(now); status = "paused"; observed = committed + skippedMs } }
    fun stop(now: Long) { committed = elapsed(now); status = "stopped" }
    fun skip(now: Long): List<String> {
        check(status == "running" || status == "paused" || status == "interrupted")
        val active = elapsed(now)
        val rest = remaining(now)
        committed = active
        skippedMs += rest
        anchor = now
        observed = committed + skippedMs
        if (observed >= total) { status = "completed"; return listOf(if (skippedMs > 0) "modified" else "complete") }
        return listOf(intervals[indexAt(observed)].activity)
    }
    fun advance(now: Long, halfway: Boolean = true, warning: Boolean = true): List<String> {
        if (status != "running") return emptyList()
        val value = position(now)
        val previous = observed
        observed = value
        if (value >= total) { committed = total - skippedMs; status = "completed"; return listOf(if (skippedMs > 0) "modified" else "complete") }
        val cues = mutableListOf<String>()
        val index = indexAt(value)
        if (indexAt(previous) != index) cues.add(intervals[index].activity)
        // A delayed callback must never speak obsolete milestones or interval transitions.
        val late = value - previous > 2000
        if (skippedMs == 0L && halfway && previous < total / 2 && value >= total / 2 && emitted.add("halfway") && !late) cues.add("halfway")
        if (skippedMs == 0L && warning && previous < total - 60000 && value >= total - 60000 && total > 60000 && emitted.add("minute") && !late) cues.add("minute")
        return cues
    }
}
