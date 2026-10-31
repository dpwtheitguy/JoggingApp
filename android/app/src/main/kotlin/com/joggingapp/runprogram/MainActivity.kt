package com.joggingapp.runprogram

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "runprogram/coach").setMethodCallHandler { call, result ->
            val db = CoachDatabase(this)
            try {
                val args = if (call.arguments is Map<*, *>) JSONObject(call.arguments as Map<*, *>) else JSONObject()
                when (call.method) {
                    "snapshot" -> {
                        val runtime = WorkoutService.current?.snapshot() ?: db.recoverRuntime()
                        result.success(JSONObject().put("state", db.state()).put("runtime", runtime ?: JSONObject.NULL).toString())
                    }
                    "newProgram" -> {
                        val runtime = db.read("runtime")
                        require(runtime == null || runtime.optString("status") in setOf("completed", "stopped", "modified", "modified_confirmed")) { "End the current workout before changing programs." }
                        WorkoutService.current?.dismissFinished()
                        require(args.getJSONArray("workouts").length() > 0)
                        val state = db.state(); state.getJSONArray("programs").put(args)
                        db.write("state", state); db.write("runtime", null); result.success(null)
                    }
                    "settings" -> { val state = db.state(); state.put("settings", args); db.write("state", state); WorkoutService.current?.applySettings(); result.success(null) }
                    "pauseTraining", "repeatWeek" -> {
                        val runtime = db.read("runtime")
                        require(runtime == null || runtime.optString("status") in setOf("completed", "stopped", "modified", "modified_confirmed"))
                        val state = db.state(); val programs = state.getJSONArray("programs")
                        val p = programs.getJSONObject(programs.length() - 1)
                        if (call.method == "pauseTraining") p.put("paused", args.getBoolean("paused"))
                        else {
                            val count = p.getJSONArray("workouts").length()
                            val cursor = p.getInt("cursor")
                            p.put("replay", org.json.JSONArray(ProgressPolicy.repeatWeek(cursor, count)))
                        }
                        db.write("state", state); result.success(null)
                    }
                    "start" -> {
                        val old = db.read("runtime")
                        require(old == null || old.optString("status") in setOf("completed", "stopped", "modified", "modified_confirmed")) { "A workout is already active." }
                        val steps = args.getJSONObject("workout").getJSONArray("intervals")
                        require(steps.length() in 1..200)
                        var total = 0L
                        for (i in 0 until steps.length()) { val s = steps.getJSONObject(i); require(s.getString("activity") in setOf("run", "walk", "warmup", "cooldown")); require(s.getInt("seconds") in 1..14400); total += s.getInt("seconds") }
                        require(total <= 21600)
                        args.put("attemptId", java.util.UUID.randomUUID().toString()).put("elapsedMs", 0).put("status", "paused")
                        db.write("runtime", args)
                        launchService(); result.success(null)
                    }
                    "skip" -> { val service = WorkoutService.current ?: error("Resume the interrupted workout before skipping."); service.skipInterval(); result.success(null) }
                    "acceptModified" -> { db.acceptModified(args.getString("attemptId")); result.success(null) }
                    "pause" -> { WorkoutService.current?.pause(); result.success(null) }
                    "resume" -> {
                        val data = db.read("runtime") ?: error("No interrupted workout to resume")
                        require(data.getString("status") in setOf("paused", "interrupted", "running"))
                        if (WorkoutService.current != null) WorkoutService.current?.resume() else launchService()
                        result.success(null)
                    }
                    "end" -> {
                        if (WorkoutService.current != null) WorkoutService.current?.stopWorkout()
                        else db.read("runtime")?.let { db.finish(it, "stopped", it.optLong("elapsedMs")) }
                        result.success(null)
                    }
                    "reportedDistance" -> {
                        val km = args.getDouble("km"); require(km.isFinite() && km > 0 && km <= 200)
                        val state = db.state(); val history = state.getJSONArray("history")
                        val match = (0 until history.length()).map { history.getJSONObject(it) }.firstOrNull { it.getString("id") == args.getString("attemptId") && it.getString("status") == "completed" }
                            ?: error("Completed attempt not found")
                        match.put("reportedKm", km); db.write("state", state); result.success(null)
                    }
                    "dismiss" -> {
                        val r = db.read("runtime")
                        require(r == null || r.getString("status") in setOf("completed", "stopped", "modified", "modified_confirmed"))
                        WorkoutService.current?.dismissFinished()
                        db.write("runtime", null); result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("COACH_ERROR", e.message ?: "Workout operation failed", null) }
            finally { db.close() }
        }
    }
    private fun launchService() {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 20)
        startForegroundService(Intent(this, WorkoutService::class.java))
    }
}
