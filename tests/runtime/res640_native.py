#!/usr/bin/env python3
"""T-RES-640 native gate: real window resizing, PID-only captures and autoplay.
No desktop capture; all launches use a disposable HOME and --save-dir.
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
OUT = ROOT / 'build/evidence/res640'
OUT.mkdir(parents=True, exist_ok=True)
records = []


def record(value):
    records.append(value)
    (OUT / 'native.commands.json').write_text(json.dumps(records, indent=2) + '\n')


def run(name, args, timeout=120):
    p = subprocess.run(list(map(str, args)), cwd=ROOT, capture_output=True, timeout=timeout)
    (OUT / (name + '.stdout.txt')).write_bytes(p.stdout)
    (OUT / (name + '.stderr.txt')).write_bytes(p.stderr)
    record(dict(name=name, argv=list(map(str, args)), exit_code=p.returncode))
    assert p.returncode == 0, (name, p.returncode, p.stderr.decode())
    return p


def window(pid):
    deadline = time.monotonic() + 10
    while True:
        p = subprocess.run([str(ROOT / 'build/res640-window-info'), str(pid)], capture_output=True, check=True)
        matches = json.loads(p.stdout)
        if matches or time.monotonic() >= deadline:
            break
        time.sleep(.1)
    assert len(matches) == 1, (pid, matches)
    w = matches[0]
    assert w['kCGWindowOwnerPID'] == pid and w['kCGWindowName'] == 'The Last Stop'
    return w


def resize(pid, width, height, current_height):
    run('resize-%s-%s-%s' % (pid, width, height), [ROOT / 'build/res640-window', pid, width, height, current_height])
    deadline = time.monotonic() + 4
    while time.monotonic() < deadline:
        w = window(pid)
        if w['kCGWindowBounds']['Width'] == width and w['kCGWindowBounds']['Height'] == height + 32:
            time.sleep(.25)
            return
        time.sleep(.05)
    raise AssertionError(('native client size mismatch', width, height, w))


def capture(name, pid, width, height):
    w = window(pid)
    assert w['kCGWindowBounds']['Width'] == width
    assert w['kCGWindowBounds']['Height'] == height + 32  # current native title bar
    (OUT / (name + '.window.json')).write_text(json.dumps(w, indent=2) + '\n')
    image = OUT / (name + '.png')
    try:
        run(name + '-capture', ['/usr/sbin/screencapture', '-x', '-o', '-l' + str(w['kCGWindowNumber']), image])
        assert image.stat().st_size > 1000
    except BaseException:
        image.unlink(missing_ok=True)
        raise


def both_sizes(name, pid):
    capture(name + '-1280x720', pid, 1280, 720)
    resize(pid, 640, 360, 720)
    capture(name + '-640x360', pid, 640, 360)
    resize(pid, 1280, 720, 360)


def hashes():
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted((ROOT / 'data').rglob('*')) if p.is_file()}


run('native-build-release', ['odin', 'build', 'src', '-out:build/the-last-stop'])
run('native-build-dev', ['odin', 'build', 'src', '-define:DEV_TOOLS=true', '-out:build/the-last-stop-dev'])
run('native-build-window-info', ['swiftc', 'tests/runtime/window_info.swift', '-o', 'build/res640-window-info'])
run('native-build-resize', ['swiftc', 'tests/runtime/res640_window.swift', '-o', 'build/res640-window'])
before = hashes()
with tempfile.TemporaryDirectory(prefix='native-profile-', dir=OUT) as tmp:
    profile = Path(tmp)
    home = profile / 'home'; home.mkdir()
    env = dict(os.environ, HOME=str(home))
    def launch(name, binary, args=(), extra_env=None):
        argv = [ROOT / ('build/' + binary), '--save-dir', profile / 'saves', '--project-root', ROOT, *args]
        log = open(OUT / (name + '.log'), 'wb')
        p = subprocess.Popen(list(map(str, argv)), cwd='/tmp', env=dict(env, **(extra_env or {})), stdout=log, stderr=log)
        return p, log, argv
    def reap(name, p, log, argv, expected=None):
        try:
            if p.poll() is None: p.terminate()
            p.wait(timeout=5)
        except subprocess.TimeoutExpired:
            p.kill(); p.wait(timeout=5)
        finally:
            log.close()
            record(dict(name=name, argv=list(map(str, argv)), cwd='/tmp', pid=p.pid,
                        exit_code=p.returncode, expected_exit_code=expected,
                        terminated_after_capture=expected is None))
        if expected is not None: assert p.returncode == expected

    p, log, argv = launch('release-title', 'the-last-stop')
    try:
        time.sleep(1)
        both_sizes('release-title', p.pid)
        resize(p.pid, 1000, 700, 720)
        capture('release-title-letterboxed-1000x700', p.pid, 1000, 700)
        resize(p.pid, 1280, 720, 700)
        # Request a below-minimum native size and verify the OS/raylib constraint.
        run('minimum-clamp-request', [ROOT / 'build/res640-window', p.pid, 400, 200, 720])
        time.sleep(.4)
        w = window(p.pid)
        assert w['kCGWindowBounds']['Width'] >= 640 and w['kCGWindowBounds']['Height'] >= 392
        (OUT / 'minimum-clamp.window.json').write_text(json.dumps(w, indent=2) + '\n')
    finally:
        reap('release-title', p, log, argv)
    rendezvous = profile / 'rendezvous'; rendezvous.mkdir()
    p, log, argv = launch('dev-autoplay', 'the-last-stop-dev', ['--autoplay', 'res640'], {'TLS_M2_EVIDENCE': str(rendezvous)})
    try:
        for stage in ('title', 'start', 'shelf', 'carried', 'installed', 'cranking', 'cleared', 'returned'):
            ready = rendezvous / (stage + '.ready')
            deadline = time.monotonic() + 35
            while not ready.exists() and time.monotonic() < deadline:
                assert p.poll() is None, ('early exit', stage, p.returncode)
                time.sleep(.04)
            assert ready.exists(), ('autoplay timeout', stage)
            time.sleep(.25)
            (OUT / (stage + '.state.txt')).write_bytes(ready.read_bytes())
            if stage in ('title', 'start', 'carried', 'cleared'):
                both_sizes('dev-' + stage, p.pid)
            else:
                capture('dev-' + stage + '-1280x720', p.pid, 1280, 720)
            saved = profile / 'saves/chapter_01.json'
            if saved.exists():
                (OUT / (stage + '.save.json')).write_bytes(saved.read_bytes())
            (rendezvous / (stage + '.release')).write_text('verified game-window captures complete\n')
        p.wait(timeout=10)
        assert p.returncode == 0
        final = json.loads((profile / 'saves/chapter_01.json').read_bytes())
        assert final['save_version'] == 2 and final['checkpoint'] == 'returned'
        assert final['puzzle']['phase'] == 'cleared' and not final['puzzle']['snail_seen']
        assert not (home / 'Library/Application Support/The Last Stop/saves').exists()
        (OUT / 'native-final-save.json').write_text(json.dumps(final, indent=2) + '\n')
    finally:
        reap('dev-autoplay', p, log, argv, expected=0)
assert hashes() == before
(OUT / 'native-isolation.json').write_text(json.dumps(dict(data_before=before, data_after=hashes(),
    temporary_home=True, explicit_temporary_save_dir=True, all_owned_processes_reaped=True), indent=2) + '\n')
print('PASS native: title/start/carried/cleared at both client sizes; minimum constraint; real-input autoplay completion; isolated profiles and reaped processes')
