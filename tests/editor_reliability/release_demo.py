#!/usr/bin/env python3
"""Ordinary release, no Studio, native PID-scoped keyboard/AX; disposable HOME."""
import errno, importlib.util, json, os, shutil, subprocess, sys, tempfile, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/evidence/e4'
spec=importlib.util.spec_from_file_location('release_native_helper',ROOT/'tests/dev_editor/native.py');native=importlib.util.module_from_spec(spec);spec.loader.exec_module(native);native.OUT=OUT
state=json.loads((OUT/'demo-state.json').read_text());root=Path(state['root']);home=Path(state['home'])
assert not (root/'.studio').exists()
cli=root/'build/tls-content'
if cli.exists(): cli.rename(cli.with_name('tls-content.disabled'))
assert not cli.exists()
release=str(root/'build/e4-release-current');helper=OUT/'window-info';control=OUT/'window-control';key=OUT/'pid-key'
subprocess.run(['swiftc',str(ROOT/'tests/assets/pol1_key.swift'),'-o',str(key)],check=True)
env=dict(os.environ,HOME=str(home));env.pop('TLS_SAVE_DIR',None);rows=[]
def run(args):
    p=subprocess.run(list(map(str,args)),env=env,capture_output=True,timeout=30)
    rows.append(dict(argv=list(map(str,args)),exit=p.returncode,stdout=p.stdout.decode(errors='replace'),stderr=p.stderr.decode(errors='replace')))
    assert p.returncode==0,p.stderr;return p

build_argv=['odin','build','src','-out:'+release]
build=subprocess.run(build_argv,cwd=ROOT,env=env,capture_output=True,timeout=120)
assert build.returncode==0,build.stderr

def hashes():return {str(p.relative_to(root)):__import__('hashlib').sha256(p.read_bytes()).hexdigest() for p in (root/'data').rglob('*') if p.is_file()}
before=hashes();sentinel=home/'Library/Application Support/The Last Stop/saves/chapter_01.json';normal=sentinel.read_bytes()
profile=Path(tempfile.mkdtemp(prefix='release-play-',dir=str(root)))
with (OUT/'release-play.log').open('wb') as log:
    p=subprocess.Popen([release,'--project-root',str(root),'--save-dir',str(profile)],env=env,cwd='/tmp',stdout=log,stderr=log)
    try:
        time.sleep(.8);native.capture('release-title',p.pid,helper)
        run([control,p.pid,'focus']);time.sleep(.3)
        for _ in range(3):
            run([key,p.pid,36,.12]);time.sleep(.8)
            if (profile/'chapter_01.json').exists():break
        assert (profile/'chapter_01.json').exists(), ('native key was not consumed',p.pid,profile)
        for _ in range(5):
            save=json.loads((profile/'chapter_01.json').read_text())
            if save['checkpoint']=='puzzle':break
            run([key,p.pid,7,.12]);time.sleep(.8)
        assert save['checkpoint']=='puzzle',save
        # Puzzle is durable during Obstacle_Arrival, before Playing. Finish that
        # cutscene explicitly; X in Playing is harmless and cannot clear a puzzle.
        run([key,p.pid,7,.12]);time.sleep(.8)
        # Release ignores F4: no authoring state/storage can appear.
        run([key,p.pid,118,.06]);time.sleep(.25);native.capture('release-playing-no-studio',p.pid,helper)
        # Complete with real native keyboard input, no DEV/autoplay/test hooks.
        # Ground is continuous; world-edge anchors remove timing drift.
        run([key,p.pid,2,9.0]);run([key,p.pid,0,.65]);time.sleep(.2)
        native.capture('release-at-handle',p.pid,helper);run([control,p.pid,'focus'])
        for _ in range(3):
            run([key,p.pid,14,.12]);time.sleep(.5)
            held=json.loads((profile/'chapter_01.json').read_text())
            if held['puzzle']['handle_location']=='held':break
        assert held['puzzle']['handle_location']=='held',held
        run([key,p.pid,0,10.0]);run([key,p.pid,2,3.2]);time.sleep(.2)
        native.capture('release-at-winch',p.pid,helper);run([control,p.pid,'focus'])
        for _ in range(3):
            run([key,p.pid,14,.12]);time.sleep(.5)
            installed=json.loads((profile/'chapter_01.json').read_text())
            if installed['puzzle']['handle_location']=='installed':break
        assert installed['puzzle']['handle_location']=='installed',installed
        for _ in range(3):
            run([key,p.pid,14,.12]);time.sleep(.5)
            started=json.loads((profile/'chapter_01.json').read_text())
            if started['puzzle']['phase']!='blocked':break
        deadline=time.monotonic()+10
        while time.monotonic()<deadline:
            save=json.loads((profile/'chapter_01.json').read_text())
            if save['puzzle']['phase']=='cleared':break
            time.sleep(.05)
        assert save['puzzle']['phase']=='cleared',save
        for _ in range(3):
            run([key,p.pid,15,.12]);time.sleep(.8)
            if json.loads((profile/'chapter_01.json').read_text())['checkpoint']!='puzzle':break
        for _ in range(5):
            save=json.loads((profile/'chapter_01.json').read_text())
            if save['checkpoint']=='complete':break
            run([key,p.pid,7,.12]);time.sleep(.8)
        assert save['checkpoint']=='complete',save
        native.capture('release-complete-no-studio',p.pid,helper)
        run([control,p.pid,'close']);p.wait(timeout=10);assert p.returncode==0
        rows.append(dict(name='ordinary-release-play',pid=p.pid,exit=p.returncode,save=save,pid_scoped_synthetic_keys=True,cli_unavailable=True))
    finally:
        if p.poll() is None:p.kill();p.wait(timeout=5)
