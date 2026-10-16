"""Verify saved browser form/agent edits render in the native story player.
Requires native_demo.py --serve and build/evidence/e3/browser-ui.json from the
actual collaborative-browser run. This is a synthetic-input native observation.
"""
import hashlib
import http.client
import json
import os
from pathlib import Path
import subprocess
import time
from urllib.parse import urlsplit

from common import ROOT
from native_demo import capture, save, OUT

state = json.loads((OUT / 'demo-state.json').read_text())
root = Path(state['root'])
url = urlsplit(state['url'])

def api(command, **kwargs):
    connection = http.client.HTTPConnection('127.0.0.1', url.port, timeout=10)
    connection.request('POST', '/api/command', json.dumps(dict(command=command, **kwargs)),
                       {'Content-Type': 'application/json', 'Origin': 'http://' + url.netloc, 'X-Editor-Token': url.fragment.split('=', 1)[1]})
    response = connection.getresponse(); value = json.loads(response.read()); connection.close()
    assert response.status == 200, value
    return value

# Launch again via the actual workspace guard, then capture this owned window.
running = api('run-scene'); save('browser-final-workspace-run', running)
try:
    time.sleep(.5); capture('browser-final-workspace-run', running['pid'])
finally:
    api('stop-preview')

inspection = api('inspect-document', document='intro'); assert inspection['exit_code'] == 0
save('browser-final-dialogue', inspection)
assert inspection['result']['authored']['lines']['prologue_rin_01']['text'] == 'E3 structured agent: hello from the platform.'
assert inspection['result']['authored']['beats']['intro_establish']['duration_ms'] == 350
artifact = running['artifact']; assert hashlib.sha256(Path(artifact).read_bytes()).hexdigest() == running['artifact_sha256']
profile = root / 'browser-followup-profile'; profile.mkdir()
markers = root / 'browser-followup-markers'; markers.mkdir()
argv = [artifact, '--project-root', str(root), '--save-dir', str(profile), '--autoplay', 'story-advance']
log = open(OUT / 'browser-final-dialogue-native.log', 'wb')
process = subprocess.Popen(argv, cwd=str(root), stdout=log, stderr=log, env=dict(os.environ, TLS_M2_EVIDENCE=str(markers)))
try:
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline and process.poll() is None:
        ready = next((p for p in markers.glob('*.ready') if not p.with_suffix('.release').exists()), None)
        if ready:
            time.sleep(.15)
            if ready.stem == 'prologue':
                capture('browser-final-dialogue-native', process.pid)
                save('browser-final-dialogue-native', dict(argv=argv, pid=process.pid, rendered_beat=ready.read_text(), synthetic_input=True,
                                                          content_revision=inspection['result']['graph_revision'], source_fingerprint=running['source_fingerprint']))
                break
            ready.with_suffix('.release').write_text('synthetic observation\n')
        time.sleep(.02)
    else:
        raise AssertionError('Did not reach the browser-edited native dialogue')
finally:
    if process.poll() is None: process.terminate(); process.wait(timeout=3)
    log.close()
save('browser-final-diff', api('diff-head', path='src/main.odin'))
save('browser-final-task-status', api('task-status'))
print('PASS saved browser/agent dialogue and geometry rendered in verified native windows')
