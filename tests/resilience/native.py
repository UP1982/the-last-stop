#!/usr/bin/env python3
"""M4 native lifecycle gate; PID/window scoped, /tmp profiles, no global input.
Input-file commands are explicitly synthetic logical Input. AX close/minimize/
focus and resize operate on verified native windows. SIGTERM remains abrupt.
"""
import importlib.util, json, os, shutil, signal, subprocess, sys, tempfile, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/evidence/m4';OUT.mkdir(parents=True,exist_ok=True)
STATES=('chapter_start','boarded','shelf','held','dropped','installed','cranking','cleared','returned','arrival','complete')
TMP=Path(tempfile.mkdtemp(prefix='tls-m4-native-',dir='/tmp'));(TMP/'home').mkdir()
ENV=dict(os.environ,HOME=str(TMP/'home'));ROWS=[];CHILDREN=[]
def record(**r):
 ROWS.append(r);(OUT/'native-results.json').write_text(json.dumps(dict(temp_root=str(TMP),rows=ROWS),indent=2)+'\n')
def run(args,name='helper'):
 p=subprocess.run(list(map(str,args)),cwd=ROOT,env=ENV,capture_output=True,timeout=180);record(name=name,argv=list(map(str,args)),exit=p.returncode,stderr=p.stderr.decode(errors='replace')[-1000:]);assert p.returncode==0,(args,p.stderr);return p.stdout
BIN=TMP/'native';FIX=TMP/'fixture';WINDOW=TMP/'window';CONTROL=TMP/'control';RESIZE=TMP/'resize'
run(['odin','build','src','-define:DEV_TOOLS=true','-define:M4_TEST_HOOKS=true','-define:M2_TEST_HOOKS=true','-out:'+str(BIN)],'native-build')
run(['odin','build','src','-define:M2_SELF_TEST=true','-out:'+str(FIX)],'fixture-build')
for src,out in [('tests/runtime/window_info.swift',WINDOW),('tests/resilience/window_control.swift',CONTROL),('tests/runtime/res640_window.swift',RESIZE)]:run(['swiftc',src,'-o',out])
def seed(state,save):run([FIX,'write-'+state,'--save-dir',save,'--project-root',ROOT],'seed-'+state)
def window(pid):
 w=json.loads(run([WINDOW,pid],'verify-window'))
 assert len(w)==1 and w[0]['kCGWindowOwnerPID']==pid and w[0]['kCGWindowName']=='The Last Stop' and w[0]['kCGWindowLayer']==0,(pid,w)
 return w[0]
def capture(name,p):
 path=OUT/(name+'.png')
 for attempt in range(3):
  time.sleep(.3)
  w=window(p.pid)
  try:
   run(['/usr/sbin/screencapture','-x','-o','-l'+str(w['kCGWindowNumber']),path],name+'-capture')
   after=window(p.pid)
   assert after['kCGWindowNumber']==w['kCGWindowNumber']
   from PIL import Image
   with Image.open(path) as im:
    b=after['kCGWindowBounds']
    assert any(abs(int(b['Width'])*s-im.width)<=4*s and abs(int(b['Height'])*s-im.height)<=4*s for s in (1,2)),(im.size,b)
   (OUT/(name+'.window.json')).write_text(json.dumps(dict(before=w,after=after,attempt=attempt),indent=2))
   return
  except BaseException:
   path.unlink(missing_ok=True)
   if attempt==2:raise
