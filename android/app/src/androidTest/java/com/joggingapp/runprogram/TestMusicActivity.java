package com.joggingapp.runprogram;

import android.app.Activity;
import android.content.Intent;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.os.Bundle;
import android.os.Process;
import android.widget.TextView;

/** Separate-UID test APK activity. Java keeps it independent of the target's Kotlin runtime. */
public class TestMusicActivity extends Activity {
    public static final String ACTION = "com.joggingapp.runprogram.TEST_MUSIC_STATE";
    public static final String STOP = "com.joggingapp.runprogram.STOP_TEST_MUSIC";
    private AudioTrack track;
    private AudioFocusRequest request;
    private AudioManager manager;
    private TextView label;
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        manager = getSystemService(AudioManager.class);
        label = new TextView(this);
        label.setText("Separate-app audio fixture"); label.setTextSize(24);
        setContentView(label);
        if (STOP.equals(getIntent().getAction())) { finish(); return; }
        getWindow().getDecorView().postDelayed(() -> { if (!isFinishing()) startAudio(); }, 500);
    }
    private void report(String state, int focus) {
        label.setText("Separate-app audio fixture\n" + state);
        sendBroadcast(new Intent(ACTION).setPackage("com.joggingapp.runprogram")
            .putExtra("state", state).putExtra("uid", Process.myUid()).putExtra("focus", focus)
            .putExtra("playState", track == null ? AudioTrack.PLAYSTATE_STOPPED : track.getPlayState()));
    }
    private void startAudio() {
        AudioAttributes attributes = new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build();
        request = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).setAudioAttributes(attributes)
            .setWillPauseWhenDucked(true).setOnAudioFocusChangeListener(change -> {
                if (change == AudioManager.AUDIOFOCUS_GAIN) {
                    if (track != null) track.play(); report("resumed", change);
                } else if (change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK ||
                           change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT || change == AudioManager.AUDIOFOCUS_LOSS) {
                    if (track != null) track.pause(); report("paused", change);
                }
            }).build();
        if (manager.requestAudioFocus(request) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            report("focus_denied", 0); return;
        }
        int rate = 24000;
        short[] samples = new short[rate * 2];
        for (int i = 0; i < samples.length; i++) {
            double frequency = i < rate ? 261.63 : 329.63;
            samples[i] = (short)(Math.sin(2 * Math.PI * frequency * i / rate) * 3500);
        }
        track = new AudioTrack.Builder().setAudioAttributes(attributes)
            .setAudioFormat(new AudioFormat.Builder().setSampleRate(rate)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
            .setTransferMode(AudioTrack.MODE_STATIC).setBufferSizeInBytes(samples.length * 2).build();
        if (track.write(samples, 0, samples.length) != samples.length) throw new IllegalStateException("Audio write failed");
        if (track.setLoopPoints(0, samples.length, -1) != AudioTrack.SUCCESS) throw new IllegalStateException("Audio loop failed");
        track.play(); report("playing", 0);
    }
    @Override public void onNewIntent(Intent intent) { super.onNewIntent(intent); if (STOP.equals(intent.getAction())) finish(); }
    @Override public void onDestroy() {
        if (track != null) { track.stop(); track.release(); track = null; }
        if (request != null) { manager.abandonAudioFocusRequest(request); request = null; }
        report("stopped", 0);
        super.onDestroy();
    }
}
