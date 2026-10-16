#!/usr/bin/env python3
"""M3 round-1 native regressions. Build outputs live in build/evidence/m3-fix.

Run after the release/DEV builds and check.sh. All content/profile experiments
live under /tmp. Only capture a uniquely PID-verified named game window.
"""
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/evidence/m3-fix'
CHAPTER = 'data/chapters/chapter_01.json'
records = []


def record(**row):
    records.append(row)
    (OUT / 'native-commands.json').write_text(json.dumps(records, indent=2) + '\n')


def run(name, argv, expected=0):
    p = subprocess.run(list(map(str, argv)), cwd=ROOT, capture_output=True, timeout=60)
    (OUT / (name + '.stdout.txt')).write_bytes(p.stdout)
    (OUT / (name + '.stderr.txt')).write_bytes(p.stderr)
    record(name=name, argv=list(map(str, argv)), exit_code=p.returncode)
    assert p.returncode == expected, (name, p.returncode, p.stdout, p.stderr)
    return p


def window(pid):
    rows = json.loads(subprocess.check_output([str(OUT / 'window-info'), str(pid)]))
    assert len(rows) == 1, (pid, rows)
    row = rows[0]
    assert row['kCGWindowOwnerPID'] == pid
    assert row['kCGWindowName'] == 'The Last Stop' and row['kCGWindowLayer'] == 0
    return row


def wait_for(predicate, process):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        assert process.poll() is None, ('game exited early', process.returncode)
        if predicate(): return
        time.sleep(.1)
    raise AssertionError('native rendezvous timeout')


def capture(name, process):
    run(name + '-resize', [OUT / 'window-resize', process.pid, 640, 360, 720])
    time.sleep(.3)
    row = window(process.pid)
    assert row['kCGWindowBounds']['Width'] == 640
    path = OUT / (name + '.png')
    (OUT / (name + '.window.json')).write_text(json.dumps(row, indent=2) + '\n')
    try:
        run(name + '-capture', ['/usr/sbin/screencapture', '-x', '-o', '-l' + str(row['kCGWindowNumber']), path])
        data = path.read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n'
        width, height = struct.unpack('>II', data[16:24])
        b = row['kCGWindowBounds']
        assert any(0 <= int(b['Width'])*s-width <= 4*s and
                   0 <= int(b['Height'])*s-height <= 4*s for s in (1, 2)), ((width, height), b)
    except BaseException:
        path.unlink(missing_ok=True)  # discard any non-game/unverified capture
        raise


def launch(name, binary, content, profile, rendezvous=None):
    args = [str(binary), '--project-root', str(content), '--save-dir', str(profile)]
    env = None
    if rendezvous:
        import os
        args += ['--autoplay', 'story-skip']
        env = dict(os.environ, TLS_M2_EVIDENCE=str(rendezvous))
    with (OUT / (name + '.stdout.txt')).open('wb') as stdout, (OUT / (name + '.stderr.txt')).open('wb') as stderr:
        p = subprocess.Popen(args, cwd='/tmp', env=env, stdout=stdout, stderr=stderr)
        try:
            wait_for(lambda: bool(json.loads(subprocess.check_output([str(OUT / 'window-info'), str(p.pid)]))), p)
            if rendezvous:
                wait_for(lambda: (rendezvous / 'title.ready').exists(), p)
                (rendezvous / 'title.release').touch()
                wait_for(lambda: (rendezvous / 'intro_skip.ready').exists(), p)
                assert 'mode=Station_Intro' in (rendezvous / 'intro_skip.ready').read_text()
                (OUT / 'footer-max-budget-state.txt').write_text((rendezvous / 'intro_skip.ready').read_text())
            time.sleep(.2)
            capture(name, p)
            if not rendezvous: assert not profile.exists(), 'v1 startup wrote a profile'
        finally:
            if p.poll() is None:
                p.terminate()
                try: p.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    p.kill(); p.wait(timeout=5)
            record(name=name, argv=args, pid=p.pid, exit_code=p.returncode, reaped=True)
    if not rendezvous:
        diagnostic = (OUT / (name + '.stderr.txt')).read_text()
        assert 'story_migration_required: Chapter content is schema v1; migrate to v2 to play' in diagnostic


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    run('native-window-info-build', ['swiftc', 'tests/runtime/window_info.swift', '-o', OUT / 'window-info'])
    run('native-window-resize-build', ['swiftc', 'tests/runtime/res640_window.swift', '-o', OUT / 'window-resize'])
    with tempfile.TemporaryDirectory(prefix='tls-m3-fix-native-', dir='/tmp') as directory:
        directory = Path(directory)
        content = directory / 'max-content'
        shutil.copytree(ROOT / 'data', content / 'data')
        shutil.copytree(ROOT / 'assets', content / 'assets')
        chapter = json.loads((content / CHAPTER).read_text())
        chapter['strings'].update(advance='W'*14, skip_scene='Skip scene', return_menu='Return to menu')
        (content / CHAPTER).write_text(json.dumps(chapter))
        (OUT / 'footer-max-budget-chapter.json').write_text(json.dumps(chapter, indent=2) + '\n')
        run('native-max-content-validate', [ROOT / 'build/tls-content', 'validate-content', '--project-root', content])
        rendezvous = directory / 'rendezvous'; rendezvous.mkdir()
        launch('footer-max-budget-640x360', OUT / 'the-last-stop-dev', content, directory / 'max-profile', rendezvous)
        chapter['strings']['advance'] = 'Continue through this quiet station scene whenever you are ready.'
        (content / CHAPTER).write_text(json.dumps(chapter))
        p = run('native-astra-string-rejected', [ROOT / 'build/tls-content', 'validate-content', '--project-root', content], expected=2)
        assert 'ui_text_budget' in p.stdout.decode()
        for name, path in [('chapter_01.json', CHAPTER),
                           ('oliver_intro.json', 'data/dialogue/oliver_intro.json'),
                           ('oliver_arrival.json', 'data/dialogue/oliver_arrival.json')]:
            shutil.copyfile(ROOT / 'tests/story/fixtures/v1' / name, content / path)
        run('native-v1-tool-validate', [ROOT / 'build/tls-content', 'validate-content', '--project-root', content])
        for variant in ('the-last-stop', 'the-last-stop-dev'):
            launch('v1-startup-' + variant, OUT / variant, content, directory / (variant + '-profile'))
    print('PASS native M3 fixes: max-budget footer and release/DEV v1 error screens; PID/window verified; /tmp profiles; all processes reaped')


if __name__ == '__main__': main()
