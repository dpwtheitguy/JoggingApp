package com.joggingapp.runprogram

import android.app.*
import android.content.*
import android.content.pm.ServiceInfo
import android.os.*
import org.json.JSONObject

class WorkoutService : Service() {
    companion object { var current: WorkoutService? = null; private set }
    private lateinit var db: CoachDatabase
    private lateinit var audio: CoachAudio
    private var engine: IntervalEngine? = null
    private var payload: JSONObject? = null
    private val handler = Handler(Looper.getMainLooper())
    private var wake: PowerManager.WakeLock? = null
    private var lastCheckpoint = 0L
    private var lastNotification = -1L
    private val noisy = object : BroadcastReceiver() { override fun onReceive(c: Context?, i: Intent?) { pause("Headphones disconnected. Resume when ready.") } }
    override fun onCreate() {
        super.onCreate(); current = this; db = CoachDatabase(this)
        audio = CoachAudio(this) { pause("Audio was interrupted. Resume when ready.") }
        val filter = IntentFilter(android.media.AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(noisy, filter, RECEIVER_NOT_EXPORTED) else registerReceiver(noisy, filter)
        getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel("workout", "Workout coaching", NotificationManager.IMPORTANCE_LOW))
    }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "pause") { pause(); return START_NOT_STICKY }
        if (intent?.action == "resume" && engine != null) { resume(); return START_NOT_STICKY }
        try {
            handler.removeCallbacksAndMessages(null)
            audio.finished = null; audio.stop(); releaseWake()
            val data = db.read("runtime") ?: error("No workout to start")
            payload = data
            val steps = data.getJSONObject("workout").getJSONArray("intervals")
            engine = IntervalEngine((0 until steps.length()).map { val s = steps.getJSONObject(it); IntervalEngine.Step(s.getString("activity"), s.getInt("seconds")) }, data.optLong("elapsedMs"))
            val notification = notification()
            if (Build.VERSION.SDK_INT >= 34) startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE) else startForeground(1, notification)
            resume()
        } catch (e: Exception) {
            db.read("runtime")?.let { db.write("runtime", it.put("status", "interrupted").put("message", "Workout could not start: ${e.message}")) }
            stopSelf()
        }
        return START_NOT_STICKY
    }
    fun dismissFinished() {
        if (engine?.status !in setOf("completed", "stopped")) return
        handler.removeCallbacksAndMessages(null)
        audio.finished = null; audio.stop(); releaseWake()
        engine = null; payload = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        handler.postDelayed({ stopSelf() }, 500)
    }
    fun lastAudioCue(): String? = audio.lastPlayedCue
    fun applySettings() {
        val prefs = db.state().optJSONObject("settings") ?: JSONObject()
        audio.enabled = prefs.optBoolean("voice", true); audio.duck = prefs.optBoolean("duck", true)
        if (!audio.enabled) audio.stop()
    }
    fun snapshot(): JSONObject? {
        val data = payload ?: return null
        val e = engine ?: return data
        val now = SystemClock.elapsedRealtime()
        data.put("elapsedMs", e.elapsed(now)).put("status", e.status).put("intervalIndex", e.indexAt(e.elapsed(now)))
            .put("remainingMs", e.remaining(now)).put("totalMs", e.total)
        return JSONObject(data.toString())
    }
    private fun checkpoint() { snapshot()?.let { db.write("runtime", it) }; lastCheckpoint = SystemClock.elapsedRealtime() }
    fun pause(message: String? = null) {
        val e = engine ?: return
        if (e.status != "running") return
        e.pause(SystemClock.elapsedRealtime()); audio.stop(); releaseWake()
        if (message != null) payload?.put("message", message)
        checkpoint(); notifyPlayer()
    }
    fun resume() {
        val e = engine ?: return
        if (e.status !in setOf("paused", "interrupted")) return
        val prefs = db.state().optJSONObject("settings") ?: JSONObject()
        audio.enabled = prefs.optBoolean("voice", true); audio.duck = prefs.optBoolean("duck", true)
        payload?.remove("message")
        val cue = e.resume(SystemClock.elapsedRealtime())
        wake = getSystemService(PowerManager::class.java).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "runprogram:workout").also { it.acquire(e.total + 300000) }
        val spokenCue = if (e.committed > 0 && cue in setOf("warmup", "cooldown")) "resume_$cue" else cue
        checkpoint(); audio.say(listOf(spokenCue)); handler.removeCallbacks(tick); handler.post(tick)
    }
    fun stopWorkout() {
        val e = engine ?: return
        if (e.status in setOf("completed", "stopped")) return
        e.stop(SystemClock.elapsedRealtime()); audio.stop(); releaseWake()
        payload?.let { db.finish(it, "stopped", e.elapsed(SystemClock.elapsedRealtime())) }
        stopForeground(STOP_FOREGROUND_REMOVE); stopSelf()
    }
    private val tick = object : Runnable {
        override fun run() {
            val e = engine ?: return
            if (e.status != "running") return
            val now = SystemClock.elapsedRealtime()
            val prefs = db.state().optJSONObject("settings") ?: JSONObject()
            audio.enabled = prefs.optBoolean("voice", true); audio.duck = prefs.optBoolean("duck", true)
            val cues = e.advance(now, prefs.optBoolean("halfway", true), prefs.optBoolean("warning", true))
            if (e.status == "completed") {
                releaseWake()
                payload?.let { db.finish(it, "completed", e.total) }
                audio.finished = { stopForeground(STOP_FOREGROUND_REMOVE); stopSelf() }
                audio.stop(); audio.say(cues)
                // Avoid holding a foreground service indefinitely if playback never finishes.
                handler.postDelayed({ stopForeground(STOP_FOREGROUND_REMOVE); stopSelf() }, 15000)
                return
            }
            if (cues.isNotEmpty()) {
                if (cues.any { it in setOf("run", "walk", "cooldown", "warmup") }) audio.stop()
                if (prefs.optBoolean("vibration", false)) {
                    val vibrator = getSystemService(android.os.Vibrator::class.java)
                    vibrator.vibrate(VibrationEffect.createOneShot(180, VibrationEffect.DEFAULT_AMPLITUDE))
                }
                audio.say(cues); checkpoint()
            } else if (now - lastCheckpoint >= 5000) checkpoint()
            if (now / 1000 != lastNotification) { lastNotification = now / 1000; notifyPlayer() }
            handler.postDelayed(this, 250)
        }
    }
    private fun releaseWake() { wake?.let { if (it.isHeld) it.release() }; wake = null }
    private fun notification(): Notification {
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val e = engine
        val now = SystemClock.elapsedRealtime()
        val remaining = ((e?.remaining(now) ?: 0) + 999) / 1000
        val activity = e?.let { it.intervals[it.indexAt(it.elapsed(now))].activity.uppercase() } ?: "READY"
        val pause = e?.status == "running"
        val control = PendingIntent.getService(this, if (pause) 1 else 2, Intent(this, WorkoutService::class.java).setAction(if (pause) "pause" else "resume"), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return Notification.Builder(this, "workout").setSmallIcon(R.drawable.ic_runprogram)
            .setContentTitle("RUN//PROGRAM · ${e?.status?.uppercase() ?: "READY"}")
            .setContentText("$activity · ${remaining / 60}:${(remaining % 60).toString().padStart(2, '0')}")
            .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true)
            .addAction(Notification.Action.Builder(null, if (pause) "Pause" else "Resume", control).build())
            .addAction(Notification.Action.Builder(null, "End / open controls", open).build()).build()
    }
    private fun notifyPlayer() { getSystemService(NotificationManager::class.java).notify(1, notification()) }
    override fun onDestroy() {
        if (engine?.status == "running") { engine?.pause(SystemClock.elapsedRealtime()); payload?.put("status", "interrupted"); checkpoint() }
        handler.removeCallbacksAndMessages(null); audio.stop(); releaseWake(); unregisterReceiver(noisy)
        current = null; db.close(); super.onDestroy()
    }
}
