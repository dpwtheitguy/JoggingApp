"""Explicit API 33+ disposable-device UI checks. Revokes notification permission;
force-stops the app; preserves evidence locally. Never launches an emulator.
"""
import json, re, sqlite3, subprocess, sys, time, xml.etree.ElementTree as E
from shutil import which
from pathlib import Path
if len(sys.argv) != 3 or not which('adb'):
 raise SystemExit('Source scripts/dev-env.sh, then: python3 scripts/check-device-ui.py DISPOSABLE_SERIAL OUTPUT_DIRECTORY')
out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
adb=[which('adb'),'-s',sys.argv[1]]
def run(*args): return subprocess.check_output(adb+list(args),stderr=subprocess.STDOUT)
def nodes():
 run('shell','uiautomator','dump','/sdcard/final-ui.xml')
 raw=run('exec-out','cat','/sdcard/final-ui.xml');(out/'last-ui.xml').write_bytes(raw)
 return list(E.fromstring(raw).iter('node'))
def label(n):return n.get('text') or n.get('content-desc') or ''
def hit(n):
 x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')));run('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
def tap(text,scroll=False):
 for _ in range(6 if scroll else 1):
  for n in nodes():
   if label(n)==text or label(n).startswith(text+'\nTab '):hit(n);return
  if scroll:run('shell','input','swipe','540','1900','540','850','250')
 raise AssertionError('Missing '+text)
def has(text):return any(text in label(n) for n in nodes())
def home():
 if any(label(n)=='Return to Home' for n in nodes()):tap('Return to Home')
def db(name):
 p=out/(name+'.db');p.write_bytes(run('exec-out','run-as','com.joggingapp.runprogram','cat','databases/coach.db'))
 c=sqlite3.connect(p)
 values={k:json.loads(v) for k,v in c.execute('select name,value from documents')};c.close();return values

def stop():tap('End Workout',True);tap('Confirm');assert has('Workout stopped early')
run('shell','am','force-stop','com.joggingapp.runprogram')
run('shell','pm','revoke','com.joggingapp.runprogram','android.permission.POST_NOTIFICATIONS')
run('shell','am','start','-W','-n','com.joggingapp.runprogram/.MainActivity')
home();before=db('before-ui');cursor=before['state']['programs'][-1]['cursor']
tap('Start Workout')
items=nodes();denied=False
for n in items:
 if 'permission_deny' in n.get('resource-id',''):
  hit(n);denied=True;break
assert has('RUNNING')
stop();home();tap('Start Workout')
items=nodes();assert not any('permission_deny' in n.get('resource-id','') for n in items)
assert has('RUNNING')
stop();home()
permission=run('shell','dumpsys','package','com.joggingapp.runprogram').decode()
assert re.search(r'POST_NOTIFICATIONS: granted=false',permission)
prefs=run('exec-out','run-as','com.joggingapp.runprogram','cat','shared_prefs/permission_prompts.xml').decode()
assert 'name="notifications_requested" value="true"' in prefs
assert db('after-denial')['state']['programs'][-1]['cursor']==cursor
print('PASS: denied notifications permit workouts; no repeat permission prompt; no progression',flush=True)

tap('Start Workout');time.sleep(7)
run('shell','am','force-stop','com.joggingapp.runprogram')
killed=db('after-kill');saved=killed['runtime']['elapsedMs'];count=len(killed['state']['history'])
assert saved>0 and killed['state']['programs'][-1]['cursor']==cursor
time.sleep(2)
run('shell','am','start','-W','-n','com.joggingapp.runprogram/.MainActivity')
assert has('INTERRUPTED')
reopened=db('after-reopen');assert reopened['runtime']['elapsedMs']==saved
assert len(reopened['state']['history'])==count
assert has('Resume')
time.sleep(2)
assert db('still-interrupted')['runtime']['elapsedMs']==saved
stop();final=db('after-recovery-stop')
assert final['state']['programs'][-1]['cursor']==cursor
assert final['state']['history'][-1]['elapsedMs']==saved
(out/'recovery-result.json').write_text(json.dumps({'checkpointMs':saved,'cursor':cursor,'historyBeforeStop':count,'status':final['state']['history'][-1]['status']}))
print('PASS: force-stop/reopen retains checkpoint exactly without downtime or automatic progression; explicit stop saves it',flush=True)
(out/'recovery.png').write_bytes(run('exec-out','screencap','-p'))
home();tap('History')
for n in nodes():
 if 'Week ' in label(n) and 'Stopped early' in label(n):hit(n);break
assert has('Workout details')
assert has('Active exercise:')
(out/'history-details.png').write_bytes(run('exec-out','screencap','-p'))
print('PASS: actual history entry opens saved workout details',flush=True)
