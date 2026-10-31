"""Regression check: optimized Android APK must retain every bundled voice clip."""
from pathlib import Path
import sys
import zipfile

apk = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/app/outputs/flutter-apk/app-release.apk')
source = Path('android/app/src/main/res/raw')
expected = {p.read_bytes() for p in source.glob('cue_*.wav')}
with zipfile.ZipFile(apk) as archive:
    actual = {archive.read(n) for n in archive.namelist() if n.startswith('res/')}
missing = expected - actual
assert expected and not missing, f'{len(missing)} of {len(expected)} coaching clips missing from {apk}'
print(f'PASS: all {len(expected)} coaching clips retained byte-for-byte in {apk}')
