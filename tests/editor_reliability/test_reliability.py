"""E4 cross-surface failures and durable recovery; real HTTP/CLI/compiler/syscalls."""
import copy, errno, hashlib, json, os, shutil, subprocess, sys, tempfile, time, unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'editor_workspace'))
from common import ROOT, Client, project, server_module
OUT = ROOT / 'build/evidence/e4'
OUT.mkdir(parents=True, exist_ok=True)

def run(args, **kwargs):
    result = subprocess.run(list(map(str, args)), capture_output=True, timeout=120, **kwargs)
    assert result.returncode == 0, (args, result.returncode, result.stderr.decode(errors='replace')[-5000:])
    return result

class Drafts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='tls-e4-drafts-', dir='/tmp')
        self.root = Path(self.temp.name).resolve(); (self.root / 'src').mkdir()
        (self.root / 'src/main.odin').write_text('package main\n')
        self.client = Client(self.root)
    def tearDown(self): self.client.close(); self.temp.cleanup()
    def read(self, kind='scene', id='oliver_obstacle'): return self.client.api('read-draft', kind=kind, id=id)
    def write(self, value, expected=None, kind='scene', id='oliver_obstacle'):
        return self.client.api('write-draft', kind=kind, id=id, value=value, expected_sha256=expected)
    def test_port_restart_all_draft_types_keep_revision_history_and_conflict(self):
        cases = [('scene','oliver_obstacle'), ('dialogue','intro'), ('source','src/main.odin')]
        value = dict(base={'schema_version':2}, draft={'schema_version':2,'text':'unsaved'}, revision='original', past=[{'text':'undo'}], future=[])
        for kind, id in cases: self.write(value, kind=kind, id=id)
        port = self.client.server.server_port; key = self.client.bridge.project_key
        self.client.close(); self.client = Client(self.root)
        self.assertNotEqual(port, self.client.server.server_port); self.assertEqual(key, self.client.bridge.project_key)
        for kind, id in cases:
            recovered = self.read(kind, id); self.assertEqual(recovered['value'], value)
            self.assertEqual(self.client.raw(dict(command='write-draft', kind=kind, id=id, value={}, expected_sha256=None))[0], 409)
        self.assertEqual((self.root / 'src/main.odin').read_text(), 'package main\n')
        for p in (self.root / '.studio/drafts').rglob('*.json'): self.assertEqual(p.stat().st_mode & 0o777, 0o600)
    def test_keys_boundaries_corrupt_records_and_unavailable_storage(self):
        for kind, id in [('shell','a'),('source','../x'),('scene','../x'),('source','.studio/x'),('scene',[]),([], 'x')]:
            self.assertNotEqual(self.client.raw(dict(command='read-draft', kind=kind, id=id))[0], 200)
        self.write({'revision':'old'})
        path = next((self.root / '.studio/drafts').rglob('*.json')); path.write_text('{broken')
        self.assertEqual(self.client.raw(dict(command='read-draft',kind='scene',id='oliver_obstacle'))[0],409)
        self.assertEqual(path.read_text(), '{broken')
        path.unlink(); path.symlink_to(self.root / 'src/main.odin')
        self.assertNotEqual(self.client.raw(dict(command='read-draft',kind='scene',id='oliver_obstacle'))[0],200)
        self.assertEqual((self.root / 'src/main.odin').read_text(),'package main\n')
    def test_full_intro_undo_history_and_max_source_buffers_recover(self):
        doc = json.loads((ROOT/'data/dialogue/oliver_intro.json').read_text())
        history = dict(base=doc, draft=doc, revision='original', past=[doc] * 100, future=[])
        saved = self.write(history, kind='dialogue', id='intro')
        self.assertEqual(len(saved['value']['past']), 100)
        source = dict(path='src/main.odin', base='a' * 200000, text='b' * 200000, hash='a' * 64)
        self.write(source, kind='source', id='src/main.odin')
        self.client.close(); self.client = Client(self.root)
        self.assertEqual(self.read('dialogue','intro')['value'], history)
        self.assertEqual(self.read('source','src/main.odin')['value'], source)
        self.assertEqual((self.root/'src/main.odin').read_text(),'package main\n')
        port = self.client.server.server_port
        connection = __import__('http.client',fromlist=['HTTPConnection']).HTTPConnection('127.0.0.1',port)
        connection.request('POST','/api/draft',json.dumps(dict(command='check-game')),{'Content-Type':'application/json','Origin':'http://127.0.0.1:'+str(port),'X-Editor-Token':self.client.bridge.token})
        response = connection.getresponse(); self.assertEqual(response.status,400); response.read(); connection.close()
    def test_atomic_failed_replace_preserves_draft_and_kill_both_sides(self):
        before = self.write({'draft':'old','revision':'original'})
        with patch.object(os, 'replace', side_effect=OSError('injected rename failure')):
            self.assertEqual(self.client.raw(dict(command='write-draft',kind='scene',id='oliver_obstacle',value={'draft':'failed'},expected_sha256=before['sha256']))[0],500)
        self.assertEqual(self.read(), before)
        rows = []
        for phase in ('before','after'):
            current=self.read(); self.write({'draft':'old','revision':'original'},current['sha256'])
            marker=self.root/(phase+'.ready')
            process=subprocess.Popen([sys.executable,'-B',str(ROOT/'tests/editor_reliability/draft_crash.py'),str(self.root),phase,str(marker)],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
            try:
                deadline=time.monotonic()+10
                while not marker.exists() and process.poll() is None and time.monotonic()<deadline:time.sleep(.01)
                self.assertTrue(marker.exists(), process.poll())
            finally: process.kill(); out,err=process.communicate(timeout=5)
            self.assertEqual(process.returncode,-9)
            self.assertEqual(self.read()['value']['draft'],'old' if phase=='before' else 'complete new')
            rows.append(dict(phase=phase,exit=process.returncode,recovered=self.read()))
        (OUT/'draft-crashes.json').write_text(json.dumps(rows,indent=2)+'\n')

class Integrated(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp=tempfile.TemporaryDirectory(prefix='tls-e4-integration-',dir='/tmp');cls.root=Path(cls.temp.name).resolve();project(cls.root)
        cls.home=cls.root/'home';cls.home.mkdir();cls.env=dict(os.environ,HOME=str(cls.home))
        cls.client=Client(cls.root)
        cls.fault=cls.root/'build/fault-content';cls.probe=cls.root/'build/probe';cls.lockprobe=cls.root/'build/lockprobe';cls.interposer=cls.root/'build/lock-error.dylib'
        for args in (['odin','build','tools/content','-define:E0_TEST_HOOKS=true','-out:'+str(cls.fault)], ['odin','build','src','-define:E0B_SELF_TEST=true','-out:'+str(cls.probe)], ['odin','build','src','-define:M4_SELF_TEST=true','-define:DEV_TOOLS=true','-define:M4_TEST_HOOKS=true','-define:M2_TEST_HOOKS=true','-out:'+str(cls.lockprobe)], ['cc','-dynamiclib',str(ROOT/'tests/editor_reliability/lock_error.c'),'-o',str(cls.interposer)]):run(args,cwd=cls.root,env=cls.env)
    @classmethod
    def tearDownClass(cls):cls.client.close();cls.temp.cleanup()
    def test_lock_errno_classification_and_fail_closed(self):
        rows=[]
        for code in (errno.EACCES,errno.EAGAIN,errno.ENOLCK,errno.EINVAL,errno.ENOSYS):
            profile=self.root/('lock-'+str(code));profile.mkdir();sentinel=profile/'chapter_01.json';sentinel.write_bytes(b'EXISTING_SAVE_SENTINEL')
            env=dict(self.env,DYLD_INSERT_LIBRARIES=str(self.interposer),TLS_E4_LOCK_ERRNO=str(code))
            command='busy' if code in (errno.EACCES,errno.EAGAIN) else 'lock-unavailable'
            p=run([self.lockprobe,command,'--project-root',self.root,'--save-dir',Path('/tmp')/profile.relative_to('/private/tmp')],env=env,cwd='/tmp')
            self.assertEqual(sentinel.read_bytes(),b'EXISTING_SAVE_SENTINEL')
            rows.append(dict(errno=code,command=command,exit=p.returncode,stderr=p.stderr.decode(errors='replace')))
        (OUT/'lock-errno.json').write_text(json.dumps(rows,indent=2)+'\n')
    def request(self,before,ops):return dict(protocol_version=1,request_id='e4_reliability',chapter='oliver_flower_market',document=before['document'],expected_revision=before['graph_revision'],operations=ops)
    def test_invalid_candidates_and_external_content_web_cli_runtime(self):
        before=self.client.api('inspect-scene')['result'];path=self.root/before['document_path'];good=path.read_bytes();rows=[]
        for label,change in [('unknown-version',lambda d:d.update(schema_version=999)),('missing-asset',lambda d:d['objects']['crank_handle'].update(asset='missing_e4'))]:
            doc=copy.deepcopy(before['authored']);change(doc)
            response=self.client.restore(before,doc);self.assertEqual(response['exit_code'],2);self.assertEqual(path.read_bytes(),good)
            path.write_text(json.dumps(doc));bad=path.read_bytes()
            try:
                response=self.client.api('validate-content');self.assertEqual(response['exit_code'],2)
                p=subprocess.run([str(self.root/'build/tls-content'),'validate-content','--project-root',str(self.root)],env=self.env,capture_output=True);self.assertEqual(p.returncode,2)
                native=run([self.probe,'invalid','--project-root',self.root],env=self.env)
                self.assertEqual(path.read_bytes(),bad)
                rows.append(dict(case=label,web=response['exit_code'],cli=p.returncode,runtime=native.returncode))
            finally:path.write_bytes(good)
        path.write_text('{broken')
        try:
            self.assertEqual(self.client.api('validate-content')['exit_code'],2)
            run([self.probe,'invalid','--project-root',self.root],env=self.env)
            self.assertEqual(path.read_text(),'{broken')
        finally:path.write_bytes(good)
        asset = self.root / 'assets/backgrounds/forest_track.png'
        asset_bytes = asset.read_bytes(); asset.unlink()
        try:
            self.assertEqual(self.client.api('validate-content')['exit_code'], 2)
            p = subprocess.run([str(self.root/'build/tls-content'),'validate-content','--project-root',str(self.root)],env=self.env,capture_output=True)
            self.assertEqual(p.returncode, 2)
            native = run([self.probe,'invalid','--project-root',self.root],env=self.env)
            rows.append(dict(case='missing-asset-file',web=2,cli=p.returncode,runtime=native.returncode))
        finally: asset.write_bytes(asset_bytes)
        (OUT/'cross-surface-invalid.json').write_text(json.dumps(rows,indent=2)+'\n')
    def test_web_content_writer_sigkill_around_actual_cli_rename(self):
        # HTTP handler waits for the real CLI. Kill that CLI at its compiled transaction rendezvous.
        import threading
        path=self.root/'data/scenes/oliver_obstacle.json';good=path.read_bytes();rows=[]
        shutil.copy2(self.fault,self.root/'build/tls-content')
        try:
            for point in ('before_rename','after_rename'):
                path.write_bytes(good);before=self.client.api('inspect-scene')['result'];doc=copy.deepcopy(before['authored']);doc['objects']['crank_handle']['position']=[1192,256]
                marker=self.root/(point+'.ready');result=[]
                with patch.dict(os.environ,TLS_E0_PAUSE=point,TLS_E0_MARKER=str(marker)):
                    thread=threading.Thread(target=lambda:result.append(self.client.raw(dict(command='apply-edit',request=self.request(before,[dict(op='restore_document',value=doc)])))))
                    thread.start();deadline=time.monotonic()+10
                    while not marker.exists() and time.monotonic()<deadline:time.sleep(.01)
                    self.assertTrue(marker.exists())
                    # Match both executable and exact project root, never other agent processes.
                    listing=subprocess.check_output(['ps','-axo','pid=,command='],text=True)
                    pids=[int(line.strip().split(None,1)[0]) for line in listing.splitlines() if str(self.root/'build/tls-content')+' apply-edit ' in line and '--project-root '+str(self.root)+' ' in line]
                    self.assertEqual(len(pids),1,pids);os.kill(pids[0],9);thread.join(timeout=25);self.assertFalse(thread.is_alive())
                self.assertEqual(result[0][0],502)
                self.assertEqual(json.loads(path.read_bytes())['objects']['crank_handle']['position'],[1176,256] if point=='before_rename' else [1192,256])
                self.assertTrue(list((self.root/'.studio/history').glob('*/before.json')))
                rows.append(dict(point=point,killed_cli=pids[0],http=result[0],coherent_disk=True))
        finally:path.write_bytes(good)
        (OUT/'web-content-crashes.json').write_text(json.dumps(rows,indent=2)+'\n')
    def test_run_journey_fixed_mapping_and_fresh_artifact_guard(self):
        # Popen is inspected here; E4 native demonstration exercises the actual executable.
        self.assertEqual(self.client.raw(dict(command='run-journey',entry='scene'))[0],400)
        build=self.client.job('build-dev');self.assertEqual(build['exit_code'],0)
        from unittest.mock import Mock
        process=Mock(pid=101);process.poll.return_value=None
        actual_popen = subprocess.Popen
        def preview_only(argv, **kwargs):
            if argv[0] == build['artifact']: return process
            return actual_popen(argv, **kwargs)
        with patch.object(server_module.subprocess,'Popen',side_effect=preview_only) as popen:
            result=self.client.api('run-journey');argv=popen.call_args.args[0]
            self.assertEqual(argv[-3:],['--preview-entry','chapter','--dump-scene']);self.assertEqual(result['entry'],'chapter')
            self.assertRegex(result['session'],'^editor_[a-f0-9]{24}$');self.client.api('stop-preview')
        process.poll.return_value=0
        path=self.root/'src/main.odin';original=path.read_bytes()
        try:
            path.write_bytes(original+b'\n// stale E4\n');self.assertEqual(self.client.raw(dict(command='run-journey'))[0],409)
        finally:path.write_bytes(original)
        binary=Path(build['artifact']);binary.write_bytes(binary.read_bytes()+b'tamper');self.assertEqual(self.client.raw(dict(command='run-journey'))[0],409)

if __name__=='__main__':unittest.main(verbosity=2)
