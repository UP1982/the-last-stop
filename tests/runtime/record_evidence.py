#!/usr/bin/env python3
"""Explicit native E0b gate. Reversible real-project CLI edits; no delegation.
Requires macOS screen capture. Uses PID+title-verified window-only captures.
"""
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/evidence/e0b'
CLI = ROOT / 'build/tls-content'
SCENE = 'data/scenes/oliver_obstacle.json'
OUT.mkdir(parents=True, exist_ok=True)
records = []


def run(name, args, cwd=ROOT):
    args = list(map(str, args))
    p = subprocess.run(args, cwd=cwd, capture_output=True, timeout=180)
    (OUT / (name + '.stdout.txt')).write_bytes(p.stdout)
    (OUT / (name + '.stderr.txt')).write_bytes(p.stderr)
    records.append({'name': name, 'argv': args, 'cwd': str(cwd), 'exit_code': p.returncode})
    (OUT / 'commands.json').write_text(json.dumps(records, indent=2) + '\n')
    assert p.returncode == 0, '%s exit %s: %s' % (name, p.returncode, p.stderr.decode())
    return p


def cli(name, command, request=None):
    args = [CLI, command, '--project-root', ROOT]
    if request is not None:
        path = OUT / (name + '.request.json')
        path.write_text(json.dumps(request, indent=2, ensure_ascii=False) + '\n')
        args += ['--request', path]
    return json.loads(run(name, args).stdout)


def data_hashes():
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted((ROOT / 'data').rglob('*')) if p.is_file()}


def native(name, args):
    stdout = open(OUT / (name + '.stdout.txt'), 'wb')
    stderr = open(OUT / (name + '.stderr.txt'), 'wb')
    p = subprocess.Popen(list(map(str, args)), cwd='/tmp', stdout=stdout, stderr=stderr)
    try:
        matches = []
        for _ in range(15):
            assert p.poll() is None, 'game exited before capture'
            result = subprocess.run([str(ROOT / 'build/e0b-window-info'), str(p.pid)], capture_output=True, check=True)
            matches = json.loads(result.stdout)
            if matches:
                break
            time.sleep(0.4)
        assert len(matches) == 1, 'No unique PID+title-verified game window: %r' % matches
        window = matches[0]
        assert window['kCGWindowOwnerPID'] == p.pid and window['kCGWindowName'] == 'The Last Stop'
        (OUT / (name + '.window.json')).write_text(json.dumps(window, indent=2) + '\n')
        time.sleep(0.8)
        image = OUT / (name + '.png')
        try:
            run(name + '-capture', ['/usr/sbin/screencapture', '-x', '-o', '-l' + str(window['kCGWindowNumber']), image])
        except BaseException:
            image.unlink(missing_ok=True)
            raise
        assert image.stat().st_size > 1000
    finally:
        if p.poll() is None:
            p.terminate()
        try:
            p.wait(timeout=5)
        except subprocess.TimeoutExpired:
            p.kill()
            p.wait(timeout=5)
        stdout.close()
        stderr.close()
        records.append({'name': name, 'argv': list(map(str, args)), 'cwd': '/tmp', 'pid': p.pid,
                        'exit_code': p.returncode, 'termination': 'SIGTERM after window capture; process reaped'})
        (OUT / 'commands.json').write_text(json.dumps(records, indent=2) + '\n')
    return (OUT / (name + '.stderr.txt')).read_text()


run('01-check-src', ['odin', 'check', 'src'])
run('02-build-release', ['odin', 'build', 'src', '-out:build/the-last-stop'])
run('03-build-dev', ['odin', 'build', 'src', '-define:DEV_TOOLS=true', '-out:build/the-last-stop-dev'])
run('04-m0-selftest', ['odin', 'run', 'src', '-define:M0_SELF_TEST=true', '-out:build/e0b-m0-test'])
run('05-m1-selftest', ['odin', 'run', 'src', '-define:M1_SELF_TEST=true', '-out:build/e0b-m1-test'])
run('06-runtime-tests', ['python3', '-B', 'tests/runtime/run.py'])
run('07-check-all', ['./scripts/check.sh'])
run('08-release-deps', ['odin', 'build', 'src', '-out:build/the-last-stop', '-export-dependencies:json',
                        '-export-dependencies-file:build/evidence/e0b/release-deps.json'])
