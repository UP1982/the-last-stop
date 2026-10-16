"""Disposable committed projects and actual authenticated bridge requests."""
import http.client
import importlib.util
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('e3_server', ROOT / 'editor/server.py')
server_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server_module)


def project(destination):
    data = subprocess.check_output(['git', 'archive', 'HEAD'], cwd=str(ROOT))
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        archive.extractall(str(destination))
    # Include the integrated working source; E4 delivery is intentionally uncommitted.
    for name in ('src', 'shared', 'tools', 'editor', 'tests', 'scripts'):
        shutil.copytree(ROOT / name, destination / name, dirs_exist_ok=True, ignore=shutil.ignore_patterns('__pycache__'))
    shutil.copy2(ROOT / 'README.md', destination / 'README.md')
    # Local Git history for HEAD diffs; no account or remote mutation.
    subprocess.run(['git', 'init', '-q'], cwd=str(destination), check=True)
    subprocess.run(['git', 'add', '.'], cwd=str(destination), check=True)
    subprocess.run(['git', '-c', 'user.name=Disposable E3 test', '-c', 'user.email=e3@example.invalid', 'commit', '-qm', 'Disposable integrated working source'], cwd=str(destination), check=True)
    (destination / 'build').mkdir(exist_ok=True)
    result = subprocess.run([shutil.which('odin'), 'build', 'tools/content', '-out:build/tls-content'], cwd=str(destination), capture_output=True)
    assert result.returncode == 0, result.stderr.decode()


class Client:
    def __init__(self, root, reservations=()):
        self.server = server_module.make_server(root, reservations=reservations)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.bridge = self.server.bridge

    def raw(self, body, token=True, headers=None):
        connection = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=30)
        values = {'Content-Type': 'application/json', 'Origin': 'http://127.0.0.1:' + str(self.server.server_port)}
        if token:
            values['X-Editor-Token'] = self.bridge.token
        values.update(headers or {})
        path = '/api/draft' if isinstance(body, dict) and body.get('command') == 'write-draft' else '/api/command'
        connection.request('POST', path, json.dumps(body), values)
        response = connection.getresponse()
        status, result = response.status, json.loads(response.read())
        connection.close()
        return status, result

    def api(self, command, **kwargs):
        status, result = self.raw(dict(command=command, **kwargs))
        assert status == 200, (status, result)
        return result

    def job(self, command):
        started = self.api(command)
        deadline = time.monotonic() + 120
        logs, cursor = '', 0
        while time.monotonic() < deadline:
            result = self.api('job-status', job_id=started['job_id'], cursor=cursor)
            logs += result['log']; cursor = result['cursor']
            if result['state'] not in ('running', 'starting'):
                result['complete_log'] = logs
                return result
            time.sleep(.03)
        raise AssertionError('Compiler job did not finish')

    def inspect(self, document='intro'):
        response = self.api('inspect-document', document=document)
        assert response['exit_code'] == 0, response
        return response['result']

    def restore(self, before, authored, **kwargs):
        request = dict(protocol_version=1, request_id='e3_test', chapter=server_module.CHAPTER,
                       document=before['document'], expected_revision=before['graph_revision'],
                       operations=[dict(op='restore_document', value=authored)])
        request.update(kwargs)
        return self.api('apply-edit', request=request)

    def close(self):
        self.server.shutdown(); self.server.server_close(); self.thread.join(timeout=3); self.bridge.close()
