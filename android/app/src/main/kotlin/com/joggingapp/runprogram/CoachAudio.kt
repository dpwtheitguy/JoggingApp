package com.joggingapp.runprogram

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.util.Log

class CoachAudio(private val context: Context, private val interrupted: () -> Unit) {
    private val manager = context.getSystemService(AudioManager::class.java)
    private var player: MediaPlayer? = null
    private var focus: AudioFocusRequest? = null
    private val queue = ArrayDeque<String>()
    var lastPlayedCue: String? = null; private set
    var enabled = true
    var duck = true
    var finished: (() -> Unit)? = null
    fun say(cues: List<String>) { if (!enabled) { finished?.invoke(); return }; queue.addAll(cues); if (player == null) playNext() }
    private fun playNext() {
        if (queue.isEmpty()) { releaseFocus(); finished?.invoke(); return }
        val cue = queue.removeFirst()
        // Workout coaching is spoken media, not turn-by-turn navigation. Media
        // usage also permits Android playback capture for screen/audio testing.
        val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()
        val request = AudioFocusRequest.Builder(if (duck) AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK else AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            .setAudioAttributes(attributes).setOnAudioFocusChangeListener { change ->
                Log.d("RunProgramAudio", "focus changed: $change")
                if (change == AudioManager.AUDIOFOCUS_LOSS || change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT || change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK) { stop(); interrupted() }
            }.build()
        if (focus == null) {
            focus = request
            if (manager.requestAudioFocus(request) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { stop(); interrupted(); return }
        }
        // Explicit references are essential: release resource shrinking removes
        // clips referenced only through generated getIdentifier names.
        val id = when (cue) {
            "warmup" -> R.raw.cue_warmup
            "resume_warmup" -> R.raw.cue_resume_warmup
            "run" -> R.raw.cue_run
            "walk" -> R.raw.cue_walk
            "halfway" -> R.raw.cue_halfway
            "minute" -> R.raw.cue_minute
            "cooldown" -> R.raw.cue_cooldown
            "resume_cooldown" -> R.raw.cue_resume_cooldown
            "complete" -> R.raw.cue_complete
            "modified" -> R.raw.cue_modified
            else -> 0
        }
        if (id == 0) { stop(); interrupted(); return }
        try {
            val p = MediaPlayer()
            player = p
            p.setAudioAttributes(attributes)
            context.resources.openRawResourceFd(id).use { p.setDataSource(it.fileDescriptor, it.startOffset, it.length) }
            p.setOnCompletionListener { Log.d("RunProgramAudio", "cue finished: $cue"); player = null; it.release(); playNext() }
            p.setOnErrorListener { _, what, extra -> Log.e("RunProgramAudio", "cue failed: $cue what=$what extra=$extra"); stop(); interrupted(); true }
            p.prepare(); p.start(); lastPlayedCue = cue
            Log.d("RunProgramAudio", "cue started: $cue")
        } catch (error: Exception) { Log.e("RunProgramAudio", "cue exception: $cue", error); stop(); interrupted() }
    }
    private fun releaseFocus() { focus?.let { manager.abandonAudioFocusRequest(it) }; focus = null }
    fun stop() { queue.clear(); player?.release(); player = null; releaseFocus() }
}
