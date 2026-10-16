#!/usr/bin/env python3
"""Art3 native gate: verified owned-window captures and real-loop journey input.
Uses temporary save profiles; authored content/assets and normal saves unchanged.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/evidence/art3'
OUT.mkdir(parents=True,exist_ok=True)
records=[]

def record(row):
    records.append(row)
    (OUT/'native.commands.json').write_text(json.dumps(records,indent=2)+'\n')

def run(name,args,timeout=120,env=None):
    p=subprocess.run(list(map(str,args)),cwd=ROOT,capture_output=True,timeout=timeout,env=env)
    (OUT/(name+'.stdout.txt')).write_bytes(p.stdout)
    (OUT/(name+'.stderr.txt')).write_bytes(p.stderr)
    record(dict(name=name,argv=list(map(str,args)),exit_code=p.returncode))
    assert p.returncode==0,(name,p.returncode,p.stderr.decode())
    return p

def hashes(path):
    if not path.exists(): return None
    return {str(p.relative_to(path)):hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(path.rglob('*')) if p.is_file()}

def window(pid):
    rows=json.loads(subprocess.check_output([str(ROOT/'build/art3-window-info'),str(pid)]))
    assert len(rows)==1,(pid,rows)
    w=rows[0]
    assert w['kCGWindowOwnerPID']==pid and w['kCGWindowName']=='The Last Stop' and w['kCGWindowLayer']==0
    return w

def capture(name,pid,width=1280,height=720):
    w=window(pid);b=w['kCGWindowBounds']
    assert width<=b['Width']<=width+2 and height+32<=b['Height']<=height+34,(name,b)
    path=OUT/(name+'.png')
    try:
        run(name+'-capture',['/usr/sbin/screencapture','-x','-o','-l'+str(w['kCGWindowNumber']),path])
        with Image.open(path) as im:
            assert any(0<=int(b['Width'])*s-im.width<=4*s and 0<=int(b['Height'])*s-im.height<=4*s for s in (1,2)),(im.size,b)
    except BaseException:
        path.unlink(missing_ok=True) # Never retain a non-game/invalid capture.
        raise
    (OUT/(name+'.window.json')).write_text(json.dumps(w,indent=2)+'\n')

def reap(p,log,label):
    if p.poll() is None:
        p.terminate()
        try:p.wait(timeout=5)
        except subprocess.TimeoutExpired:p.kill();p.wait(timeout=5)
    log.close()
    record(dict(name=label,pid=p.pid,exit_code=p.returncode,owned_process_reaped=True))

normal=Path.home()/'Library/Application Support/The Last Stop/saves'
before={key:hashes(path) for key,path in [('data',ROOT/'data'),('assets',ROOT/'assets'),('saves',normal)]}
for label,flags in [('release',[]),('dev',['-define:DEV_TOOLS=true']),('resource-test',['-define:DEV_TOOLS=true','-define:ART3_SELF_TEST=true'])]:
    binary={'release':'the-last-stop','dev':'the-last-stop-dev','resource-test':'art3-resource-test'}[label]
    run('build-'+label,['odin','build','src',*flags,'-out:build/'+binary])
run('build-window-info',['swiftc','tests/runtime/window_info.swift','-o','build/art3-window-info'])
run('build-resize',['swiftc','tests/runtime/res640_window.swift','-o','build/art3-window-resize'])

with tempfile.TemporaryDirectory(prefix='art3-native-',dir=OUT) as tmp:
    tmp=Path(tmp)
    # Resource decode failure that passes graph/hash validation: corrupted PNG
    # bytes have their exact new hash registered only in the disposable fixture.
    bad=tmp/'bad';shutil.copytree(ROOT/'data',bad/'data');shutil.copytree(ROOT/'assets',bad/'assets')
    manifest=bad/'data/assets/manifest.json';doc=json.loads(manifest.read_text())
    asset=doc['assets']['milo_idle_r'];broken=b'invalid PNG data for staged texture failure\n'
    (bad/asset['path']).write_bytes(broken);asset['sha256']=hashlib.sha256(broken).hexdigest()
    manifest.write_text(json.dumps(doc))
    run('resource-reloads',[ROOT/'build/art3-resource-test','resources','--project-root',ROOT,
                           '--save-dir',tmp/'resource-saves'],env=dict(os.environ,TLS_ART3_BAD_ROOT=str(bad)))
    # Missing assets fail in the existing content validator; inspect visible error.
    (bad/asset['path']).unlink()
    log=open(OUT/'missing-asset.log','wb')
    p=subprocess.Popen([str(ROOT/'build/the-last-stop'),'--project-root',str(bad),'--save-dir',str(tmp/'error-saves')],cwd='/tmp',stdout=log,stderr=log)
    try:
        time.sleep(.8);capture('missing-asset-content-error',p.pid)
    finally:reap(p,log,'missing-asset-content-error')
    # Whole journey + movement/jump rendezvous. No gameplay state mutation.
    rv=tmp/'rendezvous';rv.mkdir();log=open(OUT/'native-art3.log','wb')
    p=subprocess.Popen([str(ROOT/'build/the-last-stop-dev'),'--project-root',str(ROOT),
                        '--save-dir',str(tmp/'saves'),'--autoplay','art3'],cwd='/tmp',
                       env=dict(os.environ,TLS_M2_EVIDENCE=str(rv)),stdout=log,stderr=log)
    done=set()
    try:
        deadline=time.monotonic()+180
        while time.monotonic()<deadline:
            ready=next((s.stem for s in sorted(rv.glob('*.ready')) if not (rv/(s.stem+'.release')).exists()),None)
            if ready:
                time.sleep(.18)
                state=(rv/(ready+'.ready')).read_text()
                (OUT/(ready+'.state.txt')).write_text(state)
                capture(ready+'-1280x720',p.pid)
                if ready=='puzzle':
                    run('minimum-resize',[ROOT/'build/art3-window-resize',p.pid,640,360,720]);time.sleep(.3)
                    capture('puzzle-640x360',p.pid,640,360)
                    run('restore-size',[ROOT/'build/art3-window-resize',p.pid,1280,720,360]);time.sleep(.2)
                if ready in ('walking_right','walking_left'):assert 'art=milo_walk_r' in state,state
                if ready=='walking_left':assert 'facing=-1' in state,state
                if ready=='jumping':assert 'art=milo_jump_r' in state and 'grounded=false' in state,state
                done.add(ready);(rv/(ready+'.release')).write_text('verified game-window capture\n')
            if p.poll() is not None:
                assert p.returncode==0,p.returncode
                break
            time.sleep(.03)
        else:raise AssertionError(('journey timeout',done))
        required={'title','prologue','travel','puzzle','walking_right','walking_left','jumping','carried','cleared','return','arrival','end_card','title_end'}
        assert required<=done,(required-done,done)
        final=json.loads((tmp/'saves/chapter_01.json').read_text())
        assert final['checkpoint']=='complete' and final['puzzle']['phase']=='cleared'
        (OUT/'native-result.json').write_text(json.dumps(dict(stages=sorted(done),save=final,exit_code=p.returncode),indent=2)+'\n')
    finally:reap(p,log,'native-art3')

after={key:hashes(path) for key,path in [('data',ROOT/'data'),('assets',ROOT/'assets'),('saves',normal)]}
assert before==after
(OUT/'native-isolation.json').write_text(json.dumps(dict(before=before,after=after,all_owned_processes_reaped=True),indent=2)+'\n')
print('PASS native art3: owned game windows, full journey + left/right/jump, minimum size, resource rollback, no save/content/asset changes')
