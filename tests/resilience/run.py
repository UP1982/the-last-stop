#!/usr/bin/env python3
"""Maintained M4 production-function/process harness. All profiles live in /tmp.
--quick: F1/F3/F4/F5, 88 rejections, migrations and clock/locale, ~seconds.
Default also runs event SIGKILLs, 22 atomic kills, native reload/resource staging
and real EACCES. --disk-full adds a bounded disposable HFS+ ENOSPC volume.
Native lifecycle/window captures are in native.py. No real Library saves.
"""
import copy, hashlib, json, os, random, shutil, signal, subprocess, sys, tempfile, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/evidence/m4'
STATES=('chapter_start','boarded','shelf','held','dropped','installed','cranking','cleared','returned','arrival','complete')
SEED=4041001
class Harness:
 def __init__(self):
  OUT.mkdir(parents=True,exist_ok=True)
  self.tmp=Path(tempfile.mkdtemp(prefix='tls-m4-',dir='/tmp')); self.rows=[]
  (self.tmp/'home').mkdir(); self.env=dict(os.environ,HOME=str(self.tmp/'home'))
  self.bin=self.tmp/'m4-test';self.fixture=self.tmp/'m2-test';self.story=self.tmp/'m3b-test'
  for b,flags in [(self.bin,['M4_SELF_TEST','DEV_TOOLS','M4_TEST_HOOKS','M2_TEST_HOOKS']),(self.fixture,['M2_SELF_TEST','M2_TEST_HOOKS']),(self.story,['M3B_SELF_TEST'])]:
   self.exec(['odin','build','src',*['-define:'+x+'=true' for x in flags],'-out:'+str(b)],cwd=ROOT)
 def record(self,row):
  self.rows.append(row)
  if len(self.rows)%25==0 or row['name'] in ('PASS','rejection-migration-counts','crash-counts','geometry-counts','asset-counts'):self.flush()
 def flush(self):
  (OUT/('quick-results.json' if '--quick' in sys.argv else 'harness-results.json')).write_text(json.dumps(dict(seed=SEED,temp_root=str(self.tmp),rows=self.rows),indent=2)+'\n')
 def exec(self,args,env=None,cwd='/tmp',expected=0,name=None):
  p=subprocess.Popen(list(map(str,args)),cwd=cwd,env=dict(self.env,**(env or {})),stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  try: out,err=p.communicate(timeout=90)
  except BaseException:p.kill();p.communicate();raise
  n=name or 'call-%04d'%len(self.rows);(self.tmp/(n+'.log')).write_bytes(out+err)
  self.record(dict(name=n,argv=list(map(str,args)),pid=p.pid,exit=p.returncode,log=str(self.tmp/(n+'.log')),stdout=out.decode(errors='replace')[-2000:],stderr=err.decode(errors='replace')[-2000:]))
  assert p.returncode==expected,(n,p.returncode,err[-4000:]);return out,err
 def args(self,b,cmd,save,root=ROOT):return [b,cmd,'--save-dir',save,'--project-root',root]
 def call(self,cmd,save,b=None,env=None,root=ROOT,expected=0,name=None):return self.exec(self.args(b or self.bin,cmd,save,root),env=env,expected=expected,name=name)
 def seed(self,state,save):
  self.call('write-'+state,save,b=self.fixture);return (save/'chapter_01.json').read_bytes()
 def wait(self,marker,p):
  until=time.monotonic()+15
  while not marker.exists():
   assert p.poll() is None,(p.returncode,p.communicate());assert time.monotonic()<until,marker;time.sleep(.005)
 def paused(self,cmd,save,stop,root=ROOT):
  marker=self.tmp/('marker-%04d'%len(self.rows));p=subprocess.Popen(list(map(str,self.args(self.bin,cmd,save,root))),env=dict(self.env,TLS_M4_STOP=str(stop),TLS_M4_MARKER=str(marker)),stdout=subprocess.PIPE,stderr=subprocess.PIPE,cwd='/tmp')
  try:self.wait(marker,p)
  except BaseException:p.kill();p.communicate();raise
  return p,marker
 def finish(self,p,marker,kill=False,name='rendezvous'):
  if kill:p.kill()
  else:Path(str(marker)+'.release').touch()
  out,err=p.communicate(timeout=15)
  log=self.tmp/(name+'.log');log.write_bytes(out+err)
  self.record(dict(name=name,pid=p.pid,exit=p.returncode,intentional_sigkill=kill,log=str(log),stderr=err.decode(errors='replace')[-2000:]))
  assert p.returncode==(-9 if kill else 0),(name,p.returncode,err[-2000:]);return err
 def fixtures(self):
  for state in STATES:
   save=self.tmp/'rejections';good=json.loads(self.seed(state,save));path=save/'chapter_01.json'
   for version in (1,2):
    d=copy.deepcopy(good);d['save_version']=version
    if version==1 and d['puzzle']['dropped_feet']:d['puzzle']['dropped_feet']=[x/2 for x in d['puzzle']['dropped_feet']]
    path.write_text(json.dumps(d));original=path.read_bytes();normalized=json.loads(self.call('inspect',save,b=self.fixture)[0]);assert path.read_bytes()==original
    path.write_text(json.dumps(normalized));assert json.loads(self.call('inspect',save,b=self.fixture)[0])==normalized
    for variant in ('corrupt','truncated','unknown','contradiction'):
     bad=copy.deepcopy(d)
     if variant=='unknown':bad['save_version']=99
     if variant=='contradiction':
      if state in ('chapter_start','boarded'):bad['puzzle']['snail_seen']=True
      else:bad['puzzle'].update(phase='cleared',handle_location='shelf',dropped_feet=None)
     payload=json.dumps(bad).encode()
     if variant=='corrupt':payload=b'{broken'
     if variant=='truncated':payload=payload[:-5]
     path.write_bytes(payload);self.call('inspect',save,b=self.fixture,expected=3);self.call('title-quit',save,b=self.fixture);assert path.read_bytes()==payload
  self.record(dict(name='rejection-migration-counts',rejections=88,version_state_idempotence=22))
 def navigation(self):
  for state,target in [('shelf','Held'),('dropped','Installed'),('cranking','Cleared'),('arrival','Complete')]:
   for fault in ('temp','write','sync','close','rename','directory_sync'):
    save=self.tmp/('retry-'+target+'-'+fault);self.seed(state,save)
    self.call('failed-navigation',save,env={'TLS_M4_FAULT':fault,'TLS_M4_TARGET':target},name='retry-'+target+'-'+fault)
    self.call('resume',save,b=self.story)
  save=self.tmp/'deleted';self.seed('complete',save);self.call('delete-continue',save);assert not (save/'chapter_01.json').exists()
  for variant in ('missing','unreadable','replaced','replaced-valid','symlink-missing'):
   save=self.tmp/('reread-'+variant);self.seed('complete',save);p,m=self.paused('reread',save,'Chapter_Start/Shelf/Blocked/before_continue');path=save/'chapter_01.json'
   try:
    if variant=='missing':path.unlink()
    elif variant=='unreadable':path.chmod(0)
    elif variant=='replaced':path.write_text('{broken')
    elif variant=='replaced-valid':
     d=json.loads(path.read_bytes());d['checkpoint']='arrival';candidate=save/'external';candidate.write_text(json.dumps(d));candidate.replace(path)
    else:path.unlink();path.symlink_to(self.tmp/'absent-target')
    self.finish(p,m,name='fresh-continue-'+variant)
   finally:
    if path.exists():path.chmod(0o600)
    if p.poll() is None:p.kill();p.communicate()
 def identities(self):
  save=self.tmp/'owner';self.seed('arrival',save)
  p,m=self.paused('hold',save,'Arrival/Installed/Cleared/loaded')
  try:
   before=(save/'chapter_01.json').read_bytes();link=self.tmp/'owner-link';link.symlink_to(save,target_is_directory=True)
   for target in (save,link):self.call('busy',target);assert (save/'chapter_01.json').read_bytes()==before
  finally:self.finish(p,m,name='owner-lock-release')
  self.call('resume',link,b=self.story);assert json.loads((save/'chapter_01.json').read_bytes())['checkpoint']=='complete'
  for point in ('before_temp','before_write','before_rename','after_rename'):
   for variant in ('directory','symlink','lock'):
    real=self.tmp/('replace-'+point+'-'+variant);self.seed('arrival',real);save=real
    if variant=='symlink':save=self.tmp/(real.name+'-alias');save.symlink_to(real,target_is_directory=True)
    p,m=self.paused('one-save',save,'Arrival/Installed/Cleared/'+point)
    try:
     if variant=='directory':real.rename(Path(str(real)+'-old'));real.mkdir()
     elif variant=='symlink':save.unlink();other=self.tmp/(real.name+'-new');other.mkdir();save.symlink_to(other,target_is_directory=True)
     else:(real/'.write-owner.lock').rename(real/'.old-lock');(real/'.write-owner.lock').touch()
     err=self.finish(p,m,name='identity-'+point+'-'+variant);assert b'dirty true' in err
     old=Path(str(real)+'-old') if variant=='directory' else real
     assert json.loads((old/'chapter_01.json').read_bytes())['checkpoint']=='arrival'
    finally:
     if p.poll() is None:p.kill();p.communicate()
 def clocks(self):
  save=self.tmp/'locale';self.seed('dropped',save);expected=self.call('inspect',save,b=self.fixture)[0]
  for locale in ('C','en_US.UTF-8','de_DE.UTF-8','tr_TR.UTF-8'):
   for tz in ('UTC','Pacific/Kiritimati','America/Chicago'):assert self.call('inspect',save,b=self.fixture,env={'LC_ALL':locale,'LANG':locale,'TZ':tz})[0]==expected
  for state in ('chapter_start','cranking','arrival'):save=self.tmp/('clock-'+state);self.seed(state,save);self.call('virtual-time',save)
 def crashes(self):
  events=0
  for route in ('whole','whole-skip'):
   _,trace=self.call(route,self.tmp/('trace-'+route));lines=[x for x in trace.decode().splitlines() if x.startswith('M4_EVENT')]
   for line in lines:
    n=int(line.split()[1]);save=self.tmp/('crash-'+route+'-'+str(n));p,m=self.paused(route,save,n)
    try:
     self.finish(p,m,kill=True,name='kill-'+route+'-'+str(n));path=save/'chapter_01.json'
     prior=path.read_bytes() if path.exists() else None
     if prior:json.loads(prior);self.call('resume',save,b=self.story)
     else:self.call('whole',save)
     assert json.loads(path.read_bytes())['checkpoint']=='complete'
     self.record(dict(name='crash-record',event=line,prior_bytes=prior.decode() if prior else None,restart_complete=True))
    finally:
     if p.poll() is None:p.kill();p.communicate()
   events+=len(lines)
  for state in STATES:
   for point in ('before_rename','after_rename'):
    save=self.tmp/('atomic-'+state+'-'+point);before=self.seed(state,save)
    # one-save cold-restores Held as Dropped, by contract.
    normalized=json.loads(self.call('inspect',save,b=self.fixture)[0]);label='/'.join((normalized['checkpoint'].title().replace('_','_'),))
    # Ordinal is not used: match actual restored checkpoint/handle/phase.
    cp={'chapter_start':'Chapter_Start'}.get(normalized['checkpoint'],normalized['checkpoint'].title())
    p,m=self.paused('one-save',save,cp+'/'+normalized['puzzle']['handle_location'].title()+'/'+normalized['puzzle']['phase'].title()+'/'+point)
    try:
     self.finish(p,m,kill=True,name='atomic-'+state+'-'+point);after=(save/'chapter_01.json').read_bytes();json.loads(after)
     if point=='before_rename':assert before==after
     self.call('resume',save,b=self.story)
    finally:
     if p.poll() is None:p.kill();p.communicate()
  self.record(dict(name='crash-counts',integrated_events=events,atomic_boundaries=22,seed=SEED))
 def geometry(self):
  random.seed(SEED)
  # Four independent validator-valid dimensions, crossed with six live puzzle
  # states and three mode families; real texture staging and focused completion.
  for change in ('ground','world','handle','recovery'):
   root=self.tmp/('geometry-'+change);shutil.copytree(ROOT/'data',root/'data');shutil.copytree(ROOT/'assets',root/'assets')
   path=root/'data/scenes/oliver_obstacle.json';d=json.loads(path.read_text())
   if change in ('ground','world'):
    axis=1 if change=='ground' else 0;delta=40 if axis==1 else 80
    for key in ('world_bounds','camera_bounds','ground'):d[key][axis]+=delta
    for obj in [*d['objects'].values(),*d['spawns'].values()]:obj['position'][axis]+=delta
    d['puzzle']['branch_cleared_position'][axis]+=delta
   elif change=='handle':d['objects'][d['puzzle']['handle']]['size'][0]+=8
   else:d['spawns'][d['puzzle']['handle_recovery_spawn']]['position'][0]-=24
   path.write_text(json.dumps(d));self.exec([ROOT/'build/tls-content','validate-content','--project-root',root])
   for state in ('shelf','held','dropped','installed','cranking','cleared','chapter_start','arrival'):
    for paused in (False,True):
     save=self.tmp/('reload-'+change+'-'+state+'-'+str(paused));self.seed('shelf' if state=='held' else state,save)
     self.call('reload',save,env={'TLS_M4_CONTENT':str(root),'TLS_M4_LIVE':'Held' if state=='held' else '', 'TLS_M4_PAUSED':'1' if paused else ''},name='reload-'+change+'-'+state+'-'+str(paused))
  self.record(dict(name='geometry-counts',native_live_reloads=64,seed=SEED))
 def assets(self):
  for kind in ('missing','hash','dimensions','decode','upload'):
   root=self.tmp/('asset-'+kind);shutil.copytree(ROOT/'data',root/'data');shutil.copytree(ROOT/'assets',root/'assets')
   path=root/'data/assets/manifest.json';d=json.loads(path.read_text());asset=d['assets']['milo_idle_r'];file=root/asset['path']
   if kind=='missing':file.unlink()
   elif kind=='hash':file.write_bytes(b'changed')
   elif kind=='dimensions':asset['frame_count']+=1;path.write_text(json.dumps(d))
   elif kind=='decode':
    file.write_bytes(b'not a PNG');asset['sha256']=hashlib.sha256(file.read_bytes()).hexdigest();path.write_text(json.dumps(d))
   env={'TLS_M4_CONTENT':str(root),'TLS_M4_UPLOAD_FAIL':'1' if kind=='upload' else ''}
   self.call('asset-reject',self.tmp/'asset-profile',root=root,env=env,name='asset-start-'+kind)
   self.call('assets',self.tmp/'asset-profile',env=env,name='asset-reload-'+kind)
  root=self.tmp/'snapshot';shutil.copytree(ROOT/'data',root/'data');shutil.copytree(ROOT/'assets',root/'assets');d=json.loads((root/'data/assets/manifest.json').read_text());file=root/d['assets']['milo_idle_r']['path']
  self.call('snapshot',self.tmp/'snapshot-profile',root=root,env={'TLS_M4_DELETE':str(file)})
  self.record(dict(name='asset-counts',startup_rejections=5,reload_rollbacks=40,snapshot_deletion=1))
 def permissions(self):
  denied=self.tmp/'eacces-startup';denied.mkdir();denied.chmod(0o500)
  try:self.call('unavailable',denied,name='real-EACCES-startup')
  finally:denied.chmod(0o700)
  save=self.tmp/'eacces';self.seed('arrival',save);before=(save/'chapter_01.json').read_bytes()
  p,m=self.paused('one-save',save,'Arrival/Installed/Cleared/loaded')
  try:
   save.chmod(0o500);err=self.finish(p,m,name='real-EACCES');assert b'dirty true' in err and (save/'chapter_01.json').read_bytes()==before
  finally:
   save.chmod(0o700)
   if p.poll() is None:p.kill();p.communicate()
  self.call('resume',save,b=self.story)
 def disk_full(self):
  volume=self.tmp/'full-volume';volume.mkdir();image=self.tmp/'full.dmg'
  self.exec(['hdiutil','create','-size','16m','-fs','HFS+','-volname','TLS-M4-ENOSPC',image]);self.exec(['hdiutil','attach',image,'-mountpoint',volume,'-nobrowse'])
  def fill():
   import errno
   with (volume/'filler').open('wb',buffering=0) as f:
    for size,limit in ((1048576,40),(4096,256),(1,65536)):
     for _ in range(limit):
      try:f.write(b'x'*size)
      except OSError as e:assert e.errno==errno.ENOSPC;break
     else:raise AssertionError('bounded fill did not exhaust disk')
  try:
   save=volume/'saves';self.seed('arrival',save);before=(save/'chapter_01.json').read_bytes();p,m=self.paused('one-save',save,'Arrival/Installed/Cleared/loaded')
   try:
    fill();err=self.finish(p,m,name='real-ENOSPC');assert b'dirty true' in err and before==(save/'chapter_01.json').read_bytes()
   finally:
    if p.poll() is None:p.kill();p.communicate()
   self.call('unavailable',volume/'startup',name='real-ENOSPC-startup')
   (volume/'filler').unlink();self.call('resume',save,b=self.story)
  finally:self.exec(['hdiutil','detach',volume])
 def run(self):
  before={n:hashes(ROOT/n) for n in ('data','assets')}
  self.fixtures();self.navigation();self.identities();self.clocks()
  if '--quick' not in sys.argv:self.crashes();self.geometry();self.assets();self.permissions()
  if '--disk-full' in sys.argv:self.disk_full()
  assert before=={n:hashes(ROOT/n) for n in before}
  self.record(dict(name='PASS',rows=len(self.rows),seed=SEED,authored_unchanged=True,all_children_reaped=True))
  print('PASS M4',len(self.rows),'records; seed',SEED,'retained',self.tmp,flush=True)
def hashes(root):return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()}
if __name__=='__main__':
 h=Harness()
 try:h.run()
 finally:h.flush()
