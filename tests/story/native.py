#!/usr/bin/env python3
"""Whole-journey native gate. Capture only a verified window of our own PID."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/evidence/m3b'
OUT.mkdir(parents=True, exist_ok=True)
records = []


def record(row):
    records.append(row)
    (OUT / 'native.commands.json').write_text(json.dumps(records, indent=2) + '\n')


def run(name, args, timeout=180):
    p = subprocess.run(list(map(str, args)), cwd=ROOT, capture_output=True, timeout=timeout)
    (OUT / (name + '.stdout.txt')).write_bytes(p.stdout)
    (OUT / (name + '.stderr.txt')).write_bytes(p.stderr)
    record(dict(name=name, argv=list(map(str,args)), exit_code=p.returncode))
    assert p.returncode == 0, (name, p.returncode, p.stderr.decode())
    return p


def hashes(path):
    if not path.exists(): return None
    return {str(p.relative_to(path)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(path.rglob('*')) if p.is_file()}


def window(pid):
    matches = json.loads(subprocess.check_output([str(ROOT / 'build/m3b-window-info'), str(pid)]))
    assert len(matches) == 1, (pid,matches)
    w = matches[0]
    assert w['kCGWindowOwnerPID'] == pid and w['kCGWindowName'] == 'The Last Stop' and w['kCGWindowLayer'] == 0
    return w


def capture(name,pid):
    w = window(pid)
    path = OUT / (name + '.png')
    (OUT / (name + '.window.json')).write_text(json.dumps(w,indent=2) + '\n')
    try:
        run(name + '-capture',['/usr/sbin/screencapture','-x','-o','-l' + str(w['kCGWindowNumber']),path])
        from PIL import Image
        with Image.open(path) as im:
            # Retina backing can be 1x or 2x. Reject any image outside our exact
            # window bounds (CG can include a 1px border omitted by -o);
            # remove failures before returning to the caller.
            b = w['kCGWindowBounds']
            assert any(0 <= int(b['Width'])*s-im.width <= 4*s and 0 <= int(b['Height'])*s-im.height <= 4*s for s in (1,2)), (im.size,b)
    except BaseException:
        path.unlink(missing_ok=True)
        raise


def minimum_capture(name,pid,current_height=720):
    run(name + '-resize',[ROOT / 'build/m3b-window-resize',pid,640,360,current_height])
    time.sleep(.3)
    assert window(pid)['kCGWindowBounds']['Width'] == 640
    capture(name + '-640x360',pid)
    run(name + '-restore',[ROOT / 'build/m3b-window-resize',pid,1280,720,360])
    time.sleep(.2)


normal = Path.home() / 'Library/Application Support/The Last Stop/saves'
before = {'data':hashes(ROOT / 'data'),'normal_saves':hashes(normal)}
run('check',['odin','check','src'])
run('release',['odin','build','src','-out:build/the-last-stop','-export-dependencies:json',
               '-export-dependencies-file:build/evidence/m3b/release-deps.json'])
assert 'content_edit' not in (OUT / 'release-deps.json').read_text()
run('dev',['odin','build','src','-define:DEV_TOOLS=true','-out:build/the-last-stop-dev'])
run('window-helper',['swiftc','tests/runtime/window_info.swift','-o','build/m3b-window-info'])
run('resize-helper',['swiftc','tests/runtime/res640_window.swift','-o','build/m3b-window-resize'])
watched = ('title','prologue','boarding','travel','obstacle','puzzle','carried','installed','cranking','cleared',
           'return','arrival','supper','end_card','title_end')
skipped = ('title','intro_skip','travel_skip','obstacle_skip','puzzle','carried','installed','cranking','cleared',
           'return_skip','arrival_skip','end_skip','title_end')

for route in ('advance','skip','restart'):
    rendezvous = OUT / ('native-' + route)
    if rendezvous.exists(): shutil.rmtree(rendezvous)
    rendezvous.mkdir()
    with tempfile.TemporaryDirectory(prefix='m3b-native-profile-',dir=OUT) as tmp:
        profile=Path(tmp)
        stages = watched if route!='skip' else skipped
        done=set()
        starts=0
        reload_label=''
        while True:
            starts+=1
            args=[ROOT / 'build/the-last-stop-dev','--save-dir',profile,'--project-root',ROOT,
                  '--autoplay','story-skip' if route=='skip' else 'story-advance']
            name='native-%s-process-%02d' % (route,starts)
            log=open(OUT / (name + '.stdout.txt'),'wb')
            err=open(OUT / (name + '.stderr.txt'),'wb')
            env=dict(os.environ,TLS_M2_EVIDENCE=str(rendezvous),TLS_M3B_RELOAD_LABEL=reload_label)
            p=subprocess.Popen(list(map(str,args)),cwd='/tmp',env=env,stdout=log,stderr=err)
            killed=False
            try:
                deadline=time.monotonic()+160
                while time.monotonic()<deadline:
                    if p.poll() is not None:
                        assert p.returncode==0 and set(stages)<=done,(route,p.returncode,done)
                        break
                    ready=next((s.stem for s in sorted(rendezvous.glob('*.ready'))
                                if not (rendezvous / (s.stem+'.release')).exists()),None)
                    if ready:
                        time.sleep(.18)  # ready marker precedes the actual frozen render
                        capture('native-%s-%s' % (route,ready),p.pid)
                        saved=profile / 'chapter_01.json'
                        if saved.exists(): (OUT / ('native-%s-%s.save.json' % (route,ready))).write_bytes(saved.read_bytes())
                        metadata=(rendezvous / (ready+'.ready')).read_text()
                        if ready.startswith('reload_'):
                            expected={'reload_intro':'Station_Intro','reload_crank':'Playing','reload_farewell':'Station_Outro'}[ready]
                            assert 'mode='+expected in metadata and 'story_cues=0' in metadata,metadata
                            if ready=='reload_crank': assert 'phase=Cranking' in metadata,metadata
                        if route=='advance' and ready in ('travel','supper','end_card'):
                            minimum_capture('native-%s-%s' % (route,ready),p.pid)
                        if route=='restart' and ready in ('prologue','cranking','arrival'):
                            expected={'prologue':'chapter_start','cranking':'puzzle','arrival':'arrival'}[ready]
                            assert json.loads(saved.read_bytes())['checkpoint']==expected
                            reload_label={'prologue':'intro','cranking':'crank','arrival':'farewell'}[ready]
                            p.kill();p.wait(timeout=5);killed=True
                        done.add(ready)
                        (rendezvous / (ready+'.release')).write_text('PID/title/window verified and captured\n')
                        if killed: break
                    time.sleep(.03)
                else: raise AssertionError(('native timeout',route,done))
            finally:
                if p.poll() is None: p.kill();p.wait(timeout=5)
                log.close();err.close()
                record(dict(name=name,argv=list(map(str,args)),pid=p.pid,cwd='/tmp',exit_code=p.returncode,
                            intentional_sigkill=killed,reload_label=reload_label))
            if not killed: break
        final=json.loads((profile / 'chapter_01.json').read_bytes())
        assert final['checkpoint']=='complete' and final['puzzle']['phase']=='cleared'
        if route=='restart': assert starts==4 and {'reload_intro','reload_crank','reload_farewell'}<=done
        (OUT / ('native-'+route+'-result.json')).write_text(json.dumps(dict(processes=starts,stages=sorted(done),save=final),indent=2)+'\n')
        print('PASS native',route,'processes',starts,flush=True)
        if route=='advance':
            # Release is independent of development autoplay; Title must preserve
            # an existing completed record and offer Continue.
            log=open(OUT / 'native-release-title.log','wb')
            p=subprocess.Popen([str(ROOT / 'build/the-last-stop'),'--save-dir',str(profile)],cwd='/tmp',stdout=log,stderr=log)
            try:
                time.sleep(1)
                capture('native-release-title',p.pid)
            finally:
                p.terminate();p.wait(timeout=5);log.close()
                record(dict(name='native-release-title',pid=p.pid,exit_code=p.returncode,intentional_sigterm=True))
            assert json.loads((profile / 'chapter_01.json').read_bytes())==final

after={'data':hashes(ROOT / 'data'),'normal_saves':hashes(normal)}
assert before==after
(OUT / 'native-isolation.json').write_text(json.dumps(dict(before=before,after=after),indent=2)+'\n')
print('PASS native whole journey, all scene skips, intro/crank/farewell SIGKILL + relaunch; human playtest remains unverified')
