package com.joggingapp.runprogram

import android.content.Intent
import android.os.SystemClock
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Explicit opt-in real-time test; skipped during the short regression suite. */
@RunWith(AndroidJUnit4::class)
class WorkoutSoakTest {
    @Test fun backgroundAndLockedScreenSoak() {
        val args = InstrumentationRegistry.getArguments()
        val seconds = args.getString("soakSeconds")?.toIntOrNull() ?: 0
        assumeTrue("Pass soakSeconds=900 for the fifteen-minute test", seconds in 60..1200)
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val db = CoachDatabase(context)
        val savedState = db.read("state")
        val savedRuntime = db.read("runtime")
        check(WorkoutService.current == null) { "End active workouts before testing" }
        fun shell(command: String) {
            instrumentation.uiAutomation.executeShellCommand(command).use {
                android.os.ParcelFileDescriptor.AutoCloseInputStream(it).readBytes()
            }
        }
        fun snapshot(): JSONObject? {
            var value: JSONObject? = null
            instrumentation.runOnMainSync { value = WorkoutService.current?.snapshot() }
            return value
        }
        try {
            val steps = JSONArray()
            var left = seconds
            var index = 0
            while (left > 0) {
                val length = minOf(60, left)
                val activity = if (index == 0) "warmup" else if (left <= 60) "cooldown" else if (index % 2 == 1) "run" else "walk"
                steps.put(JSONObject().put("activity", activity).put("seconds", length))
                left -= length; index++
            }
            val workout = JSONObject().put("id", "soak").put("week", 1).put("session", 1)
                .put("seconds", seconds).put("intervals", steps)
            val program = JSONObject().put("id", "soak-program").put("cursor", 0)
                .put("replay", JSONArray()).put("workouts", JSONArray().put(workout))
            db.write("state", JSONObject().put("programs", JSONArray().put(program))
                .put("history", JSONArray()).put("settings", JSONObject().put("voice", false)))
            db.write("runtime", JSONObject().put("attemptId", "soak-attempt").put("programId", "soak-program")
                .put("index", 0).put("mode", "normal").put("workout", workout).put("status", "paused").put("elapsedMs", 0))
            instrumentation.startActivitySync(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            instrumentation.runOnMainSync { context.startForegroundService(Intent(context, WorkoutService::class.java)) }
            val deadline = SystemClock.elapsedRealtime() + 12000
            while (snapshot()?.optString("status") != "running" && SystemClock.elapsedRealtime() < deadline) SystemClock.sleep(100)
            assertEquals("running", snapshot()!!.getString("status"))
            shell("input keyevent KEYCODE_HOME")
            shell("input keyevent KEYCODE_SLEEP")
            val wallStart = SystemClock.elapsedRealtime()
            val startElapsed = snapshot()!!.getLong("elapsedMs")
            var samples = 0
            while (SystemClock.elapsedRealtime() - wallStart < seconds * 1000L + 5000) {
                val current = snapshot()
                if (current == null || current.optString("status") == "completed") break
                assertEquals("running", current.getString("status"))
                val elapsed = current.getLong("elapsedMs")
                val expected = minOf(seconds * 1000L, startElapsed + SystemClock.elapsedRealtime() - wallStart)
                assertTrue("Monotonic elapsed diverged: $elapsed vs $expected", kotlin.math.abs(elapsed - expected) < 1000)
                if (samples++ % 10 == 0) Log.i("RunProgramSoak", "elapsedMs=$elapsed expectedMs=$expected status=running")
                SystemClock.sleep(1000)
            }
            val result = db.read("runtime")!!
            assertEquals("completed", result.getString("status"))
            assertEquals(seconds * 1000L, result.getLong("elapsedMs"))
            assertEquals(1, db.state().getJSONArray("history").length())
            assertEquals(1, db.state().getJSONArray("programs").getJSONObject(0).getInt("cursor"))
            Log.i("RunProgramSoak", "PASS durationSeconds=$seconds samples=$samples")
        } finally {
            shell("input keyevent KEYCODE_WAKEUP")
            shell("wm dismiss-keyguard")
            instrumentation.runOnMainSync { context.stopService(Intent(context, WorkoutService::class.java)) }
            val deadline = SystemClock.elapsedRealtime() + 5000
            while (WorkoutService.current != null && SystemClock.elapsedRealtime() < deadline) SystemClock.sleep(100)
            check(WorkoutService.current == null) { "Service cleanup failed; saved state not restored" }
            db.write("state", savedState); db.write("runtime", savedRuntime); db.close()
        }
    }
}
