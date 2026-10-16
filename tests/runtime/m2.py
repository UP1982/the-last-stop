#!/usr/bin/env python3
"""M2 contract 1-7: real Odin runtime/IO in fresh processes, never real saves."""
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
BIN = ROOT / 'build/m2-test'
DEV = ROOT / 'build/m2-test-dev'
SCENE = Path('data/scenes/oliver_obstacle.json')
NORMAL = Path.home() / 'Library/Application Support/The Last Stop/saves'


def hashes(path):
    if not path.exists():
        return None
    return {str(p.relative_to(path)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(path.rglob('*')) if p.is_file()}


def call(command, directory, binary=BIN, root=ROOT, env=None, expected=0, cwd='/tmp', extra=()):
    p = subprocess.run([str(binary), command, '--save-dir', str(directory),
                        '--project-root', str(root), *map(str, extra)], cwd=cwd,
                       env=dict(os.environ, **(env or {})), capture_output=True, timeout=45)
    assert p.returncode == expected, (command, p.returncode, p.stdout.decode(), p.stderr.decode())
    return p


class M2Tests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='tls-m2-', dir=ROOT / 'build')
        self.dir = Path(self.tmp.name)
        self.save = self.dir / 'saves'
        self.path = self.save / 'chapter_01.json'

    def tearDown(self):
        self.tmp.cleanup()

    def inspect(self):
        return json.loads(call('inspect', self.save).stdout)

    def test_01_behavior_real_loop_and_exhaustive_state_graph(self):
        p = call('selftest', self.save)
        self.assertIn(b'12 reachable abstract states x 9 actions', p.stdout)

    def test_02_every_checkpoint_fresh_process_then_completion(self):
        for checkpoint in ('chapter_start', 'boarded', 'shelf', 'held', 'dropped', 'installed',
                           'cranking', 'cleared', 'returned', 'arrival', 'complete'):
            with self.subTest(checkpoint=checkpoint):
                call('write-' + checkpoint, self.save)
                original = self.path.read_bytes()
                normalized = self.inspect()
                self.assertEqual(self.path.read_bytes(), original)  # normalization is not a write
                self.assertEqual(self.inspect(), normalized)  # double normalization unchanged
                p = call('resume', self.save)
                self.assertIn(b'Returned' if checkpoint not in ('arrival', 'complete') else checkpoint.capitalize().encode(), p.stdout)
                self.assertFalse(self.inspect()['puzzle']['snail_seen'])
                if checkpoint in ('cleared', 'returned', 'arrival', 'complete'):
                    self.assertIn(b'cues 0', p.stdout)  # no clearance effect replay

    def test_03_one_run_restarted_at_every_transition_no_snail(self):
        call('write-shelf', self.save)
        # Held loads as dropped: recover once, then take it all the way to winch
        # in the same fresh process (otherwise every held reload recovers again).
        call('advance', self.save)
        self.assertEqual(self.inspect()['puzzle']['handle_location'], 'dropped')
        call('drop', self.save)
        self.assertEqual(self.inspect()['puzzle']['handle_location'], 'dropped')
        call('resume', self.save)
        self.assertEqual(self.inspect()['checkpoint'], 'returned')
        self.assertFalse(self.inspect()['puzzle']['snail_seen'])
        # Also independently restart immediately after installed/cranking/cleared.
        for checkpoint in ('installed', 'cranking', 'cleared'):
            call('write-' + checkpoint, self.save)
            call('pause-save', self.save)
            call('quit-save', self.save)
            call('resume', self.save)
            self.assertEqual(self.inspect()['checkpoint'], 'returned')

        call('write-shelf', self.save)
        call('snail', self.save)
        self.assertTrue(self.inspect()['puzzle']['snail_seen'])
        call('resume', self.save)
        self.assertTrue(self.inspect()['puzzle']['snail_seen'])

    def test_04_spatial_recovery_and_changed_authored_geometry(self):
        call('write-dropped', self.save)
        record = self.inspect()
        self.assertEqual(record['puzzle']['dropped_feet'], json.loads(self.path.read_bytes())['puzzle']['dropped_feet'])
        for feet in ([-2000, 288], [1280, 288], [0, 288], [1000, -1998], [1000, 280], [1e30, 1e30], [1e300, 288]):
            bad = copy.deepcopy(record)
            bad['puzzle']['dropped_feet'] = feet
            self.path.write_text(json.dumps(bad))
            self.assertEqual(self.inspect()['puzzle']['dropped_feet'], [1184, 288])
            call('resume', self.save)
        fixture = self.dir / 'moved'
        shutil.copytree(ROOT / 'data', fixture / 'data')
        shutil.copytree(ROOT / 'assets', fixture / 'assets')
        scene = json.loads((fixture / SCENE).read_bytes())
        for key in ('world_bounds', 'camera_bounds', 'ground'):
            scene[key][0] += 80
            scene[key][1] += 40
        for spawn in scene['spawns'].values():
            spawn['position'][0] += 80
            spawn['position'][1] += 40
        for obj in scene['objects'].values():
            obj['position'][0] += 80
            obj['position'][1] += 40
        scene['puzzle']['branch_cleared_position'][0] += 80
        scene['puzzle']['branch_cleared_position'][1] += 40
        (fixture / SCENE).write_text(json.dumps(scene))
        self.path.write_text(json.dumps(record))
        state = json.loads(call('inspect', self.save, root=fixture).stdout)
        self.assertEqual(state['puzzle']['dropped_feet'], [1264, 328])
        call('resume', self.save, root=fixture)
        # Invalid authored content blocks before any save access/write.
        before = self.path.read_bytes()
        (fixture / SCENE).write_text('{')
        call('resume', self.save, root=fixture, expected=2)
        self.assertEqual(self.path.read_bytes(), before)

    def test_05_strict_rejection_preserves_bytes_explicit_keep_and_reset(self):
        call('write-shelf', self.save)
        good = self.inspect()
        invalid = [b'{', b'{}', self.path.read_bytes()[:-7],
                   self.path.read_bytes().replace(b'"save_version": 2', b'"save_version": 99'),
                   self.path.read_bytes().replace(b'"save_version": 2', b'"save_version": 2, "save_version": 2'),
                   self.path.read_bytes() + b' false']
        for key, value in [('chapter_id', 'other'), ('scene_id', 'other'), ('checkpoint', 'other'),
                           ('player_spawn', 'train_return'), ('save_version', True), ('extra', 1)]:
            bad = copy.deepcopy(good); bad[key] = value; invalid.append(json.dumps(bad).encode())
        for key, value in [('handle_location', 'other'), ('phase', 'other'), ('phase', 'cleared'),
                           ('dropped_feet', [1000, 288]), ('snail_seen', 1)]:
            bad = copy.deepcopy(good); bad['puzzle'][key] = value; invalid.append(json.dumps(bad).encode())
        for feet in ([float('nan'), 288], [float('inf'), 288], ['1000', 288], [500], None):
            bad = copy.deepcopy(good); bad['puzzle'].update(handle_location='dropped', dropped_feet=feet)
            invalid.append(json.dumps(bad).encode())
        for payload in invalid:
            with self.subTest(payload=payload[:80]):
                self.path.write_bytes(payload)
                call('inspect', self.save, expected=3)
                call('title-quit', self.save)
                call('keep', self.save)
                self.assertEqual(self.path.read_bytes(), payload)
        call('reset', self.save)
        self.assertEqual(self.inspect()['puzzle']['handle_location'], 'shelf')

    def test_08_save_v1_to_v2_unit_migration(self):
        # v1 has the identical durable state model, with half-sized coordinates.
        # Check every boundary, normalization idempotence, and completion after
        # conversion; merely reading a legacy save must not rewrite its bytes.
        for checkpoint in ('chapter_start', 'boarded', 'shelf', 'held', 'dropped',
                           'installed', 'cranking', 'cleared', 'returned', 'arrival', 'complete'):
            with self.subTest(checkpoint=checkpoint):
                call('write-' + checkpoint, self.save)
                legacy = json.loads(self.path.read_bytes())
                legacy['save_version'] = 1
                feet = legacy['puzzle']['dropped_feet']
                if feet is not None:
                    legacy['puzzle']['dropped_feet'] = [n / 2 for n in feet]
                self.path.write_text(json.dumps(legacy))
                original = self.path.read_bytes()
                upgraded = self.inspect()
                self.assertEqual(upgraded['save_version'], 2)
                self.assertEqual(self.path.read_bytes(), original)
                if checkpoint == 'dropped':
                    self.assertEqual(upgraded['puzzle']['dropped_feet'], [n * 2 for n in legacy['puzzle']['dropped_feet']])
                    self.assertNotEqual(upgraded['puzzle']['dropped_feet'], legacy['puzzle']['dropped_feet'])
                elif checkpoint == 'held':
                    self.assertEqual(upgraded['puzzle']['dropped_feet'], [1184, 288])
                self.path.write_text(json.dumps(upgraded))
                self.assertEqual(self.inspect(), upgraded)  # v2 never doubles again
                call('resume', self.save)
        call('write-dropped', self.save)
        legacy = self.inspect()
        legacy['save_version'] = 1
        for feet in ([1e300, 144], [-1000, 144], [500, 140]):
            legacy['puzzle']['dropped_feet'] = feet
            self.path.write_text(json.dumps(legacy))
            self.assertEqual(self.inspect()['puzzle']['dropped_feet'], [1184, 288])
            call('resume', self.save)
        # Unit migration never repairs a contradictory phase/checkpoint.
        legacy['puzzle'].update(handle_location='dropped', phase='cleared', dropped_feet=[500, 144])
        self.path.write_text(json.dumps(legacy))
        original = self.path.read_bytes()
        call('inspect', self.save, expected=3)
        self.assertEqual(self.path.read_bytes(), original)

    def test_06_atomic_faults_and_crash_commit_boundary(self):
        call('write-returned', self.save)
        original = self.path.read_bytes()
        for fault in ('temp', 'write', 'sync', 'close', 'rename'):
            call('write-held', self.save, env={'TLS_M2_FAULT': fault}, expected=4)
            self.assertEqual(self.path.read_bytes(), original)
        p = call('write-held', self.save, env={'TLS_M2_FAULT': 'directory_sync'}, expected=5)
        self.assertIn(b'durability uncertain', p.stderr)
        self.assertEqual(json.loads(self.path.read_bytes())['puzzle']['handle_location'], 'held')
        for point in ('before_rename', 'after_rename'):
            call('write-returned', self.save)
            original = self.path.read_bytes()
            marker = self.dir / point
            env = dict(os.environ, TLS_M2_PAUSE=point, TLS_M2_MARKER=str(marker))
            p = subprocess.Popen([str(BIN), 'write-held', '--save-dir', str(self.save), '--project-root', str(ROOT)],
                                 env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                deadline = time.monotonic() + 10
                while not marker.exists() and time.monotonic() < deadline:
                    self.assertIsNone(p.poll()); time.sleep(.02)
                self.assertTrue(marker.exists())
                p.kill(); p.communicate(timeout=5)
                current = self.path.read_bytes()
                decoded = json.loads(current)
                self.assertEqual(decoded['checkpoint'], 'returned' if point == 'before_rename' else 'chapter_start')
                if point == 'before_rename': self.assertEqual(current, original)
                call('resume', self.save)
            finally:
                if p.poll() is None: p.kill(); p.communicate()

    def test_07_paths_precedence_cwd_preview_test_isolation(self):
        first = call('path', self.save, cwd=ROOT).stdout
        self.assertEqual(first, call('path', self.save, cwd='/tmp').stdout)
        default1 = call('default-path', self.save, cwd=ROOT).stdout
        self.assertEqual(default1, call('default-path', self.save, cwd='/tmp').stdout)
        self.assertEqual(default1.decode().strip(), str(NORMAL))
        env = dict(os.environ, TLS_SAVE_DIR=str(self.dir / 'environment'))
        p = subprocess.run([str(BIN), 'path', '--project-root', str(ROOT)], env=env, capture_output=True)
        self.assertEqual(p.returncode, 0)
        self.assertIn(b'environment/chapter_01.json', p.stdout)
        self.assertIn(str(self.save).encode(), call('path', self.save, env=env).stdout)
        env.pop('TLS_SAVE_DIR', None)
        p = subprocess.run([str(BIN), 'path', '--project-root', str(ROOT)], env=env, capture_output=True)
        self.assertEqual(p.returncode, 2)  # no test fallback
        home = self.dir / 'home'; home.mkdir()
        extra = ['--preview-scene', 'oliver_obstacle', '--preview-session', 'm2-isolation']
        call('resume', self.save, binary=DEV, env={'HOME': str(home)}, extra=extra)
        preview = home / 'Library/Caches/The Last Stop/preview/m2-isolation/chapter_01.json'
        self.assertEqual(json.loads(preview.read_bytes())['checkpoint'], 'returned')
        self.assertFalse(self.path.exists())  # preview wins even over --save-dir


if __name__ == '__main__':
    before_data, before_normal = hashes(ROOT / 'data'), hashes(NORMAL)
    for binary, flags in ((BIN, []), (DEV, ['-define:DEV_TOOLS=true'])):
        subprocess.run(['odin', 'build', 'src', '-define:M2_SELF_TEST=true', '-define:M2_TEST_HOOKS=true',
                        *flags, '-out:' + str(binary)], cwd=ROOT, check=True)
    suite = unittest.main(verbosity=2, exit=False)
    assert hashes(ROOT / 'data') == before_data, 'authored data mutated'
    assert hashes(NORMAL) == before_normal, 'normal saves mutated'
    print('PASS isolation: data/ and normal saves byte-identical')
    raise SystemExit(not suite.result.wasSuccessful())