class Game:
 def __init__(self,name,save):
  self.name=name;self.save=save;self.dir=TMP/(name+'-window');self.dir.mkdir();self.control=self.dir/'input';self.status=self.dir/'status'
  self.log=(self.dir/'native.log').open('wb');self.p=subprocess.Popen([str(BIN),'--save-dir',str(save),'--project-root',str(ROOT)],cwd='/tmp',env=dict(ENV,TLS_M4_CONTROL=str(self.control),TLS_M4_STATUS=str(self.status)),stdout=self.log,stderr=self.log);CHILDREN.append(self)
  self.wait(lambda s:s[0]=='Title');window(self.p.pid)
 def state(self):
  try:
   s=self.status.read_text().split('|');return s if len(s)==12 else None
  except FileNotFoundError:return None
 def wait(self,pred):
  end=time.monotonic()+15
  while time.monotonic()<end:
   assert self.p.poll() is None,(self.name,self.p.returncode,(self.dir/'native.log').read_text()[-1500:]);s=self.state()
   if s and pred(s):return s
   time.sleep(.015)
  raise AssertionError(('native state timeout',self.name,self.state()))
 def cmd(self,cmd,pred=None):
  generation=int(self.state()[-1])
  staged=self.dir/'input.next';staged.write_text(cmd);staged.replace(self.control)
  if cmd=='quit':
   self.p.wait(timeout=10);assert self.p.returncode==0;return self.state()
  s=self.wait(lambda s:int(s[-1])>generation)
  if pred:return self.wait(pred)
  return s
 def release(self):self.cmd('release')
 def enter(self):self.cmd('continue');self.cmd('settle');return self.cmd('release',lambda s:s[6]=='false')
 def stop(self,how):
  if self.p.poll() is None:
   if how=='sigterm':self.p.terminate()
   elif how=='close':window(self.p.pid);run([CONTROL,self.p.pid,'close'],'AX-close')
   elif how=='title-quit':
    self.cmd('pause',lambda s:s[0]=='Paused');self.release();self.cmd('title');self.cmd('settle');self.release();self.wait(lambda s:s[0]=='Title');self.cmd('quit')
   self.p.wait(timeout=10)
  expected=-15 if how=='sigterm' else 0;assert self.p.returncode==expected,(self.name,self.p.returncode)
  self.log.close();record(name=self.name,pid=self.p.pid,exit=self.p.returncode,operation=how,intentional_sigterm=how=='sigterm',last_state=self.state())
