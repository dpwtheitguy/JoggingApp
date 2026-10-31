package com.joggingapp.runprogram

import android.app.Activity
import android.content.Intent
import android.widget.ScrollView
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Bundle
import android.view.WindowManager
import android.view.WindowInsets
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.PI
import kotlin.math.sin

/** Debug variant only: continuous, locally synthesized audio to diagnose routing. */
class DebugAudioActivity : Activity() {
    private var track: AudioTrack? = null
    private var playing = true
    private lateinit var coach: CoachAudio
    private lateinit var status: TextView
    private lateinit var melodyButton: Button
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        playing = !intent.getBooleanExtra("cues", false)
        coach = CoachAudio(this) { status.text = "Playback interrupted or failed. Try the cue again; see RunProgramAudio in Logcat." }
        volumeControlStream = android.media.AudioManager.STREAM_MUSIC
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 64, 32, 32)
            setBackgroundColor(0xff101810.toInt())
        }
        layout.addView(TextView(this).apply {
            text = "Workout audio lab\n\nTest the real coaching clips or a continuous melody. Use Android media volume to adjust loudness.\n\nDebug build only. No workout progress is changed."
            textSize = 22f
            setTextColor(0xff00ff66.toInt())
        })
        melodyButton = Button(this).apply {
            text = if (playing) "Pause melody" else "Play melody"
            setOnClickListener {
                playing = !playing
                coach.stop()
                if (playing) startMelody() else stopMelody()
                text = if (playing) "Pause melody" else "Play melody"
            }
        }
        layout.addView(melodyButton)
        status = TextView(this).apply {
            text = "Choose a cue below."; textSize = 18f; setTextColor(0xffffffff.toInt())
        }
        layout.addView(status)
        val cues = linkedMapOf(
            "Warm up" to "warmup", "Resume warm-up" to "resume_warmup",
            "Run" to "run", "Walk" to "walk", "Halfway" to "halfway",
            "One minute remaining" to "minute", "Cool down" to "cooldown",
            "Resume cooldown" to "resume_cooldown", "Workout complete" to "complete",
            "Finished with skips" to "modified"
        )
        fun playCues(values: List<String>) {
            playing = false; melodyButton.text = "Play melody"; stopMelody(); coach.stop()
            status.text = "Playing: ${values.joinToString(", ")}"
            coach.finished = { status.text = "Playback finished. Did you hear the cue clearly?" }
            coach.say(values)
        }
        layout.addView(Button(this).apply {
            text = "Play all coaching cues"
            setOnClickListener { playCues(cues.values.toList()) }
        })
        cues.forEach { (label, cue) ->
            layout.addView(Button(this).apply {
                text = label
                setOnClickListener { playCues(listOf(cue)) }
            })
        }
        layout.addView(Button(this).apply {
            text = "Open workout app"
            setOnClickListener { startActivity(Intent(this@DebugAudioActivity, MainActivity::class.java)); finish() }
        })
        layout.addView(Button(this).apply {
            text = "Close sound test"
            setOnClickListener { finish() }
        })
        setContentView(ScrollView(this).apply {
            addView(layout)
            clipToPadding = false
            setOnApplyWindowInsetsListener { view, insets ->
                val bars = insets.getInsets(WindowInsets.Type.systemBars())
                view.setPadding(bars.left, 0, bars.right, bars.bottom)
                insets
            }
        })
    }
    override fun onResume() { super.onResume(); if (playing) startMelody() }
    override fun onPause() { coach.stop(); stopMelody(); super.onPause() }
    override fun onDestroy() { coach.stop(); stopMelody(); super.onDestroy() }
    private fun startMelody() {
        stopMelody()
        val rate = 24000
        val notes = doubleArrayOf(261.63, 329.63, 392.0, 523.25, 440.0, 392.0, 329.63, 293.66)
        val framesPerNote = rate / 2
        val samples = ShortArray(framesPerNote * notes.size) { i ->
            val t = (i % framesPerNote).toDouble() / rate
            val envelope = minOf(1.0, t / 0.02, (0.5 - t) / 0.04).coerceAtLeast(0.0)
            val phase = 2 * PI * notes[i / framesPerNote] * t
            ((sin(phase) + 0.2 * sin(phase * 2)) * envelope * 6000).toInt().toShort()
        }
        val next = AudioTrack.Builder()
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
            .setAudioFormat(AudioFormat.Builder().setSampleRate(rate)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
            .setTransferMode(AudioTrack.MODE_STATIC).setBufferSizeInBytes(samples.size * 2).build()
        check(next.write(samples, 0, samples.size) == samples.size)
        check(next.setLoopPoints(0, samples.size, -1) == AudioTrack.SUCCESS)
        track = next
        next.play()
    }
    private fun stopMelody() { track?.let { it.stop(); it.release() }; track = null }
}
