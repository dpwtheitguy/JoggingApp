"""Generate offline neural coaching WAVs with Kokoro on CPU.

Development-only dependencies: scripts/voice-requirements.txt.
See docs/VOICE-DIRECTION.md for model downloads, hashes and license provenance.
No model, Python package, service account or network access is needed by Android.
"""
import argparse
import hashlib
import importlib.metadata
import json
from pathlib import Path
import tempfile

CUES = {
    'warmup': 'Begin your five-minute warm-up.',
    'resume_warmup': 'Resume walking for your warm-up.',
    'resume_cooldown': 'Resume walking for your cooldown.',
    'run': 'Start running.',
    'walk': 'Stop running. Start walking.',
    'halfway': "You’re halfway there.",
    'minute': 'One minute left in this workout.',
    'cooldown': 'Begin your five-minute cooldown.',
    'complete': 'Workout complete.',
    'modified': 'Workout finished. Some intervals were skipped.',
}
MODEL_HASHES = {
    'kokoro-v1.0.onnx': 'beb0d1848dee9a49da392cc3df26958d46cfa35d321edf434f52949153f0df3a',
    'voices-v1.0.bin': 'bca610b8308e8d99f32e6fe4197e7ec01679264efed0cac9140fe9c29f1fbf7d',
}
ROOT = Path(__file__).resolve().parents[1]


def generate():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--voice', choices=['af_heart', 'af_bella', 'af_sarah'], default='af_heart')
    parser.add_argument('--speed', type=float, default=0.96)
    parser.add_argument('--model-dir', type=Path, default=ROOT / '.local-tools/voice')
    parser.add_argument('--output', type=Path, default=ROOT / 'android/app/src/main/res/raw')
    parser.add_argument('--manifest', type=Path, default=ROOT / 'docs/audio/coaching-manifest.json')
    args = parser.parse_args()
    if not 0.8 <= args.speed <= 1.1:
        parser.error('Use a coaching speech speed from 0.8 to 1.1.')
    import numpy as np
    import onnxruntime as rt
    import soundfile as sf
    from kokoro_onnx import Kokoro

    for filename, expected in MODEL_HASHES.items():
        actual = hashlib.sha256((args.model_dir / filename).read_bytes()).hexdigest()
        if actual != expected:
            raise ValueError(f'{filename}: unexpected SHA-256 {actual}')
    # Keep host load bounded; never use the laptop GPU for audio generation.
    options = rt.SessionOptions()
    options.intra_op_num_threads = 2
    options.inter_op_num_threads = 1
    rt.disable_telemetry_events()
    session = rt.InferenceSession(str(args.model_dir / 'kokoro-v1.0.onnx'),
                                 sess_options=options, providers=['CPUExecutionProvider'])
    engine = Kokoro.from_session(session, str(args.model_dir / 'voices-v1.0.bin'))
    manifest = {'engine': 'Kokoro-82M v1.0', 'generator': 'kokoro-onnx',
                'generatorVersion': importlib.metadata.version('kokoro-onnx'),
                'voice': args.voice, 'speed': args.speed, 'language': 'en-us',
                'modelHashes': MODEL_HASHES, 'sampleRate': 24000, 'encoding': 'mono PCM16',
                'peakDbFS': -1.5, 'leadingPadMs': 80, 'trailingPadMs': 120, 'cues': {}}
    args.output.mkdir(parents=True, exist_ok=True)
    # Generate/validate the complete set before replacing any shipped file.
    with tempfile.TemporaryDirectory(prefix='runprogram-voice-') as staging:
        staging = Path(staging)
        for key, text in CUES.items():
            audio, rate = engine.create(text, voice=args.voice, speed=args.speed, lang='en-us')
            audio = np.asarray(audio).reshape(-1)
            if rate != 24000 or not np.isfinite(audio).all():
                raise ValueError(f'{key}: invalid generated audio')
            active = np.flatnonzero(np.abs(audio) >= 10 ** (-45 / 20))
            if not len(active):
                raise ValueError(f'{key}: silence')
            # Trim only outer silence, retaining internal phrasing and consonant margins.
            margin = int(rate * 0.02)
            audio = audio[max(0, int(active[0]) - margin):min(len(audio), int(active[-1]) + margin + 1)]
            audio *= 10 ** (-1.5 / 20) / float(np.max(np.abs(audio)))
            audio = np.pad(audio, (int(rate * 0.08), int(rate * 0.12)))
            duration = len(audio) / rate
            if not 0.5 <= duration <= 8:
                raise ValueError(f'{key}: implausible duration {duration}')
            filename = f'cue_{key}.wav'
            sf.write(staging / filename, audio, rate, subtype='PCM_16')
            digest = hashlib.sha256((staging / filename).read_bytes()).hexdigest()
            manifest['cues'][key] = {'text': text, 'file': filename, 'seconds': round(duration, 4), 'sha256': digest}
            print(f'{key}: {duration:.2f}s', flush=True)
        for p in staging.glob('*.wav'):
            (args.output / p.name).write_bytes(p.read_bytes())
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')


if __name__ == '__main__':
    generate()
