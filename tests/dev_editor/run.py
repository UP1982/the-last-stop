#!/usr/bin/env python3
"""E2 gates: disposable projects, temporary HOME, real native dispatcher and CLI.
No web/E3 files are changed. Native rendered evidence is a separate native.py.
"""
import hashlib, json, os, shutil, subprocess, tempfile, time, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/evidence/e2'; OUT.mkdir(parents=True,exist_ok=True)
BIN=ROOT/'build/e2-selftest'; CLI=ROOT/'build/e2-content-test'; RELEASE=ROOT/'build/e2-release'; DEV=ROOT/'build/e2-dev'
ROWS=[]
def run(args,**kw):
    p=subprocess.run(list(map(str,args)),cwd=ROOT,capture_output=True,timeout=90,**kw)
    ROWS.append(dict(argv=list(map(str,args)),exit=p.returncode,stderr=p.stderr.decode(errors='replace')[-6000:]))
    (OUT/'automated-results.json').write_text(json.dumps(ROWS,indent=2)+'\n')
    return p

def build():
    for args in (
        ['odin','build','src','-define:DEV_TOOLS=true','-define:DEV_EDITOR_SELF_TEST=true','-out:'+str(BIN)],
        ['odin','build','tools/content','-define:E0_TEST_HOOKS=true','-out:'+str(CLI)],
        ['odin','build','src','-out:'+str(RELEASE)],
        ['odin','build','src','-define:DEV_TOOLS=true','-out:'+str(DEV)],
    ):
        p=run(args); assert p.returncode==0,p.stderr.decode()

def hashes(root):
    return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'data').rglob('*') if p.is_file() and not p.name.startswith('.tls-content-')}