saved_bytes=(profile/'chapter_01.json').read_bytes()
with (OUT/'release-resume.log').open('wb') as log:
    p=subprocess.Popen([release,'--project-root',str(root),'--save-dir',str(profile)],env=env,cwd='/tmp',stdout=log,stderr=log)
    try:
        time.sleep(.8);run([control,p.pid,'focus']);run([key,p.pid,36,.12]);time.sleep(.8)
        native.capture('release-resume-complete',p.pid,helper)
        run([control,p.pid,'close']);p.wait(timeout=10);assert p.returncode==0
        assert (profile/'chapter_01.json').read_bytes()==saved_bytes
        rows.append(dict(name='ordinary-release-resume-complete',pid=p.pid,exit=p.returncode,save_bytes_unchanged=True))
    finally:
        if p.poll() is None:p.kill();p.wait(timeout=5)
# The diagnostic itself is captured in a real ordinary-release window.
interposer=OUT/'lock-error.dylib';run(['cc','-dynamiclib',ROOT/'tests/editor_reliability/lock_error.c','-o',interposer])
for code in (errno.ENOLCK,errno.EINVAL,errno.EAGAIN):
    with (OUT/('release-errno-'+str(code)+'.log')).open('wb') as log:
        p=subprocess.Popen([release,'--project-root',str(root),'--save-dir',str(root/('release-lock-'+str(code)))],env=dict(env,DYLD_INSERT_LIBRARIES=str(interposer),TLS_E4_LOCK_ERRNO=str(code)),cwd='/tmp',stdout=log,stderr=log)
        try:
            time.sleep(.8);native.capture('release-errno-'+str(code),p.pid,helper);run([control,p.pid,'close']);p.wait(timeout=10);assert p.returncode==0
            rows.append(dict(name='release-lock-error',errno=code,pid=p.pid,exit=p.returncode))
        finally:
            if p.poll() is None:p.kill();p.wait(timeout=5)
assert hashes()==before and not (root/'.studio').exists() and sentinel.read_bytes()==normal
(OUT/'release-native-results.json').write_text(json.dumps(dict(build_argv=build_argv,build_exit=build.returncode,rows=rows,authored_hashes_unchanged=True,studio_absent=True,normal_save_unchanged=True,all_processes_reaped=True),indent=2)+'\n')
print('PASS ordinary release native Start/skip/puzzle/Complete/resume/close; F4 absent; ENOLCK/EINVAL/EAGAIN captures')
