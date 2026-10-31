"""Generate bundled offline prototype cues using the host's eSpeak NG library.
No network service or AI model; generated speech output is original application content.
Run with Python 3 on a host with libespeak-ng.so.1 and its voice data installed.
"""
import ctypes as c
from pathlib import Path
import wave

lib = c.CDLL('libespeak-ng.so.1')
lib.espeak_Initialize.argtypes = [c.c_int, c.c_int, c.c_char_p, c.c_int]
rate = lib.espeak_Initialize(2, 0, None, 0)
assert rate > 0
lib.espeak_SetVoiceByName.argtypes = [c.c_char_p]
assert lib.espeak_SetVoiceByName(b'en-us') == 0
lib.espeak_SetParameter(1, 155, 0)
buffers = []
@c.CFUNCTYPE(c.c_int, c.POINTER(c.c_short), c.c_int, c.c_void_p)
def callback(samples, count, events):
    if samples and count: buffers.append(c.string_at(samples, count * 2))
    return 0
lib.espeak_SetSynthCallback(callback)
lib.espeak_Synth.argtypes = [c.c_char_p, c.c_size_t, c.c_uint, c.c_int, c.c_uint, c.c_uint, c.c_void_p, c.c_void_p]
out = Path(__file__).resolve().parents[1] / 'android/app/src/main/res/raw'
out.mkdir(parents=True, exist_ok=True)
for key, text in {
    'warmup': 'Begin your five-minute warm-up.',
    'resume_warmup': 'Resume walking for your warm-up.',
    'resume_cooldown': 'Resume walking for your cooldown.',
    'run': 'Start running.', 'walk': 'Stop running. Start walking.',
    'halfway': "You’re halfway there.", 'minute': 'One minute left in this workout.',
    'cooldown': 'Begin your five-minute cooldown.', 'complete': 'Workout complete.',
    'modified': 'Workout finished. Some intervals were skipped.',
}.items():
    buffers.clear()
    data = text.encode('utf-8')
    assert lib.espeak_Synth(data, len(data) + 1, 0, 1, 0, 1, None, None) == 0
    lib.espeak_Synchronize()
    with wave.open(str(out / f'cue_{key}.wav'), 'wb') as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(rate)
        wav.writeframes(b''.join(buffers))
    print(key, sum(map(len, buffers)), 'bytes')
lib.espeak_Terminate()
