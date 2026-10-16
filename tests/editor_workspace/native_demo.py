#!/usr/bin/env python3
"""E3 real HTTP/compiler/native evidence in a disposable committed checkout.
--serve leaves the local bridge available for a browser demonstration until SIGTERM.
No authored project data or normal player save is changed.
"""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import struct
import tempfile
import time

from common import ROOT, Client, project

OUT = ROOT / 'build/evidence/e3'
OUT.mkdir(parents=True, exist_ok=True)

def save(name, value):
    (OUT / (name + '.json')).write_text(json.dumps(value, indent=2) + '\n')

def capture(name, pid):
    helper = OUT / 'window-info'
    if not helper.exists():
        subprocess.run(['swiftc', str(ROOT / 'tests/editor_ui/game_window.swift'), '-o', str(helper)], check=True)
    window = json.loads(subprocess.check_output([str(helper), str(pid)]))
    assert window['kCGWindowOwnerPID'] == pid and window['kCGWindowLayer'] == 0
    assert window['kCGWindowName'] == 'The Last Stop', window
    path = OUT / (name + '.png')
    save(name + '-window', window)
    try:
        subprocess.run(['/usr/sbin/screencapture', '-x', '-o', '-l' + str(window['kCGWindowNumber']), str(path)], check=True)
        png = path.read_bytes()
        assert png[:8] == b'\x89PNG\r\n\x1a\n'
        width, height = struct.unpack('>II', png[16:24])
        bounds = window['kCGWindowBounds']
        assert any(0 <= int(bounds['Width']) * scale - width <= 4 * scale and 0 <= int(bounds['Height']) * scale - height <= 4 * scale for scale in (1, 2)), ((width, height), bounds)
    except BaseException:
        path.unlink(missing_ok=True)
        raise
    return window

def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--serve', action='store_true'); parser.add_argument('--journeys', action='store_true'); args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='tls-e3-native-', dir='/tmp') as directory:
        root = Path(directory).resolve(); project(root)
        # Reflect E3 source and actual current orchestration evidence in the disposable workspace.
        shutil.copytree(ROOT / 'editor', root / 'editor', dirs_exist_ok=True, ignore=shutil.ignore_patterns('__pycache__'))
        shutil.copy2(ROOT / 'docs/ORCHESTRATION_LOG.md', root / 'docs/ORCHESTRATION_LOG.md')
        (root / 'build/studio').mkdir(parents=True, exist_ok=True)
        observation = OUT / 't3-observation.json'
        if observation.exists(): shutil.copy2(observation, root / 'build/studio/orchestration.json')
        client = Client(root)
        try:
            before = client.inspect(); doc = copy.deepcopy(before['authored']); line = doc['order'][0]
            doc['lines'][line]['text'] = 'E3 Studio: a saved dialogue line.'; doc['lines'][line]['delivery'] = 'offscreen'
            # Put the edited line first for an unambiguous rendered dialogue capture.
            line_beat = next(b for b in doc['beat_order'] if doc['beats'][b].get('line') == line)
            doc['beat_order'].remove(line_beat); doc['beat_order'].insert(0, line_beat)
            doc['order'] = [doc['beats'][b]['line'] for b in doc['beat_order'] if doc['beats'][b]['kind'] == 'line']
            stage = next(b for b in doc['beat_order'] if doc['beats'][b]['kind'] == 'stage'); doc['beats'][stage]['duration_ms'] = 100
            saved = client.restore(before, doc); assert saved['exit_code'] == 0; save('dialogue-save', dict(before=before, after=client.inspect(), response=saved))
            chapter = client.inspect('oliver_flower_market'); chapter_doc = copy.deepcopy(chapter['authored']); chapter_doc['strings']['find_hint_gentle'] = 'E3 Studio saved text: follow the rope.'
            assert client.restore(chapter, chapter_doc)['exit_code'] == 0
            scene = client.api('inspect-scene')['result']; authored = copy.deepcopy(scene['authored']); authored['objects']['crank_handle']['position'] = [1192, 256]
            authored['objects']['crank_handle']['interaction'] = [-40, -16, 96, 64]
            assert client.restore(scene, authored)['exit_code'] == 0
            build = client.job('build-dev'); save('native-workspace-build', build); assert build['exit_code'] == 0 and build['current_source'], build
            running = client.api('run-scene'); save('native-workspace-run', running); assert running['running']
            time.sleep(1); capture('workspace-run-scene', running['pid'])
            save('native-workspace-preview-status', client.api('preview-status'))
            stopped = client.api('stop-preview'); assert not stopped['running']; save('native-workspace-stop', stopped)
            save('real-task-status', client.api('task-status'))
            if args.journeys:
                for route in ('advance', 'skip', 'restart'):
                    rendezvous = root / ('journey-' + route); rendezvous.mkdir()
                    profile = root / ('profile-' + route); profile.mkdir()
                    stages, starts, reload_label = set(), 0, ''
                    while True:
                        starts += 1
                        argv = [build['artifact'], '--project-root', str(root), '--save-dir', str(profile), '--autoplay', 'story-skip' if route == 'skip' else 'story-advance']
                        log = open(OUT / ('edited-journey-' + route + '-' + str(starts) + '.log'), 'wb')
                        process = subprocess.Popen(argv, cwd=str(root), stdout=log, stderr=log, env=dict(os.environ, TLS_M2_EVIDENCE=str(rendezvous), TLS_M3B_RELOAD_LABEL=reload_label))
                        killed = False
                        try:
                            deadline = time.monotonic() + 120
                            while process.poll() is None and time.monotonic() < deadline:
                                ready = next((p for p in sorted(rendezvous.glob('*.ready')) if not p.with_suffix('.release').exists()), None)
                                if ready:
                                    name = ready.stem; stages.add(name); time.sleep(.14)
                                    if name in ('prologue', 'arrival', 'title_end'): capture('edited-' + route + '-' + name, process.pid)
                                    if route == 'restart' and name in ('prologue', 'cranking', 'arrival'):
                                        reload_label = {'prologue': 'intro', 'cranking': 'crank', 'arrival': 'farewell'}[name]
                                        process.kill(); process.wait(timeout=3); killed = True
                                    ready.with_suffix('.release').write_text('Observed synthetic native rendezvous\n')
                                    if killed: break
                                time.sleep(.02)
                            if not killed:
                                process.wait(timeout=3); assert process.returncode == 0
                        finally:
                            if process.poll() is None: process.kill(); process.wait(timeout=3)
                            log.close()
                        if not killed: break
                    final = json.loads((profile / 'chapter_01.json').read_text())
                    assert final['checkpoint'] == 'complete' and final['puzzle']['phase'] == 'cleared', final
                    save('edited-journey-' + route, dict(starts=starts, stages=sorted(stages), save=final, synthetic_input=True, artifact=build['artifact']))
            if args.serve:
                save('demo-state', dict(root=str(root), url='http://127.0.0.1:{}/#token={}'.format(client.server.server_port, client.bridge.token), pid=os.getpid()))
                print('Disposable E3 demo ready', flush=True)
                active = [True]
                signal.signal(signal.SIGTERM, lambda *_: active.__setitem__(0, False))
                while active[0]: time.sleep(.2)
        finally:
            client.close()
    print('E3 native demonstration finished; owned processes stopped and temporary project removed', flush=True)

if __name__ == '__main__': main()
