"""Exercise default setup/start/confirmed stop on a disposable English emulator.
Requires the app installed and foregrounded; saves screenshots, adds an incomplete
attempt, and never deletes existing history. Do not use against valuable test data.
"""
import re
import subprocess
import time
import xml.etree.ElementTree as E
from pathlib import Path

adb = ['adb', '-s', 'emulator-5554']
def run(*args):
    return subprocess.check_output([*adb, *args])
def nodes():
    run('shell','uiautomator','dump','/sdcard/runprogram-smoke.xml')
    return list(E.fromstring(run('exec-out','cat','/sdcard/runprogram-smoke.xml')).iter('node'))
def labels(items):
    return [n.get('text') or n.get('content-desc') for n in items]
def tap(text):
    for n in nodes():
        if (n.get('text') or n.get('content-desc')) == text:
            x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')))
            run('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
            return
    raise AssertionError(f'Control missing: {text}')
def capture(name):
    Path(f'docs/screenshots/{name}.png').write_bytes(run('exec-out','screencap','-p'))

items=labels(nodes())
if 'INITIALIZE PROGRAM' in items:
    capture('setup');tap('INITIALIZE PROGRAM')
if 'Return to Home' in labels(nodes()):tap('Return to Home')
assert 'Start Workout' in labels(nodes())
capture('dashboard');tap('Start Workout')
items=labels(nodes())
if 'Allow' in items:tap('Allow')
time.sleep(2)
assert any('TRAINING SEQUENCE · RUNNING' == t for t in labels(nodes()))
capture('player');tap('Pause')
assert any('TRAINING SEQUENCE · PAUSED' == t for t in labels(nodes()))
tap('End Workout')
assert 'End workout?' in labels(nodes())
tap('Confirm')
assert 'Workout stopped early' in labels(nodes())
tap('Return to Home')
assert 'Start Workout' in labels(nodes())
print('PASS: setup/dashboard, running player, pause, confirmed early stop and return Home')
