"""Validate shipped coaching PCM, provenance, and optimized APK asset retention."""
from array import array
import hashlib
import json
import math
from pathlib import Path
import sys
import wave
import zipfile

apk = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/app/outputs/flutter-apk/app-release.apk')
source = Path('android/app/src/main/res/raw')
manifest = json.loads(Path('docs/audio/coaching-manifest.json').read_text())
keys = {'warmup', 'resume_warmup', 'resume_cooldown', 'run', 'walk', 'halfway', 'minute', 'cooldown', 'complete', 'modified'}
assert set(manifest['cues']) == keys
assert {p.name for p in source.glob('cue_*.wav')} == {f'cue_{k}.wav' for k in keys}
for key in sorted(keys):
    cue = manifest['cues'][key]
    path = source / cue['file']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == cue['sha256'], f'{key}: provenance mismatch'
    with wave.open(str(path), 'rb') as wav:
        assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) == (1, 2, 24000)
        duration = wav.getnframes() / wav.getframerate()
        assert 0.5 <= duration <= 8 and abs(duration - cue['seconds']) < 0.001
        pcm = array('h', wav.readframes(wav.getnframes()))
        if sys.byteorder != 'little': pcm.byteswap()
    peak = max(abs(n) for n in pcm) / 32768
    rms = math.sqrt(sum(n * n for n in pcm) / len(pcm)) / 32768
    assert 0.83 < peak < 0.85 and rms > 0.015, f'{key}: invalid audio level'
    voiced = [i for i, n in enumerate(pcm) if abs(n) >= 185]  # -45 dBFS
    assert voiced[0] / 24000 <= 0.15 and (len(pcm) - voiced[-1]) / 24000 <= 0.2
    print(f'{key}: {duration:.2f}s, peak {20 * math.log10(peak):.1f} dBFS, RMS {20 * math.log10(rms):.1f} dBFS')
expected = {p.read_bytes() for p in source.glob('cue_*.wav')}
with zipfile.ZipFile(apk) as archive:
    actual = {archive.read(n) for n in archive.namelist() if n.startswith('res/')}
missing = expected - actual
assert not missing, f'{len(missing)} of {len(expected)} coaching clips missing from {apk}'
print(f'PASS: all {len(expected)} validated Heart coaching clips retained byte-for-byte in {apk}')
