#!/usr/bin/env python3
"""M2 native gate: development input through real raylib loop; PID-only captures.
No desktop/full-screen captures. All profiles are temporary and explicitly named.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/evidence/m2'
OUT.mkdir(parents=True, exist_ok=True)
records = []


def run(name, args, timeout=240):
    p = subprocess.run(list(map(str, args)), cwd=ROOT, capture_output=True, timeout=timeout)
    (OUT / (name + '.stdout.txt')).write_bytes(p.stdout)
    (OUT / (name + '.stderr.txt')).write_bytes(p.stderr)
    records.append(dict(name=name, argv=list(map(str, args)), exit_code=p.returncode))
    (OUT / 'commands.json').write_text(json.dumps(records, indent=2) + '\n')
    assert p.returncode == 0, (name, p.returncode, p.stderr.decode())
    return p


def hashes(path):
    if not path.exists(): return None
    return {str(p.relative_to(path)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(path.rglob('*')) if p.is_file()}


NORMAL = Path.home() / 'Library/Application Support/The Last Stop/saves'
before_data, before_normal = hashes(ROOT / 'data'), hashes(NORMAL)
run('01-check', ['odin', 'check', 'src'])
run('02-release', ['odin', 'build', 'src', '-out:build/the-last-stop', '-export-dependencies:json',
                   '-export-dependencies-file:build/evidence/m2/release-deps.json'])
assert 'content_edit' not in (OUT / 'release-deps.json').read_text()
run('03-dev', ['odin', 'build', 'src', '-define:DEV_TOOLS=true', '-out:build/the-last-stop-dev'])
run('04-m0', ['odin', 'run', 'src', '-define:M0_SELF_TEST=true', '-out:build/m2-m0'])
run('05-m1', ['odin', 'run', 'src', '-define:M1_SELF_TEST=true', '-out:build/m2-m1'])
run('06-runtime', ['python3', '-B', 'tests/runtime/run.py'])
run('07-m2', ['python3', '-B', 'tests/runtime/m2.py'])
run('08-check-all', ['./scripts/check.sh'])
run('09-window-helper', ['swiftc', 'tests/runtime/window_info.swift', '-o', 'build/m2-window-info'])


def window(pid):
    p = subprocess.run([str(ROOT / 'build/m2-window-info'), str(pid)], capture_output=True, check=True)
    matches = json.loads(p.stdout)
    assert len(matches) == 1, (pid, matches)
    w = matches[0]
    assert w['kCGWindowOwnerPID'] == pid and w['kCGWindowName'] == 'The Last Stop'
    return w


def capture(name, pid):
    w = window(pid)
    (OUT / (name + '.window.json')).write_text(json.dumps(w, indent=2) + '\n')
    image = OUT / (name + '.png')
    try:
        run(name + '-capture', ['/usr/sbin/screencapture', '-x', '-o',
                                '-l' + str(w['kCGWindowNumber']), image])
        assert image.stat().st_size > 1000
    except BaseException:
        image.unlink(missing_ok=True)
        raise


STAGES = ('shelf', 'carried', 'installed', 'cranking', 'cleared', 'returned')
for route in ('direct', 'drop', 'restart'):
    evidence = OUT / ('native-' + route)
    if evidence.exists(): shutil.rmtree(evidence)
    evidence.mkdir()
    with tempfile.TemporaryDirectory(prefix='native-profile-', dir=OUT) as tmp:
        profile = Path(tmp)
        done = set()
        starts = 0
        while len(done) < len(STAGES):
            starts += 1
            args = [ROOT / 'build/the-last-stop-dev', '--save-dir', profile, '--project-root', ROOT,
                    '--autoplay', 'drop' if route == 'drop' else 'direct']
            logname = 'native-%s-process-%02d' % (route, starts)
            stdout = open(OUT / (logname + '.stdout.txt'), 'wb')
            stderr = open(OUT / (logname + '.stderr.txt'), 'wb')
            p = subprocess.Popen(list(map(str, args)), cwd='/tmp', env=dict(os.environ, TLS_M2_EVIDENCE=str(evidence)),
                                 stdout=stdout, stderr=stderr)
            killed_for_restart = False
            try:
                deadline = time.monotonic() + 70
                while time.monotonic() < deadline:
                    assert p.poll() is None, (route, done, 'exited early', p.returncode)
                    ready = next((s for s in STAGES if s not in done and (evidence / (s + '.ready')).exists()), None)
                    if ready:
                        time.sleep(.25)  # at least one frozen rendered frame
                        capture('native-%s-%s' % (route, ready), p.pid)
                        (OUT / ('native-%s-%s.save.json' % (route, ready))).write_bytes((profile / 'chapter_01.json').read_bytes())
                        done.add(ready)
                        if route == 'restart' and ready != 'returned':
                            p.kill(); p.wait(timeout=5)
                            killed_for_restart = True
                        (evidence / (ready + '.release')).write_text('captured game window\n')
                        if killed_for_restart: break
                        if ready == 'returned':
                            p.wait(timeout=10)
                            assert p.returncode == 0
                            break
                    time.sleep(.04)
                else:
                    raise AssertionError(('native timeout', route, done))
            finally:
                if p.poll() is None:
                    p.kill(); p.wait(timeout=5)
                stdout.close(); stderr.close()
                records.append(dict(name=logname, argv=list(map(str, args)), cwd='/tmp', pid=p.pid,
                                    exit_code=p.returncode, deliberate_checkpoint_restart=killed_for_restart))
                (OUT / 'commands.json').write_text(json.dumps(records, indent=2) + '\n')
            if route != 'restart': assert len(done) == 6
        final = json.loads((profile / 'chapter_01.json').read_bytes())
        assert final['checkpoint'] == 'returned' and final['puzzle']['phase'] == 'cleared'
        assert not final['puzzle']['snail_seen']
        print('PASS native', route, 'processes', starts, flush=True)
        # Launch the RELEASE title with a real run: Continue must be visible.
        if route == 'direct':
            log = open(OUT / 'native-release-title.stderr.txt', 'wb')
            p = subprocess.Popen([str(ROOT / 'build/the-last-stop'), '--save-dir', str(profile)],
                                 cwd='/tmp', stdout=log, stderr=log)
            try:
                time.sleep(1.3)
                capture('native-release-continue-title', p.pid)
            finally:
                p.terminate(); p.wait(timeout=5); log.close()
            assert json.loads((profile / 'chapter_01.json').read_bytes()) == final
assert hashes(ROOT / 'data') == before_data
assert hashes(NORMAL) == before_normal
(OUT / 'isolation.json').write_text(json.dumps(dict(data_before=before_data,data_after=hashes(ROOT / 'data'),
    normal_saves_before=before_normal, normal_saves_after=hashes(NORMAL)), indent=2) + '\n')
print('PASS M2 native completions + fresh process restarts; human feel/readability UNVERIFIED', flush=True)
