#!/usr/bin/env python3
"""E0a behavioral gates. Uses only stdlib and real compiled Odin executables.
Run: python3 tests/editor/run.py (builds a fault-enabled CLI separately).
All mutations occur in disposable build/e0-tests-* project copies.
"""
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
CLI = ROOT / 'build/tls-content'
FAULT_CLI = ROOT / 'build/tls-content-test'
CHAPTER = 'data/chapters/chapter_01.json'
SCENE = 'data/scenes/oliver_obstacle.json'
INTRO = 'data/dialogue/oliver_intro.json'
ARRIVAL = 'data/dialogue/oliver_arrival.json'
ASSETS = 'data/assets/manifest.json'
PATHS = [CHAPTER, SCENE, INTRO, ARRIVAL, ASSETS]


def encode(value):
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + '\n').encode()


def invoke(root, command, request=None, env=None, binary=CLI):
    args = [str(binary), command, '--project-root', str(root)]
    if command == 'inspect-scene':
        args += ['--scene', 'oliver_obstacle']
    if request is not None:
        path = root / 'request.json'
        path.write_bytes(request if isinstance(request, bytes) else encode(request))
        args += ['--request', str(path)]
    p = subprocess.run(args, capture_output=True, env=env, timeout=20)
    try:
        body = json.loads(p.stdout)
    except Exception:
        raise AssertionError('CLI did not return JSON: code=%s stdout=%r stderr=%r' % (p.returncode, p.stdout, p.stderr))
    return p.returncode, body