class E2(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='tls-e2-',dir='/tmp'); self.root=Path(self.tmp.name)/'project';self.root.mkdir()
        for name in ('data','assets'):shutil.copytree(ROOT/name,self.root/name)
        (self.root/'build').mkdir();shutil.copyfile(CLI,self.root/'build/tls-content');(self.root/'build/tls-content').chmod(0o700)
        self.home=Path(self.tmp.name)/'home';self.home.mkdir()
        self.sentinel=self.home/'Library/Application Support/The Last Stop/saves/chapter_01.json';self.sentinel.parent.mkdir(parents=True);self.sentinel.write_bytes(b'NORMAL_SAVE_SENTINEL_E2\n')
        self.override=Path(self.tmp.name)/'override';self.override.mkdir();(self.override/'sentinel').write_text('override untouched')
        self.env=dict(os.environ,HOME=str(self.home),TLS_SAVE_DIR=str(self.override))
        self.before=hashes(self.root)
    def tearDown(self):
        self.assertEqual(self.sentinel.read_bytes(),b'NORMAL_SAVE_SENTINEL_E2\n')
        self.assertEqual(sorted(p.name for p in self.override.iterdir()),['sentinel'])
        self.tmp.cleanup()
    def invoke(self,scenario,env=None,preview=True):
        args=[BIN,scenario,'--project-root',self.root]
        if preview:args+=['--preview-scene','oliver_obstacle','--preview-session','e2-'+scenario,'--save-dir',self.override]
        else:args+=['--save-dir',Path(self.tmp.name)/'normal-test']
        if scenario=='chapter':args+=['--preview-entry','chapter']
        p=run(args,env=env or self.env)
        self.assertEqual(p.returncode,0,p.stderr.decode(errors='replace'))
        self.assertIn(b'PASS E2',p.stdout)
        return p
    def test_01_options_and_normal_profile(self):
        self.invoke('flags');self.invoke('normal',preview=False)
        self.assertEqual(hashes(self.root),self.before)
    def test_02_pause_step_input_hit_testing_reset(self):
        self.invoke('state');self.assertEqual(hashes(self.root),self.before)
    def test_03_chapter_entry_frozen_timers(self):
        self.invoke('chapter');self.assertEqual(hashes(self.root),self.before)
        profile=self.home/'Library/Caches/The Last Stop/preview/e2-chapter/chapter_01.json'
        self.assertEqual(json.loads(profile.read_text())['checkpoint'],'chapter_start')
    def test_04_draft_validation_no_write(self):
        self.invoke('draft');self.assertEqual(hashes(self.root),self.before);self.assertFalse((self.root/'.studio').exists())
    def test_05_real_apply_restore_undo(self):
        self.invoke('apply')
        self.assertEqual(json.loads((self.root/'data/scenes/oliver_obstacle.json').read_text()),json.loads((ROOT/'data/scenes/oliver_obstacle.json').read_text()))
        history=self.root/'.studio/history';self.assertEqual(len(list(history.iterdir())),2)
        records=[json.loads(p.read_text()) for p in history.glob('*/committed.json')]
        self.assertTrue(all(r['document']=='oliver_obstacle' for r in records))
    def test_06_stale_apply_retains_draft(self):
        self.invoke('stale');self.assertEqual((self.root/'data/scenes/oliver_obstacle.json').read_bytes(),(ROOT/'data/scenes/oliver_obstacle.json').read_bytes())
    def test_07_stale_undo(self):self.invoke('stale-undo')
    def test_08_cli_failure_recovery(self):
        # Each failed transaction is a real fault-enabled content executable.
        for fault in ('history','temp','short_write','sync','close','rename'):
            with self.subTest(fault=fault):
                self.invoke('fault',dict(self.env,TLS_E0_FAULT=fault));self.assertEqual(hashes(self.root),self.before)
    def test_09_post_commit_uncertainty(self):
        self.invoke('fault',dict(self.env,TLS_E0_FAULT='directory_sync'))
        changed={k for k,v in hashes(self.root).items() if self.before[k]!=v}
        self.assertEqual(changed,{'data/scenes/oliver_obstacle.json'})
    def test_10_lost_response(self):self.invoke('lost')
    def test_11_missing_and_symlink_cli(self):
        executable=self.root/'build/tls-content';executable.unlink();self.invoke('missing-cli')
        executable.symlink_to(CLI);self.invoke('missing-cli');self.assertEqual(hashes(self.root),self.before)
    def test_12_symlink_preview_directory(self):
        parent=self.home/'Library/Caches/The Last Stop/preview';parent.mkdir(parents=True)
        (parent/'e2-path-block').symlink_to(self.override,target_is_directory=True)
        self.invoke('path-block');self.assertEqual(hashes(self.root),self.before)
    def test_13a_full_preview_isolation(self):
        self.invoke('isolation');self.assertEqual(hashes(self.root),self.before);self.assertFalse((self.root/'.studio').exists())
    def test_13b_geometry_properties(self):
        path=self.root/'data/scenes/oliver_obstacle.json';d=json.loads(path.read_text());d['objects']['fallen_branch']['collision']=[0,0,96,8];path.write_text(json.dumps(d))
        before=hashes(self.root);self.invoke('geometry');self.assertEqual(hashes(self.root),before)
    def test_13c_unavailable_preview_parent(self):
        parent=self.home/'Library/Caches/The Last Stop';parent.mkdir(parents=True);(parent/'preview').write_text('not a directory')
        self.invoke('path-block');self.assertEqual(hashes(self.root),self.before)
    def test_13d_busy(self):
        import fcntl
        (self.root/'.studio').mkdir();lock=(self.root/'.studio/content.lock').open('w')
        try:
            fcntl.lockf(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);self.invoke('busy');self.assertEqual(hashes(self.root),self.before)
        finally:lock.close()
    def test_13e_invalid_external_disk(self):self.invoke('invalid-disk')
    def test_13ea_unknown_version_and_missing_asset_keep_native_draft(self):
        scene=self.root/'data/scenes/oliver_obstacle.json';good=scene.read_bytes()
        for invalid in ('version','asset','file'):
            scene.write_bytes(good)
            self.invoke('invalid-disk',dict(self.env,TLS_E4_INVALID=invalid))
    def test_13f_crash_both_sides_of_rename(self):
        scene=self.root/'data/scenes/oliver_obstacle.json';original=scene.read_bytes()
        for scenario,point in [('crash-before','before_rename'),('crash-after','after_rename')]:
            scene.write_bytes(original);marker=Path(self.tmp.name)/(scenario+'.marker')
            self.invoke(scenario,dict(self.env,TLS_E0_PAUSE=point,TLS_E0_MARKER=str(marker)))
            self.assertEqual(json.loads(scene.read_text())['objects']['crank_handle']['position'],[1176,256] if scenario=='crash-before' else [1192,256])
    def test_13ga_allocation_lifecycle(self):self.invoke('allocation');self.assertEqual(hashes(self.root),self.before)
    def test_13g_timeout_unknown(self):
        self.invoke('timeout',dict(self.env,TLS_E0_PAUSE='before_rename',TLS_E0_MARKER=str(Path(self.tmp.name)/'timeout')))
        self.assertEqual(hashes(self.root),self.before)
    def test_13_release_exclusion(self):
        data=RELEASE.read_bytes()
        for marker in (b'apply-to-content',b'restore_document',b'tls-native-edit-',b'DEV_EDITOR_TEST_HOOKS',b'TLS_E2_CONTROL',b'--preview-entry',b'Edit mode: geometry'):
            self.assertFalse(marker in data,repr(marker)+" present in release")
        self.assertTrue(b'apply-to-content' in DEV.read_bytes())
        # Existing headless content probe exercises release launch parsing.
        probe=ROOT/'build/e2-release-probe';p=run(['odin','build','src','-define:E0B_SELF_TEST=true','-out:'+str(probe)]);self.assertEqual(p.returncode,0)
        for flags in (['--preview-entry','chapter'],['--preview-scene','oliver_obstacle','--preview-session','test']):
            p=run([probe,'load','--project-root',self.root]+flags,env=self.env)
            self.assertNotEqual(p.returncode,0);self.assertIn(b'unsupported option',p.stderr)
        self.assertEqual(hashes(self.root),self.before)

if __name__=='__main__':
    build();unittest.main(verbosity=2)