assert 'content_edit' not in (OUT / 'release-deps.json').read_text()
run('09-window-helper', ['swiftc', 'tests/runtime/window_info.swift', '-o', 'build/e0b-window-info'])
initial = data_hashes()
original = (ROOT / SCENE).read_bytes()
(OUT / 'scene.before.json').write_bytes(original)
validation = cli('10-validate-original', 'validate-content')
request = json.loads((ROOT / 'tests/editor/fixtures/move-handle.json').read_bytes())
request.update(request_id='e0b_native_move', expected_revision=validation['graph_revision'])
request['operations'][0]['value'] = [528, 256]  # visible from deterministic initial camera
normal_save_root = Path.home() / 'Library/Application Support/The Last Stop/saves'

def saves():
    if not normal_save_root.exists():
        return None
    return {str(p.relative_to(normal_save_root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(normal_save_root.rglob('*')) if p.is_file()}

before_saves = saves()
try:
    moved = cli('11-apply-move', 'apply-edit', request)
    assert moved['commit_state'] == 'committed'
    changed = (ROOT / SCENE).read_bytes()
    (OUT / 'scene.after.json').write_bytes(changed)
    (OUT / 'scene.move.diff').write_text(''.join(difflib.unified_diff(original.decode().splitlines(True), changed.decode().splitlines(True), fromfile=SCENE+' before', tofile=SCENE+' moved')))
    log = native('12-native-moved', [ROOT / 'build/the-last-stop-dev', '--project-root', ROOT,
                 '--preview-scene', 'oliver_obstacle', '--preview-session', 'e0b-native-gate', '--dump-scene'])
    handle = next(line for line in log.splitlines() if line.startswith('E0B object=crank_handle '))
    assert 'position=[528, 256]' in handle, handle
    assert 'interaction_local=Recti{x = -40, y = -16, w = 96, h = 64}' in handle, handle
    assert 'interaction_world=Rectangle{x = 488, y = 240, width = 96, height = 64}' in handle, handle
    assert str(Path.home() / 'Library/Caches/The Last Stop/preview/e0b-native-gate') in log
finally:
    current = cli('13-current-revision', 'validate-content')
    if (ROOT / SCENE).read_bytes() != original:
        restore = dict(request, request_id='e0b_native_restore', expected_revision=current['graph_revision'],
                       operations=[{'op': 'restore_document', 'value': json.loads(original)}])
        result = cli('14-restore-document', 'apply-edit', restore)
        assert result['commit_state'] == 'committed'
assert data_hashes() == initial
run('15-data-identical', ['git', 'diff', '--exit-code', 'HEAD', '--', 'data/chapters', 'data/dialogue', 'data/legacy', 'data/assets'])
# The release binary uses its build/ parent from /tmp with Studio closed.
log = native('16-release-from-tmp', [ROOT / 'build/the-last-stop'])
assert 'Content root:' not in log
# Native malformed-content screen, using a disposable graph.
with tempfile.TemporaryDirectory(prefix='e0b-native-bad-', dir=ROOT / 'build') as tmp:
    bad = Path(tmp)
    shutil.copytree(ROOT / 'data', bad / 'data')
    (bad / 'data/chapters/chapter_01.json').write_bytes(b'{"kind":')
    log = native('17-native-error', [ROOT / 'build/the-last-stop', '--project-root', bad])
    assert 'expected_value' in log
assert saves() == before_saves
(OUT / 'restoration.json').write_text(json.dumps({'before': initial, 'after': data_hashes(),
    'all_data_bytes_identical_to_base': True, 'normal_saves_before': before_saves, 'normal_saves_after': saves()}, indent=2) + '\n')
print('PASS E0b native gate; inspect PID-verified window-only PNGs and logs in', OUT)