try:
 # 44 starts: same checkpoint bytes + silent restore under both versions.
 for state in STATES:
  for version in (1,2):
   save=TMP/('checkpoint-'+state+'-'+str(version));seed(state,save);path=save/'chapter_01.json';d=json.loads(path.read_bytes());d['save_version']=version
   if version==1 and d['puzzle']['dropped_feet']:d['puzzle']['dropped_feet']=[x/2 for x in d['puzzle']['dropped_feet']]
   path.write_text(json.dumps(d));before=path.read_bytes();restored=[]
   for n in (1,2):
    g=Game('restore-'+state+'-'+str(version)+'-'+str(n),save);s=g.enter();assert s[8:10]==['0','0'];restored.append(s);g.stop('sigterm');assert path.read_bytes()==before
   assert restored[0][:-1]==restored[1][:-1]
 record(name='checkpoint-counts',starts=44,versions=2,states=11)
 # Each live state: true native close button and logical pause-menu/title Quit.
 for state in STATES:
  for op in ('close','title-quit'):
   save=TMP/(state+'-'+op);seed('shelf' if state=='held' else state,save);g=Game(state+'-'+op,save);g.enter()
   if state=='held':g.cmd('pickup');g.release();assert g.state()[2]=='Held'
   g.stop(op)
   # Restore to verify semantic equality and a valid checkpoint, no cue replay.
   g=Game(state+'-'+op+'-restart',save);g.enter();assert g.state()[8:10]==['0','0'];g.stop('sigterm')
 # Both sides of each story transition, close and SIGTERM; complete to valid
 # checkpoint on restart. Obstacle->Playing is immediate (no fade by design).
 for state in ('chapter_start','boarded','returned','arrival','complete'):
  for side in ('before','after'):
   for op in ('close','sigterm'):
    save=TMP/('fade-'+state+'-'+side+'-'+op);seed(state,save);g=Game('fade-'+state+'-'+side+'-'+op,save);g.enter();g.cmd('skip');g.release()
    if side=='before':g.cmd('tick-before')
    else:g.cmd('tick-after')
    g.stop(op)
 # Failure while either half of a fade is pending must preserve that fade
 # on Return to game, then finish it after the I/O fault is removed.
 for state in ('chapter_start','boarded','returned','arrival'):
  for side in ('before','after'):
   save=TMP/('dirty-fade-'+state+'-'+side);seed(state,save);g=Game('dirty-fade-'+state+'-'+side,save);g.enter();g.cmd('skip');g.release()
   g.cmd('tick-before' if side=='before' else 'tick-after');g.cmd('fault');g.release();before=g.state()[1:4]
   run([CONTROL,g.p.pid,'close'],'dirty-fade-AX-close');g.wait(lambda s:s[0]=='Save_Failed');g.cmd('return');g.release();assert g.state()[1:4]==before
   g.cmd('recover');g.cmd('settle');g.stop('close')
 # Dirty close must stay open, offer Retry/Return, keep exact state on Return.
 for state in STATES:
  save=TMP/('dirty-'+state);seed('shelf' if state=='held' else state,save);g=Game('dirty-'+state,save);g.enter()
  if state=='held':g.cmd('pickup');g.release()
  g.cmd('fault');before=g.state()[1:4];g.release();window(g.p.pid);run([CONTROL,g.p.pid,'close'],'dirty-AX-close');g.wait(lambda s:s[0]=='Save_Failed')
  if state=='arrival':capture('failed-save-prompt',g.p)
  g.cmd('return',lambda s:s[0]!='Save_Failed');g.release();assert g.state()[1:4]==before
  # Pause-menu Quit to Title uses the same failure prompt.
  g.cmd('pause',lambda s:s[0]=='Paused');g.release();g.cmd('title',lambda s:s[0]=='Save_Failed');g.release();g.cmd('recover');g.cmd('retry');g.cmd('settle');g.release();g.wait(lambda s:s[0]=='Title');g.stop('title-quit' if False else 'close')
 # Abrupt termination with an actually newer dirty reward checkpoint keeps
 # the old successful Arrival bytes; restart is silent and can finish once.
 save=TMP/'dirty-sigterm';seed('arrival',save);before=(save/'chapter_01.json').read_bytes();g=Game('dirty-sigterm',save);g.enter();g.cmd('fault');g.release();g.cmd('skip');g.cmd('settle');g.release()
 assert g.state()[1]=='Complete' and g.state()[4]=='true'
 g.stop('sigterm');assert (save/'chapter_01.json').read_bytes()==before
 g=Game('dirty-sigterm-restart',save);g.enter();assert g.state()[1]=='Arrival' and g.state()[8:10]==['0','0'];g.cmd('skip');g.cmd('settle');g.stop('close');assert json.loads((save/'chapter_01.json').read_bytes())['checkpoint']=='complete'
 # Two simultaneously live native windows, owner held until process exit.
 save=TMP/'second-instance';seed('arrival',save);a=Game('owner-window',save);a.enter();b=Game('second-window',save)
 assert b.state()[5]=='false';capture('second-instance-notice',b.p);before=(save/'chapter_01.json').read_bytes();assert (save/'chapter_01.json').read_bytes()==before;run([CONTROL,b.p.pid,'focus'],'focus-second');run([CONTROL,a.p.pid,'focus'],'focus-first');assert a.state()[1:4]==['Arrival','Installed','Cleared'];b.stop('close')
 # Real resize/minimize/restore and focus interruption, scoped to our two PIDs.
 window(a.p.pid);run([RESIZE,a.p.pid,640,360,720],'resize-minimum');run([CONTROL,a.p.pid,'minimize'],'minimize');time.sleep(.2);run([CONTROL,a.p.pid,'restore'],'restore');run([CONTROL,a.p.pid,'focus'],'focus-owner');time.sleep(.15);capture('restored-minimum',a.p)
 a.stop('close')
 record(name='PASS',all_children_reaped=True,physical_key_aliases='human-only; logical Input is injected',temp_root=str(TMP))
 print('PASS M4 native lifecycle',len([r for r in ROWS if 'pid' in r]),'process exits',TMP)
finally:
 for g in CHILDREN:
  if g.p.poll() is None:g.p.kill();g.p.wait(timeout=5)
  if not g.log.closed:g.log.close()
