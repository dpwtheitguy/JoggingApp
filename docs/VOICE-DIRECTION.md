# Production coaching voice

The current eSpeak recordings are development placeholders. The user rejected
that voice quality during listening on October 30, 2026. Audible playback is
verified; voice quality is not accepted for production.

Direction: natural, calm, confident female delivery with a restrained,
futuristic assistant character. The user's reference points are Cortana and
the Star Trek computer. Select a licensed stock voice based on those general
qualities; no actor imitation or voice cloning is required.

Audition ElevenLabs first and Azure neural/HD voices second; Google Chirp 3 HD
is another candidate. Compare the same phrases at workout volume, with music
underneath. Provider quality is a listening decision, not a documentation claim.

- https://elevenlabs.io/text-to-speech
- https://elevenlabs.io/pricing (commercial license listed on paid plans)
- https://learn.microsoft.com/azure/ai-services/speech-service/language-support?tabs=tts
- https://docs.cloud.google.com/text-to-speech/docs/chirp3-hd

Generate approved clips during development and bundle them for offline playback.
Keep provider credentials on the development machine, outside source control
and the APK. No runtime account, network connection or per-workout synthesis
is needed for the existing fixed cue set. Save the selected voice/model/settings,
text, provider, generation date and applicable usage rights with final assets.
No provider account has been purchased or service generation performed yet.

Use the ten existing cue texts in scripts/generate-coaching-audio.py as a baseline.
Audition a short set first: warm-up, run, walk, halfway and completion. Review
pacing, clarity over music and whether frequent repetitions become irritating.
Then generate every cue consistently, inspect leading/trailing silence and
relative loudness, and recheck optimized APK asset retention. Do not overwrite
approved recordings by rerunning the prototype eSpeak generator.

Production gate: replace placeholder audio with a human-approved voice and
verify all cues, music/podcast ducking, interruptions and physical-device output.
