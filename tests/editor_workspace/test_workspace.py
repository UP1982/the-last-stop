import base64
import copy
import http.client
import hashlib
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

from common import ROOT, Client, project, server_module


class SourceBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='tls-e3-boundary-', dir='/tmp')
        self.root = Path(self.temp.name).resolve()
        (self.root / 'src').mkdir(); (self.root / 'docs').mkdir()
        self.path = self.root / 'src/main.odin'; self.path.write_bytes(b'package main\r\n// \xc3\xa9\r\n')
        self.client = Client(self.root, reservations=('src/owned.odin',))

    def tearDown(self):
        self.client.close(); self.temp.cleanup()

    def request(self, **kwargs):
        body = dict(command='write-source', path='src/main.odin', expected_sha256=hashlib.sha256(self.path.read_bytes()).hexdigest(), text='package main\n', request_id='agent_e3')
        body.update(kwargs); return self.client.raw(body)

    def test_exact_bytes_noop_stale_atomic_history_and_mode(self):
        before = self.path.read_bytes(); self.path.chmod(0o640)
        file = self.client.api('read-file', path='src/main.odin')
        status, result = self.request(text=file['text'])
        self.assertEqual((status, result['commit_state']), (200, 'no_op')); self.assertEqual(self.path.read_bytes(), before)
        status, result = self.request(text='package main\n// new\n')
        self.assertEqual(result['commit_state'], 'committed'); self.assertEqual(self.path.stat().st_mode & 0o777, 0o640)
        history = json.loads(next((self.root / '.studio/source-history').glob('*.json')).read_text())
        self.assertEqual(base64.b64decode(history['before_base64']), before)
        self.assertEqual(history['request_id'], 'agent_e3')
        self.assertEqual(self.request(expected_sha256=file['sha256'])[0], 409)
        self.assertEqual(self.path.read_text(), 'package main\n// new\n')

    def test_all_roots_extensions_paths_symlinks_hardlinks_and_reservations(self):
        for path in ('/etc/passwd', '../outside.odin', 'src/../main.odin', 'src//main.odin', 'src/./main.odin', 'src\\main.odin', 'src/a\x00.odin', 'src/a\n.odin', '.git/config', 'build/main.odin', 'data/x.json', 'assets/a.py', 'docs/a.py', 'scripts/a.py', 'prompts/a.py', 'src/main.py', 'editor/a.sh'):
            with self.subTest(path=path): self.assertNotEqual(self.request(path=path)[0], 200)
        (self.root / 'src/owned.odin').write_text('owned')
        self.assertEqual(self.request(path='src/owned.odin')[0], 403)
        external = self.root / 'outside'; external.mkdir(); (external / 'a.odin').write_text('outside')
        (self.root / 'src/link').symlink_to(external, target_is_directory=True)
        (self.root / 'src/link.odin').symlink_to(self.path)
        for path in ('src/link/a.odin', 'src/link.odin'):
            self.assertEqual(self.request(path=path)[0], 403)
            self.assertNotEqual(self.client.raw(dict(command='read-file', path=path))[0], 200)
        os.link(self.path, self.root / 'src/hard.odin')
        self.assertEqual(self.request()[0], 403)
        self.assertFalse(self.client.api('read-file', path='src/main.odin')['writable'])

    def test_nonregular_oversize_deleted_and_schema_auth(self):
        os.mkfifo(self.root / 'src/pipe.odin')
        self.assertEqual(self.client.raw(dict(command='read-file', path='src/pipe.odin'))[0], 400)
        (self.root / 'src/big.odin').write_bytes(b'a' * (1024 * 1024 + 1))
        self.assertEqual(self.client.raw(dict(command='read-file', path='src/big.odin'))[0], 400)
        self.assertEqual(self.client.raw(dict(command='read-file', path='src/missing.odin'))[0], 404)
        self.assertEqual(self.client.raw(dict(command='list-project'), token=False)[0], 401)
        self.assertEqual(self.client.raw(dict(command='check-game', argv=['-anything']))[0], 400)
        self.assertEqual(self.client.raw(dict(command='write-source', path='src/main.odin'))[0], 400)

    def test_fail_before_rename_and_uncertain_after_rename(self):
        w = self.client.bridge.workspace
        original = w.journal
        def fail_history(*args): raise OSError('injected history persistence failure')
        with patch.object(w, 'journal', side_effect=fail_history):
            self.assertEqual(self.request()[0], 500)
        self.assertIn(b'\r\n', self.path.read_bytes())
        def fail_final(transaction, value):
            if value['state'] == 'committed': raise OSError('injected finalization failure')
            return original(transaction, value)
        with patch.object(w, 'journal', side_effect=fail_final):
            status, result = self.request()
        self.assertEqual(result['commit_state'], 'committed_durability_uncertain')
        self.assertEqual(self.path.read_text(), 'package main\n')

    def test_temp_write_sync_rename_faults_keep_complete_old_source(self):
        workspace = self.client.bridge.workspace
        original_bytes = self.path.read_bytes()
        original_open, original_replace, original_fsync, original_fdopen = os.open, os.replace, os.fsync, os.fdopen
        journal = workspace.journal
        for fault in ('temp', 'write', 'sync', 'rename'):
            prepared = [False]
            def record(transaction, value):
                journal(transaction, value)
                if value['state'] == 'prepared': prepared[0] = True
            def open_file(name, *args, **kwargs):
                if fault == 'temp' and str(name).startswith('.studio-write-'): raise OSError('injected temp create failure')
                return original_open(name, *args, **kwargs)
            def replace(src, dst, **kwargs):
                if fault == 'rename' and dst == 'main.odin': raise OSError('injected source rename failure')
                return original_replace(src, dst, **kwargs)
            def sync(fd):
                if fault == 'sync' and prepared[0]: raise OSError('injected source fsync failure')
                return original_fsync(fd)
            class FailedWriter:
                def __init__(self, stream): self.stream = stream
                def __enter__(self): self.stream.__enter__(); return self
                def __exit__(self, *args): return self.stream.__exit__(*args)
                def fileno(self): return self.stream.fileno()
                def write(self, data): raise OSError('injected source write failure')
            def fdopen(*args, **kwargs):
                stream = original_fdopen(*args, **kwargs)
                return FailedWriter(stream) if fault == 'write' and prepared[0] else stream
            with self.subTest(fault=fault), patch.object(workspace, 'journal', side_effect=record), patch.object(os, 'open', side_effect=open_file), patch.object(os, 'replace', side_effect=replace), patch.object(os, 'fsync', side_effect=sync), patch.object(os, 'fdopen', side_effect=fdopen):
                self.assertEqual(self.request()[0], 500)
            self.assertEqual(self.path.read_bytes(), original_bytes)

    def test_parent_sync_failure_after_rename_reports_uncertainty(self):
        original_replace, original_sync = os.replace, os.fsync
        renamed = [False]
        def replace(src, dst, **kwargs):
            result = original_replace(src, dst, **kwargs)
            if dst == 'main.odin': renamed[0] = True
            return result
        def sync(fd):
            if renamed[0]: raise OSError('injected post-rename directory sync failure')
            return original_sync(fd)
        with patch.object(os, 'replace', side_effect=replace), patch.object(os, 'fsync', side_effect=sync):
            status, result = self.request()
        self.assertEqual((status, result['commit_state']), (200, 'committed_durability_uncertain'))
        self.assertEqual(self.path.read_bytes(), b'package main\n')

    def test_parent_swap_is_detected_and_external_writer_is_preserved(self):
        w = self.client.bridge.workspace; original = w.parent_unchanged
        def race(path, fd, internal=False):
            if internal: return original(path, fd, internal=True)
            os.rename(self.root / 'src', self.root / 'old-src'); (self.root / 'src').mkdir()
            (self.root / 'src/main.odin').write_text('external replacement')
            return original(path, fd)
        with patch.object(w, 'parent_unchanged', side_effect=race):
            self.assertEqual(self.request()[0], 409)
        self.assertEqual(self.path.read_text(), 'external replacement')
        self.assertIn(b'\r\n', (self.root / 'old-src/main.odin').read_bytes())

    def test_lost_http_response_is_resolved_by_disk_and_history_inspection(self):
        old = self.path.read_bytes()
        port = self.client.server.server_port
        connection = http.client.HTTPConnection('127.0.0.1', port, timeout=3)
        body = dict(command='write-source', path='src/main.odin', expected_sha256=hashlib.sha256(old).hexdigest(), text='package main\n// response was lost\n', request_id='lost_response')
        connection.request('POST', '/api/command', json.dumps(body), {'Content-Type': 'application/json', 'Origin': 'http://127.0.0.1:' + str(port), 'X-Editor-Token': self.client.bridge.token})
        connection.close()  # Deliberately do not read or retry the mutation response.
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline and self.path.read_bytes() == old: time.sleep(.01)
        inspection = self.client.api('read-file', path='src/main.odin')
        self.assertEqual(inspection['text'], body['text'])
        # Wait for finalization independently of replacement becoming visible.
        records = []
        while time.monotonic() < deadline:
            records = [json.loads(p.read_text()) for p in (self.root / '.studio/source-history').glob('*.json')]
            if records and records[0]['state'] == 'committed': break
            time.sleep(.01)
        self.assertEqual(records[0]['state'], 'committed')
        self.assertEqual(base64.b64decode(records[0]['before_base64']), old)

    def test_python_entrypoint_startup_and_configured_reservation(self):
        process = subprocess.Popen([sys.executable, '-B', str(ROOT / 'editor/server.py'), '--project-root', str(self.root), '--read-only', 'src'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            url = process.stdout.readline().strip()
            self.assertRegex(url, r'^http://127\.0\.0\.1:[0-9]+/#token=')
            from urllib.parse import urlsplit
            parsed = urlsplit(url)
            connection = http.client.HTTPConnection('127.0.0.1', parsed.port, timeout=3)
            connection.request('GET', '/')
            response = connection.getresponse(); self.assertEqual(response.status, 200); self.assertIn(b'Coding workspace', response.read()); connection.close()
            connection = http.client.HTTPConnection('127.0.0.1', parsed.port, timeout=3)
            connection.request('POST', '/api/command', json.dumps(dict(command='list-project')), {'Content-Type': 'application/json', 'X-Editor-Token': parsed.fragment.split('=', 1)[1], 'Origin': 'http://' + parsed.netloc})
            response = connection.getresponse(); self.assertEqual(response.status, 200); result = json.loads(response.read()); self.assertEqual(result['reservations'], ['src']); connection.close()
        finally:
            process.terminate(); output, error = process.communicate(timeout=5)
        self.assertEqual(process.returncode, 0, error)

    def test_managed_writers_share_real_process_lock(self):
        directory = self.root / '.studio'; directory.mkdir(exist_ok=True)
        lock = open(directory / 'source.lock', 'w')
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertEqual(self.request()[0], 409)
        finally:
            lock.close()
        self.assertEqual(self.request()[0], 200)

    def test_missing_compiler_and_typed_job_arguments(self):
        self.client.bridge.workspace.compiler = None
        self.assertEqual(self.client.raw(dict(command='check-game'))[0], 503)
        for body in (dict(command='stop-job', job_id=[]), dict(command='job-status', job_id={}, cursor=0), dict(command='job-status', job_id='absent', cursor=-1)):
            self.assertEqual(self.client.raw(body)[0], 400)

    def test_process_kill_before_and_after_source_rename(self):
        original = self.path.read_bytes()
        for phase in ('before', 'after'):
            self.path.write_bytes(original)
            marker = self.root / (phase + '.ready')
            process = subprocess.Popen([sys.executable, '-B', str(ROOT / 'tests/editor_workspace/source_crash.py'), str(self.root), phase, str(marker)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                deadline = time.monotonic() + 10
                while not marker.exists() and time.monotonic() < deadline and process.poll() is None: time.sleep(.02)
                self.assertTrue(marker.exists(), process.poll())
            finally:
                process.kill(); process.communicate(timeout=3)
            self.assertEqual(self.path.read_bytes(), original if phase == 'before' else b'package main\n// complete new\n')
            histories = list((self.root / '.studio/source-history').glob('*.json'))
            self.assertTrue(histories)
            self.assertTrue(all(base64.b64decode(json.loads(p.read_text())['before_base64']) == original for p in histories))


@unittest.skipUnless(shutil.which('odin'), 'Real Odin compiler required')
class RealProjectTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='tls-e3-real-', dir='/tmp'); cls.root = Path(cls.temp.name).resolve(); project(cls.root)
        cls.client = Client(cls.root)

    @classmethod
    def tearDownClass(cls):
        cls.client.close(); cls.temp.cleanup()

    def test_dialogue_roundtrip_delivery_stage_order_stale_and_undo(self):
        before = self.client.inspect(); authored = copy.deepcopy(before['authored'])
        line = authored['order'][0]; authored['lines'][line]['text'] = 'E3 real dialogue edit — hello!'; authored['lines'][line]['delivery'] = 'offscreen'
        stage = next(key for key in authored['beat_order'] if authored['beats'][key]['kind'] == 'stage')
        authored['beats'][stage]['duration_ms'] = 123
        authored['beat_order'][0], authored['beat_order'][1] = authored['beat_order'][1], authored['beat_order'][0]
        authored['order'] = [authored['beats'][b]['line'] for b in authored['beat_order'] if authored['beats'][b]['kind'] == 'line']
        saved = self.client.restore(before, authored); self.assertEqual(saved['exit_code'], 0)
        after = self.client.inspect(); self.assertEqual(after['authored'], authored)
        self.assertEqual(self.client.restore(before, before['authored'])['exit_code'], 3)
        self.assertEqual(self.client.restore(after, before['authored'])['exit_code'], 0)
        self.assertEqual(self.client.inspect()['authored'], before['authored'])

    def test_authoritative_dialogue_rejections_leave_good_bytes(self):
        before = self.client.inspect(); base = before['authored']; path = self.root / before['document_path']; good = path.read_bytes()
        line = base['order'][0]; stage = next(b for b in base['beat_order'] if base['beats'][b]['kind'] == 'stage')
        beat = base['beat_order'][0]
        changes = [lambda d: d['lines'][line].update(speaker='missing_speaker'),
                   lambda d: d['lines'][line].update(text='é' * 2049),
                   lambda d: d['lines'][line].update(delivery='telepathic'),
                   lambda d: d['beat_order'].append(d['beat_order'][0]),
                   lambda d: d['beat_order'].append('missing_beat'),
                   lambda d: d.update(order=list(reversed(d['order']))),
                   lambda d: d['completion'].update(action='finish_oliver_journey'),
                   lambda d: d['beats'][stage].update(duration_ms=5001),
                   lambda d: d['beats'][beat]['stage'].update(cue='shell'),
                   lambda d: d['beats'][beat]['stage']['actors']['milo'].update(asset='missing_asset'),
                   lambda d: d['beats'][beat].update(command='whoami')]
        for change in changes:
            candidate = copy.deepcopy(base); change(candidate)
            response = self.client.restore(before, candidate)
            self.assertEqual(response['exit_code'], 2, response); self.assertEqual(path.read_bytes(), good)
        chapter = self.client.inspect('oliver_flower_market'); candidate = copy.deepcopy(chapter['authored']); candidate['strings']['skip_scene'] = 'eleven chars'
        self.assertEqual(self.client.restore(chapter, candidate)['exit_code'], 2)

    def test_invalid_external_graph_and_unrelated_revision_change(self):
        before = self.client.inspect()
        path = self.root / before['document_path']; good = path.read_bytes()
        try:
            path.write_text('{"invalid_external_document":true}')
            self.assertEqual(self.client.raw(dict(command='inspect-document', document='intro'))[0], 409)
            self.assertTrue(self.client.api('read-file', path='src/main.odin')['text'])
        finally: path.write_bytes(good)
        chapter = self.client.inspect('oliver_flower_market'); candidate = copy.deepcopy(chapter['authored']); candidate['strings']['snail'] = 'A harmless unrelated graph edit.'
        self.assertEqual(self.client.restore(chapter, candidate)['exit_code'], 0)
        self.assertEqual(self.client.restore(before, before['authored'])['exit_code'], 3)
        after = self.client.inspect('oliver_flower_market')
        self.assertEqual(self.client.restore(after, chapter['authored'])['exit_code'], 0)

    def test_manifest_hash_confined_asset_and_provenance(self):
        response = self.client.api('read-asset', asset_id='milo_idle_r')
        self.assertEqual(response['mime_type'], 'image/png')
        self.assertEqual(hashlib.sha256(base64.b64decode(response['base64'])).hexdigest(), response['asset']['sha256'])
        self.assertIn('creator', response['asset']['provenance'])
        self.assertIn('license', self.client.api('read-file', path='assets/ASSET_LICENSES.md')['text'].lower())
        self.assertEqual(self.client.raw(dict(command='read-asset', asset_id='../src/main.odin'))[0], 400)
        path = self.root / response['asset']['path']; good = path.read_bytes()
        try:
            path.write_bytes(good + b'changed'); self.assertNotEqual(self.client.raw(dict(command='read-asset', asset_id='milo_idle_r'))[0], 200)
        finally: path.write_bytes(good)

    def test_fixed_commands_and_verified_content_artifact(self):
        check = self.client.job('check-game'); self.assertEqual(check['exit_code'], 0)
        self.assertEqual(check['argv'][1:], ['check', 'src'])
        cli = self.client.job('build-content'); self.assertEqual(cli['exit_code'], 0)
        validated = self.client.api('validate-content'); self.assertEqual(validated['exit_code'], 0)
        self.assertEqual(validated['executable'], cli['artifact'])
        path = self.root / 'tools/content/main.odin'; original = path.read_bytes()
        try:
            path.write_bytes(original + b'\n// stale CLI input\n')
            self.assertEqual(self.client.raw(dict(command='validate-content'))[0], 409)
        finally: path.write_bytes(original)
        release = self.client.job('build-release'); self.assertEqual(release['exit_code'], 0)
        self.assertTrue(Path(release['artifact']).is_file())
        self.assertNotIn('-define:DEV_TOOLS=true', release['argv'])

    def test_real_compiler_errors_saved_bytes_fix_build_and_stale_guard(self):
        path = 'src/e3_diagnostic.odin'; target = self.root / path; target.write_text('package main\ne3_bad :: proc() { missing_e3_identifier() }\n')
        try:
            file = self.client.api('read-file', path=path)
            job = self.client.job('check-dev')
            self.assertNotEqual(job['exit_code'], 0); self.assertIn('missing_e3_identifier', job['complete_log'])
            self.assertTrue(any(d['path'] == path and d['line'] == 2 for d in job['diagnostics']), job)
            self.client.api('write-source', path=path, expected_sha256=file['sha256'], text='package main\ne3_good :: proc() {}\n', request_id='agent_fix')
            self.assertIn('+e3_good', self.client.api('diff-head', path=path)['diff'])
            self.assertTrue(self.client.api('diff-head', path=path)['added'])
            checked = self.client.job('check-dev'); self.assertEqual(checked['exit_code'], 0)
            built = self.client.job('build-dev'); self.assertEqual(built['exit_code'], 0); self.assertTrue(built['current_source']); self.assertTrue(Path(built['artifact']).is_file())
            artifact = Path(built['artifact']); original = artifact.read_bytes()
            artifact.write_bytes(original + b'tampered')
            self.assertEqual(self.client.raw(dict(command='run-scene'))[0], 409)
            artifact.write_bytes(original)
            target.write_text('package main\n// changed after successful build\n')
            self.assertEqual(self.client.raw(dict(command='run-scene'))[0], 409)
            target.write_text('package main\ne3_bad :: proc() { missing_again() }\n')
            failed = self.client.job('build-dev'); self.assertNotEqual(failed['exit_code'], 0)
            self.assertEqual(self.client.raw(dict(command='run-scene'))[0], 409)
        finally: target.unlink(missing_ok=True)

    def test_literal_search_diff_staged_bytes_and_task_truth(self):
        result = self.client.api('search-project', text='package main', limit=3)
        self.assertEqual(len(result['matches']), 3)
        file = self.client.api('read-file', path='src/main.odin'); good = file['text']
        try:
            self.client.api('write-source', path='src/main.odin', expected_sha256=file['sha256'], text=good + '\n// E3 staged\n', request_id='agent_diff')
            subprocess.run(['git', 'add', 'src/main.odin'], cwd=self.root, check=True)
            self.assertIn('+// E3 staged', self.client.api('diff-head', path='src/main.odin')['diff'])
            status = self.client.api('task-status')
            self.assertIn('unresolved', status['ownership_resolution'])
            self.assertFalse(status['provider_observation']['available'])
            self.assertTrue(all(task['provider_state'] == 'unknown/unavailable' for task in status['tasks']))
            self.assertTrue(status['managed_source_transactions'])
            self.assertEqual(self.client.raw(dict(command='run-journey'))[0], 409)
        finally:
            (self.root / 'src/main.odin').write_text(good)
            subprocess.run(['git', 'add', 'src/main.odin'], cwd=self.root, check=True)

    def test_job_cursor_cancel_and_changes_during_real_build(self):
        started = self.client.api('build-dev')
        # Change an included saved source immediately after the pre-build fingerprint.
        path = self.root / 'src/e3_during.odin'; path.write_text('package main\n')
        deadline = time.monotonic() + 60; cursor = 0; chunks = []
        try:
            while time.monotonic() < deadline:
                status = self.client.api('job-status', job_id=started['job_id'], cursor=cursor)
                self.assertGreaterEqual(status['cursor'], cursor); cursor = status['cursor']; chunks.append(status['log'])
                if status['state'] not in ('starting', 'running'): break
                time.sleep(.02)
            self.assertFalse(status['current_source']); self.assertEqual(self.client.raw(dict(command='run-scene'))[0], 409)
            active = self.client.api('build-release'); stopped = self.client.api('stop-job', job_id=active['job_id'])
            self.assertIn(stopped['state'], ('running', 'stopped', 'exited', 'starting'))
            # Actual process termination is joined before close; never a mocked successful build.
            self.assertNotEqual(self.client.api('job-status', job_id=active['job_id'], cursor=0).get('exit_code'), 0)
        finally: path.unlink(missing_ok=True)

if __name__ == '__main__': unittest.main()
