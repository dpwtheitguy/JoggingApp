package com.joggingapp.runprogram

/** Only the next scheduled/replay slot or an explicitly repeated past day may start. */
object StartPolicy {
    fun validate(index: Int, total: Int, cursor: Int, replay: List<Int>, mode: String, paused: Boolean) {
        require(!paused) { "Resume your training program from Home before starting a workout." }
        require(index in 0 until total) { "Workout is not part of this program." }
        require(cursor in 0..total)
        when (mode) {
            "normal" -> require(index == cursor && replay.isEmpty()) { "Start the next workout shown on Home." }
            "week" -> require(replay.firstOrNull() == index) { "Start the next day of your repeated week from Home." }
            "repeat" -> require(index <= cursor) { "Finish the earlier scheduled days before repeating this workout." }
            else -> error("Unknown workout start mode.")
        }
    }
}
