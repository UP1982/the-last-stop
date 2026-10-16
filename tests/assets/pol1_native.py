#!/usr/bin/env python3
"""Presentation gate using release keyboard input and PID-verified game captures.
Checkpoint fixtures use real save writers in disposable profiles. No normal saves,
authored content, story transitions or puzzle state are edited by this runner.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from contextlib import contextmanager
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/evidence/pol1'
OUT.mkdir(parents=True, exist_ok=True)
records = []

def record(**row):
    records.append(row)
    (OUT / 'native.commands.json').write_text(json.dumps(records, indent=2) + '\n')

def run(name, args):
    p = subprocess.run(list(map(str, args)), cwd=ROOT, capture_output=True, timeout=60)
    (OUT / (name + '.stdout.txt')).write_bytes(p.stdout)
    (OUT / (name + '.stderr.txt')).write_bytes(p.stderr)
    record(name=name, argv=list(map(str, args)), exit_code=p.returncode)
    assert p.returncode == 0, (name, p.returncode, p.stderr)
    return p

def hashes(path):
    if not path.exists(): return None
    return {str(p.relative_to(path)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(path.rglob('*')) if p.is_file()}

def window(pid):
    rows = json.loads(subprocess.check_output([str(OUT / 'window-info'), str(pid)]))
    assert len(rows) == 1, rows
    w = rows[0]
    assert w['kCGWindowOwnerPID'] == pid and w['kCGWindowName'] == 'The Last Stop'
    assert w['kCGWindowLayer'] == 0
    b = w['kCGWindowBounds']
    assert 1280 <= b['Width'] <= 1282 and 752 <= b['Height'] <= 754, b
    return w

def capture(name, p):
    assert p.poll() is None
    w = window(p.pid)
    path = OUT / (name + '-1280x720.png')
    try:
        run(name + '-capture', ['/usr/sbin/screencapture', '-x', '-o',
                               '-l' + str(w['kCGWindowNumber']), path])
        with Image.open(path) as im:
            b = w['kCGWindowBounds']
            assert any(0 <= int(b['Width'])*s-im.width <= 4*s and
                       0 <= int(b['Height'])*s-im.height <= 4*s for s in (1, 2)), (im.size, b)
    except BaseException:
        path.unlink(missing_ok=True)
        raise
    (OUT / (name + '.window.json')).write_text(json.dumps(w, indent=2) + '\n')
    return path

def key(p, code, hold=.06, settle=.16):
    run('key-' + str(len(records)), [OUT / 'key', p.pid, code, hold])
    time.sleep(settle)

@contextmanager
def launch(tmp, name, fixture=None, dev=False):
    profile = tmp / (name + '-saves')
    if fixture:
        run('seed-' + name, [OUT / 'save-fixtures', 'write-' + fixture,
                            '--project-root', ROOT, '--save-dir', profile])
    log = open(OUT / (name + '.log'), 'wb')
    binary = ROOT / ('build/the-last-stop-dev' if dev else 'build/the-last-stop')
    p = subprocess.Popen([str(binary), '--project-root', str(ROOT), '--save-dir', str(profile)],
                         cwd='/tmp', stdout=log, stderr=log)
    try:
        time.sleep(.8); window(p.pid)
        key(p, 36, settle=2) # New Game / Continue
        yield p, profile
    finally:
        if p.poll() is None:
            p.terminate()
            try: p.wait(timeout=5)
            except subprocess.TimeoutExpired: p.kill(); p.wait(timeout=5)
        log.close()
        record(name=name, pid=p.pid, exit_code=p.returncode, owned_process_reaped=True)

normal = Path.home() / 'Library/Application Support/The Last Stop/saves'
before = {k: hashes(v) for k,v in [('data', ROOT/'data'), ('assets', ROOT/'assets'), ('normal_saves', normal)]}
for name,args in [
    ('odin-check', ['odin','check','src']),
    ('build-release', ['odin','build','src','-out:build/the-last-stop']),
    ('build-dev', ['odin','build','src','-define:DEV_TOOLS=true','-out:build/the-last-stop-dev']),
    ('build-fixtures', ['odin','build','src','-define:M2_SELF_TEST=true','-out:'+str(OUT/'save-fixtures')]),
    ('build-key', ['swiftc','tests/assets/pol1_key.swift','-o',OUT/'key']),
    ('build-window-info', ['swiftc','tests/runtime/window_info.swift','-o',OUT/'window-info'])]:
    run(name,args)

with tempfile.TemporaryDirectory(prefix='tls-pol1-',dir='/tmp') as directory:
    tmp = Path(directory)
    with launch(tmp,'release-intro') as (p,profile):
        capture('prologue',p)
        # Wait through each short timed gesture; indefinite shots/lines only
        # advance on distinct real E presses. End at Oliver's boarding gesture.
        for delay in (.8,1.1,.16,.8,2.1,1.1,.16,.16,1.6):
            key(p,14,settle=delay)
        key(p,14,settle=.08)
        capture('boarding',p)
    with launch(tmp,'release-travel','boarded') as (p,profile):
        capture('travel',p)
    with launch(tmp,'release-arrival','arrival') as (p,profile):
        capture('arrival',p)
    with launch(tmp,'release-puzzle','shelf') as (p,profile):
        capture('puzzle-start',p)
        key(p,2,hold=12.0,settle=.25)
        key(p,0,hold=.6,settle=.25) # D: same controller path as human keyboard
        capture('handle-focus',p)
        key(p,14,settle=.3)
        key(p,0,hold=1.0,settle=.3) # A: leave focus to show the carry/drop prompt
        assert json.loads((profile/'chapter_01.json').read_text())['puzzle']['handle_location']=='held'
        capture('carried',p)
    with launch(tmp,'dev-intro',dev=True) as (p,profile):
        clean=capture('dev-prologue-clean',p)
        key(p,99,hold=.3,settle=.25) # F3, delivered to the verified owned PID
        overlay=capture('dev-prologue-f3',p)
        # Static label/header area changes; lower actor animation is excluded.
        with Image.open(clean) as a, Image.open(overlay) as b:
            scale=a.width/1280
            area=(0,int((32+68*2)*scale),a.width,int((32+104*2)*scale))
            assert ImageChops.difference(a.convert('RGB').crop(area),b.convert('RGB').crop(area)).getbbox()

after = {k: hashes(v) for k,v in [('data', ROOT/'data'), ('assets', ROOT/'assets'), ('normal_saves', normal)]}
assert before == after
(OUT/'native-isolation.json').write_text(json.dumps(dict(before=before,after=after,all_owned_processes_reaped=True),indent=2)+'\n')
print('PASS release captures: prologue, boarding, travel, arrival, puzzle start, handle focus, carried; DEV F3; profiles/content isolated; all owned PIDs reaped')