class E0(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='e0-tests-', dir=str(ROOT / 'build'))
        self.root = Path(self.tmp.name)
        shutil.copytree(ROOT / 'data', self.root / 'data')
        (self.root / 'assets').mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def read(self, path):
        return json.loads((self.root / path).read_bytes())

    def write(self, path, value):
        (self.root / path).write_bytes(encode(value))

    def disk(self):
        return {str(p.relative_to(self.root)): p.read_bytes() for p in (self.root / 'data').rglob('*') if p.is_file() and not p.name.startswith('.tls-content-')}

    def revision(self):
        status, body = invoke(self.root, 'validate-content')
        self.assertEqual(status, 0, body)
        return body['graph_revision']

    def request(self, ops=None, document='oliver_obstacle', revision=None):
        return {'protocol_version': 1, 'request_id': 'test_edit', 'chapter': 'oliver_flower_market',
                'document': document, 'expected_revision': revision or self.revision(),
                'operations': ops or [{'op': 'set_property', 'collection': 'objects', 'id': 'crank_handle',
                                       'property': 'position', 'value': [596, 128]}]}

    def apply(self, request, expected=0, **kwargs):
        status, body = invoke(self.root, 'apply-edit', request, **kwargs)
        self.assertEqual(status, expected, body)
        return body

    def invalid_graph(self, path, mutate):
        old = (self.root / path).read_bytes()
        value = json.loads(old)
        mutate(value)
        self.write(path, value)
        before = self.disk()
        status, body = invoke(self.root, 'validate-content')
        self.assertEqual(status, 2, body)
        self.assertTrue(body['diagnostics'], body)
        self.assertEqual(self.disk(), before)
        (self.root / path).write_bytes(old)

    def test_01_strict_json(self):
        original = (self.root / CHAPTER).read_bytes()
        malformed = {
            'truncated': original[:-3], 'duplicate': b'{"kind":"chapter","kind":"chapter"}',
            'escaped_duplicate': b'{"kind":"chapter","\\u006bind":"chapter"}',
            'garbage': original + b'wat', 'second_root': original + b'{}',
            'object_trailing_comma': original.rstrip()[:-1] + b',}',
            'array_trailing_comma': b'{"x":[1,]}', 'comment': b'/*hi*/' + original,
            'utf8': original.replace(b'Oliver', b'\xff', 1), 'leading_zero': b'{"x":01}',
            'plus': b'{"x":+1}', 'exponent': b'{"x":1e+}', 'float_overflow': b'{"x":1e9999}',
            'integer_overflow': b'{"x":9223372036854775808}',
            'negative_overflow': b'{"x":-9223372036854775809}',
            'nan': b'{"x":NaN}', 'fraction': b'{"x":1.}',
            'deep': b'[' * 34 + b'0' + b']' * 34,
            'large': b' ' * 262145, 'nul': original + b'\x00garbage',
            'formfeed': original + b'\x0c', 'apostrophe_escape': b'{"x":"\\\'"}',
            'bad_hex_escape': b'{"x":"\\uZZZZ"}', 'high_surrogate': b'{"x":"\\ud800"}',
            'low_surrogate': b'{"x":"\\udc00"}', 'raw_newline': b'{"x":"\n"}',
            'missing_quote': b'{"x":"foo}', 'bom': b'\xef\xbb\xbf' + original,
        }
        for label, content in malformed.items():
            with self.subTest(label=label):
                (self.root / CHAPTER).write_bytes(content)
                before = self.disk()
                status, body = invoke(self.root, 'validate-content')
                self.assertEqual(status, 2, (label, body))
                self.assertEqual(self.disk(), before)
        (self.root / CHAPTER).write_bytes(original)
        for path, mutation in [
            (CHAPTER, lambda d: d.pop('title')),
            (CHAPTER, lambda d: d.update(unknown=True)),
            (CHAPTER, lambda d: d.update(schema_version=2)),
            (CHAPTER, lambda d: d.update(schema_version=1.0)),
            (SCENE, lambda d: d['objects']['crank_handle'].update(unknown=True)),
            (CHAPTER, lambda d: d.update({'': True})),
        ]:
            with self.subTest(path=path, mutation=mutation): self.invalid_graph(path, mutation)
        self.assertEqual(self.revision(), self.revision())

    def test_02_graph_validation(self):
        mutations = [
            (CHAPTER, lambda d: d['scenes'][0].update(path='data/scenes/missing.json')),
            (CHAPTER, lambda d: d['scenes'][0].update(id='wrong_id')),
            (CHAPTER, lambda d: d['scenes'][0].update(path='../escape.json')),
            (CHAPTER, lambda d: d['scenes'][0].update(path='/tmp/a.json')),
            (CHAPTER, lambda d: d['scenes'][0].update(path='data/scenes/../chapter.json')),
            (CHAPTER, lambda d: d['scenes'][0].update(path='data\\scenes\\a.json')),
            (CHAPTER, lambda d: d['scenes'].append(copy.deepcopy(d['scenes'][0]))),
            (CHAPTER, lambda d: d.update(passenger='nobody')),
            (CHAPTER, lambda d: d.update(reward='missing')),
            (CHAPTER, lambda d: d['keepsakes'].update(extra={'name': 'Extra reward'})),
            (INTRO, lambda d: d['lines']['intro_01'].update(speaker='missing')),
            (INTRO, lambda d: d['completion'].update(action='finish_oliver_journey')),
            (ARRIVAL, lambda d: d['completion'].update(destination='train_travel')),
            (INTRO, lambda d: d.update(order=['intro_01', 'intro_01'])),
            (INTRO, lambda d: d.update(order=['intro_01'])),
            (INTRO, lambda d: d.update(order=['intro_01', 'absent'])),
            (INTRO, lambda d: d['lines']['intro_01'].update(reward='paper_flower')),
            (SCENE, lambda d: d['objects']['crank_handle'].update(position=[17000, 0])),
            (SCENE, lambda d: d['objects']['crank_handle'].update(position=[-10, 128])),
            (SCENE, lambda d: d['objects']['crank_handle'].update(size=[0, 8])),
            (SCENE, lambda d: d['objects']['crank_handle'].update(position=[588.0, 128])),
            (SCENE, lambda d: d['objects']['crank_handle'].update(asset='missing')),
            (SCENE, lambda d: d['objects']['crank_handle'].update(interaction=[0, -100, 8, 8])),
            (SCENE, lambda d: d['objects']['shed'].update(collision=[0, 0, 72, 48])),
            (SCENE, lambda d: d['objects']['winch'].update(collision=[0, 0, 24, 24])),
            (SCENE, lambda d: d.update(camera_bounds=[0, 0, 319, 180])),
            (SCENE, lambda d: d.update(ground=[1, 144, 639, 36])),
            (SCENE, lambda d: d['spawns']['puzzle_entry'].update(position=[140, 143])),
            (SCENE, lambda d: d['puzzle'].update(handle='winch')),
            (SCENE, lambda d: d['puzzle'].update(player_spawn='handle_recovery')),
            (SCENE, lambda d: d['puzzle'].update(winch_socket=[100, 0])),
            (SCENE, lambda d: d['puzzle'].update(branch_cleared_position=[640, 0])),
            (SCENE, lambda d: d['objects'].update(extra_handle=copy.deepcopy(d['objects']['crank_handle']))),
        ]
        for path, mutation in mutations:
            with self.subTest(path=path, mutation=mutation): self.invalid_graph(path, mutation)
        # Wrong kind despite a correct scene ID/path.
        self.invalid_graph(SCENE, lambda d: d.update(kind='dialogue'))
        # Duplicate chapter-wide object/spawn identities across two distinct scenes.
        extra = self.read(SCENE); extra['id'] = 'second_scene'
        self.write('data/scenes/second.json', extra)
        self.invalid_graph(CHAPTER, lambda d: d['scenes'].append({'id': 'second_scene', 'path': 'data/scenes/second.json'}))
        # Duplicate line identities across different dialogue documents.
        self.invalid_graph(ARRIVAL, lambda d: (d['lines'].update(intro_01=d['lines'].pop('arrival_01')), d.update(order=['intro_01', 'arrival_02'])))
        # Symlink outside expected subtree, including a symlinked parent.
        outside = self.root / 'outside.json'; outside.write_bytes((self.root / SCENE).read_bytes())
        (self.root / SCENE).unlink(); (self.root / SCENE).symlink_to(outside)
        self.assertEqual(invoke(self.root, 'validate-content')[0], 2)

    def test_03_migration(self):
        original = subprocess.check_output(['git', 'show', '66eab13:' + CHAPTER], cwd=ROOT)
        self.assertEqual((self.root / 'data/legacy/chapter_01.v0.json').read_bytes(), original)
        legacy = json.loads(original)
        chapter, scene = self.read(CHAPTER), self.read(SCENE)
        self.assertEqual(chapter['id'], legacy['id'])
        self.assertEqual(chapter['passenger'], legacy['passenger']['id'])
        self.assertEqual(chapter['reward'], legacy['keepsake'])
        self.assertEqual(scene['puzzle']['branch'], legacy['obstacle']['id'])
        self.assertEqual(scene['puzzle']['kind'], legacy['obstacle']['puzzle'])
        self.assertEqual(scene['objects'][scene['puzzle']['snail']]['kind'], 'snail')
        for beat, path in zip(legacy['story_beats'], [INTRO, ARRIVAL]):
            doc = self.read(path)
            self.assertEqual(beat['id'], doc['id'])
            self.assertEqual(beat['lines'], [doc['lines'][key]['text'] for key in doc['order']])
        self.assertNotIn('flags', chapter)
        (self.root / CHAPTER).write_bytes(original)
        status, body = invoke(self.root, 'validate-content')
        self.assertEqual(status, 2)
        self.assertEqual(body['diagnostics'][0]['code'], 'migration_required')
        self.assertEqual((self.root / CHAPTER).read_bytes(), original)

    def test_04_round_trip_and_operations(self):
        before = self.disk(); old_scene = self.read(SCENE)
        request = json.loads((ROOT/'tests/editor/fixtures/move-handle.json').read_bytes())
        request['expected_revision'] = self.revision()
        result = self.apply(request)
        self.assertEqual(result['commit_state'], 'committed')
        current = self.read(SCENE)
        self.assertEqual(set(current['objects']), set(old_scene['objects']))
        self.assertEqual(current['puzzle'], old_scene['puzzle'])
        self.assertEqual(current['objects']['crank_handle']['position'], [596, 128])
        for path, b in before.items():
            if path != SCENE: self.assertEqual((self.root / path).read_bytes(), b)
        # Deterministic normalized bytes and true no-op preserve even arbitrary whitespace.
        newbytes = (self.root / SCENE).read_bytes()
        self.assertTrue(newbytes.endswith(b'\n'))
        self.assertEqual(json.loads(newbytes), current)
        spaced = b' \n' + newbytes
        (self.root / SCENE).write_bytes(spaced)
        unchanged_revision = self.revision()
        noop = self.apply(self.request(ops=request['operations']))
        self.assertEqual(noop['commit_state'], 'not_committed')
        self.assertEqual(noop['new_revision'], unchanged_revision)
        self.assertEqual((self.root / SCENE).read_bytes(), spaced)
        # Line create + order is legal as a single batch. Unicode survives edits.
        extra = {'op': 'create', 'collection': 'lines', 'id': 'intro_extra', 'value': {'speaker': 'oliver', 'text': '猫 says café 🚂'}}
        order = {'op': 'set_order', 'order': ['intro_02', 'intro_extra', 'intro_01']}
        self.apply(self.request([extra, order], document='intro'))
        self.apply(self.request([{'op': 'update_dialogue', 'id': 'intro_extra', 'text': 'A rainy café — 猫 🚂', 'speaker': 'milo'}], document='intro'))
        self.assertEqual(self.read(INTRO)['lines']['intro_extra'], {'speaker': 'milo', 'text': 'A rainy café — 猫 🚂'})
        self.apply(self.request([{'op': 'delete', 'collection': 'lines', 'id': 'intro_extra'}, {'op': 'set_order', 'order': ['intro_01', 'intro_02']}], document='intro'))
        self.assertEqual(self.read(INTRO)['id'], 'intro')
        # Create a fresh spawn, relink, and delete it after relinking back.
        self.apply(self.request([{'op': 'create', 'collection': 'spawns', 'id': 'entry_two', 'value': {'kind': 'player_feet', 'position': [148, 144]}}, {'op': 'link_object', 'role': 'player_spawn', 'target': 'entry_two'}]))
        self.apply(self.request([{'op': 'link_object', 'role': 'player_spawn', 'target': 'puzzle_entry'}, {'op': 'delete', 'collection': 'spawns', 'id': 'entry_two'}]))

    def test_05_atomic_batches_and_allowlists(self):
        request = self.request()
        request['operations'].append({'op': 'delete', 'collection': 'objects', 'id': 'winch'})
        before = self.disk(); self.apply(request, 2); self.assertEqual(self.disk(), before)
        bad_ops = [
            {'op': 'set_property', 'collection': 'objects', 'id': 'crank_handle', 'property': 'id', 'value': 'renamed'},
            {'op': 'set_property', 'collection': 'objects', 'id': 'crank_handle', 'property': 'path', 'value': '../bad'},
            {'op': 'create', 'collection': 'objects', 'id': 'crank_handle', 'value': {}},
            {'op': 'set_property', 'collection': 'objects', 'id': 'missing', 'property': 'position', 'value': [1, 1]},
            {'op': 'set_property', 'collection': 'spawns', 'id': 'puzzle_entry', 'property': 'kind', 'value': 'oops'},
            {'op': 'link_object', 'role': 'handle', 'target': 'winch'},
            {'op': 'restore_document', 'value': dict(self.read(SCENE), id='new_identity')},
        ]
        for op in bad_ops:
            with self.subTest(op=op):
                before = self.disk(); self.apply(self.request([op]), 2); self.assertEqual(self.disk(), before)
        for mutate in [lambda r: r.update(document=['oliver_obstacle', 'intro']),
                       lambda r: r['operations'].append({'op': 'update_dialogue', 'document': 'intro', 'id': 'intro_01', 'text': 'bad'}),
                       lambda r: r.update(documents=['intro'])]:
            r = self.request(); mutate(r); before = self.disk(); self.apply(r, 2); self.assertEqual(self.disk(), before)
        self.apply((ROOT/'tests/editor/fixtures/trailing-comma.json').read_bytes(), 2)
        self.assertFalse(list((self.root / 'data').rglob('.tls-content-*')))

    def wait_marker(self, marker, process):
        deadline = time.monotonic() + 8
        while not marker.exists():
            if process.poll() is not None: self.fail('Process exited before rendezvous: %r' % (process.communicate(),))
            if time.monotonic() > deadline:
                process.kill(); self.fail('Timed out waiting for checkpoint')
            time.sleep(.01)

    def paused_writer(self, request, checkpoint):
        path = self.root / 'paused-request.json'; path.write_bytes(encode(request))
        marker = self.root / 'rendezvous'
        env = dict(os.environ, TLS_E0_PAUSE=checkpoint, TLS_E0_MARKER=str(marker))
        process = subprocess.Popen([str(FAULT_CLI), 'apply-edit', '--project-root', str(self.root), '--request', str(path)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
        self.addCleanup(lambda: process.kill() if process.poll() is None else None)
        self.wait_marker(marker, process)
        return process, marker

    def test_06_concurrency_and_external_changes(self):
        request = self.request(); before = self.disk()
        process, marker = self.paused_writer(request, 'locked')
        conflict = self.apply(request, 3)
        self.assertEqual(conflict['diagnostics'][0]['code'], 'busy')
        self.assertEqual(self.disk(), before)
        Path(str(marker) + '.release').touch()
        out, err = process.communicate(timeout=10)
        self.assertEqual(process.returncode, 0, (out, err))
        stale = self.apply(request, 3)
        self.assertEqual(stale['diagnostics'][0]['code'], 'stale_revision')
        # A referenced document's whitespace also invalidates the graph revision.
        r = self.request(); (self.root / INTRO).write_bytes((self.root / INTRO).read_bytes() + b' ')
        self.apply(r, 3)
        # Unmanaged change immediately before commit is detected without overwrite.
        marker.unlink(); Path(str(marker) + '.release').unlink()
        r = self.request([{'op':'set_property','collection':'objects','id':'crank_handle','property':'position','value':[588,128]}]); process, marker = self.paused_writer(r, 'before_recheck')
        (self.root / ARRIVAL).write_bytes((self.root / ARRIVAL).read_bytes() + b' ')
        external = self.disk(); Path(str(marker) + '.release').touch()
        out, err = process.communicate(timeout=10)
        self.assertEqual(process.returncode, 3, (out, err))
        self.assertEqual(json.loads(out)['commit_state'], 'not_committed')
        self.assertEqual(self.disk(), external)

    def test_07_io_and_crash_recovery(self):
        for fault in ['short_write', 'temp', 'sync', 'close', 'rename', 'history']:
            with self.subTest(fault=fault):
                before = self.disk()
                result = self.apply(self.request(), 4, env=dict(os.environ, TLS_E0_FAULT=fault), binary=FAULT_CLI)
                self.assertEqual(result['commit_state'], 'not_committed')
                self.assertEqual(self.disk(), before)
        request = self.request(); before = self.disk()
        process, marker = self.paused_writer(request, 'before_rename')
        process.kill(); process.communicate(timeout=5)
        self.assertEqual(self.disk(), before)
        drafts=list((self.root/'data/scenes').glob('.tls-content-*'))
        self.assertTrue(drafts, 'termination before rename retains a recoverable candidate')
        self.assertEqual(json.loads(drafts[-1].read_bytes())['objects']['crank_handle']['position'], [596,128])
        records = list((self.root / '.studio/history').glob('txn-*/prepared.json'))
        self.assertTrue(records)
        # Kernel releases F_SETLK on SIGKILL; a new transaction succeeds.
        self.apply(request)
        marker.unlink()
        request = self.request([{'op':'set_property','collection':'objects','id':'crank_handle','property':'position','value':[588,128]}])
        before = self.disk(); process, marker = self.paused_writer(request, 'after_rename')
        after = self.disk(); self.assertNotEqual(after[SCENE], before[SCENE])
        process.kill(); process.communicate(timeout=5)
        self.assertEqual(self.revision(), self.revision())
        matched = [p for p in (self.root / '.studio/history').glob('txn-*') if (p / 'before.json').read_bytes() == before[SCENE] and (p / 'after.json').read_bytes() == after[SCENE]]
        self.assertTrue(matched, 'both complete images must survive termination after rename')
        for fault, position in [('directory_sync',[596,128]), ('finalize_history',[588,128])]:
            request = self.request([{'op':'set_property','collection':'objects','id':'crank_handle','property':'position','value':position}])
            result = self.apply(request, 5, env=dict(os.environ,TLS_E0_FAULT=fault),binary=FAULT_CLI)
            self.assertEqual(result['commit_state'],'committed_durability_uncertain')
            self.assertEqual(self.read(SCENE)['objects']['crank_handle']['position'],position)
            self.assertEqual(result['new_revision'],self.revision())
            history = self.root / '.studio/history' / result['undo_token']
            self.assertTrue((history/'before.json').exists())
            self.assertTrue((history/'prepared.json').exists())

    def test_08_undo_and_history_requirements(self):
        original = (self.root / SCENE).read_bytes()
        request = self.request(); committed = self.apply(request)
        history = self.root / '.studio/history' / committed['undo_token']
        self.assertEqual((history / 'before.json').read_bytes(), original)
        record = json.loads((history / 'prepared.json').read_bytes())
        self.assertEqual(record['old_revision'], request['expected_revision'])
        self.assertEqual(record['new_revision'], committed['new_revision'])
        restored_doc = json.loads((history / 'before.json').read_bytes())
        undo = self.request([{'op':'restore_document','value':restored_doc}])
        self.apply(dict(undo, expected_revision=request['expected_revision']),3)
        self.apply(undo)
        self.assertEqual(self.read(SCENE), json.loads(original))
        # Redo is another validated transaction, using the saved after-image.
        after_image=json.loads((history/'after.json').read_bytes())
        self.apply(self.request([{'op':'restore_document','value':after_image}]))
        self.assertEqual(self.read(SCENE),after_image)
        self.apply(self.request([{'op':'restore_document','value':restored_doc}]))
        self.assertEqual(self.read(SCENE),json.loads(original))
        bad = copy.deepcopy(restored_doc); bad['puzzle']['handle']='winch'
        before = self.disk(); self.apply(self.request([{'op':'restore_document','value':bad}]),2); self.assertEqual(self.disk(),before)
        # Actual filesystem obstruction, not just injected failure.
        shutil.rmtree(self.root/'.studio/history'); (self.root/'.studio/history').write_text('blocked')
        before=self.disk(); result=self.apply(self.request(),4); self.assertEqual(result['commit_state'],'not_committed'); self.assertEqual(self.disk(),before)

    def test_09_revisions_assets_and_inspection(self):
        status, body = invoke(self.root, 'inspect-scene')
        self.assertEqual(status,0,body)
        self.assertEqual(body['document_path'],SCENE)
        self.assertEqual(body['authored'],self.read(SCENE))
        self.assertEqual(body['resolved_links']['handle'],'crank_handle')
        self.assertIn('interaction',body['editable_fields']['objects'])
        dependencies = sorted(PATHS)
        h=hashlib.sha256()
        for path in dependencies:
            digest=hashlib.sha256((self.root/path).read_bytes()).digest()
            self.assertEqual(body['document_revisions'][path],'sha256:'+digest.hex())
            h.update(struct.pack('>Q',len(path.encode())));h.update(path.encode());h.update(struct.pack('>Q',32));h.update(digest)
        self.assertEqual(body['graph_revision'],'sha256:'+h.hexdigest())
        # Asset bytes participate in the revision and hash validation.
        asset_bytes=b'original asset fixture'
        (self.root/'assets/test.bin').write_bytes(asset_bytes)
        manifest=self.read(ASSETS)
        manifest['assets']['test_sprite']={'path':'assets/test.bin','sha256':hashlib.sha256(asset_bytes).hexdigest(),'frame_size':[8,8],'frame_count':1,'pivot':[0,0],'provenance':{'creator':'test','source':'fixture','license':'CC0','attribution':''}}
        self.write(ASSETS,manifest)
        scene=self.read(SCENE);scene['objects']['crank_handle']['asset']='test_sprite';self.write(SCENE,scene)
        previous=self.revision()
        (self.root/'assets/test.bin').write_bytes(b'changed')
        self.assertEqual(invoke(self.root,'validate-content')[0],2)
        manifest['assets']['test_sprite']['sha256']=hashlib.sha256(b'changed').hexdigest();self.write(ASSETS,manifest)
        self.assertNotEqual(self.revision(),previous)
        self.invalid_graph(ASSETS,lambda d:d['assets']['test_sprite'].update(path='../test.bin'))
        # Release CLI ignores fault environment; only explicitly compiled test binary honors it.
        result=self.apply(self.request(),env=dict(os.environ,TLS_E0_FAULT='rename'))
        self.assertEqual(result['commit_state'],'committed')


if __name__ == '__main__':
    os.chdir(ROOT)
    (ROOT/'build').mkdir(exist_ok=True)
    subprocess.run(['odin','build','tools/content','-out:build/tls-content-test','-define:E0_TEST_HOOKS=true'],check=True)
    unittest.main(verbosity=2)
