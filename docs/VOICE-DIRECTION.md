# Coaching voice: Kokoro Heart

The user selected **Heart (`af_heart`)** from three locally generated stock-voice
samples on November 3, 2026. It replaces all ten rejected eSpeak recordings.
The direction is calm, natural, confident female coaching with a polished
assistant feel. No Cortana recording, actor imitation or voice cloning is used.

## Assets and rights

- Model: [hexgrad/Kokoro-82M v1.0](https://huggingface.co/hexgrad/Kokoro-82M),
  Apache 2.0 model weights; stock voice `af_heart`.
- CPU export and stock embeddings: [kokoro-onnx model-files-v1.1](https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.1).
  Downloaded files matched the SHA-256 digests published by that release.
- Development generator: [kokoro-onnx](https://github.com/thewh1teagle/kokoro-onnx)
  0.6.1, MIT. License texts are preserved under docs/licenses/.
- Original cue text, model hashes, voice, speed, output durations and each WAV's
  SHA-256 are recorded in [coaching-manifest.json](audio/coaching-manifest.json).
- Original auditions: [Heart](audio/audition-af_heart.wav),
  [Bella](audio/audition-af_bella.wav), [Sarah](audio/audition-af_sarah.wav).

Only the finished mono 24 kHz PCM16 recordings are bundled. Neither model weights
nor inference libraries are shipped in the app. Coaching requires no account,
network, online TTS service, voice download or recurring service payment.
The model card describes permissive training data and stock voice characteristics;
these are upstream statements, not an independent audit of its training corpus.

## Reproduce

Use a project-local Python 3.12 environment with scripts/voice-requirements.txt.
The local setup uses the ignored .local-tools/voice/venv directory. Download
kokoro-v1.0.onnx and voices-v1.0.bin from the release linked above into
.local-tools/voice/. The generator verifies their pinned hashes before loading.
Host libespeak-ng is used only for text-to-phoneme conversion; the neural model,
not eSpeak synthesis, produces the new waveform.

```bash
.local-tools/voice/venv/bin/python scripts/generate-coaching-audio.py --voice af_heart
source scripts/dev-env.sh
RUNPROGRAM_DEVELOPMENT_SIGNING=1 flutter build apk --release
python3 scripts/check-audio-assets.py
```

Generation uses CPU only with two intra-op threads and one inter-op thread.
Speed is 0.96. Outer silence is trimmed at -45 dBFS with 20 ms margins; clips
have 80 ms leading and 120 ms trailing padding and peaks normalized to -1.5 dBFS.
The generator stages the full set before copying recordings to the Android
resources directory. Do not regenerate approved assets casually: a tool/model
change can change the voice. Check all ten outputs and audition after changes.

## Validation limits

The Heart direction is user-selected. Audio format, non-silence, peak/headroom,
outer silence, provenance hashes and optimized APK retention are checked by
scripts/check-audio-assets.py. Android playback and listening results for this
replacement are recorded in VALIDATION.md. Physical headset, music/podcast,
call-interruption and battery checks remain release work as previously documented.
