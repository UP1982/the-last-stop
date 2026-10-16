#!/usr/bin/env python3
"""M2 review regressions. Content copies, homes and saves live only under /tmp.

TLS_M2_FIX_ROOT selects an archive checkout for the red/green comparison; copy
only src/m2_test.odin and this test into e2c6a3e, leaving production code intact.
"""
import copy
import json
import os
from pathlib import Path
import random
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(os.environ.get('TLS_M2_FIX_ROOT', Path(__file__).resolve().parents[2]))
BIN = ROOT / 'build/m2-fix-test'
CLI = ROOT / 'build/m2-fix-content'
SCENE = Path('data/scenes/oliver_obstacle.json')


class ReviewRegressions(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='tls-m2-fix-', dir='/tmp')
        self.root = Path(self.tmp.name)
        self.save = self.root / 'saves'
        self.env = dict(os.environ, HOME=str(self.root / 'home'), TLS_SAVE_DIR=str(self.save))

    def tearDown(self):
        self.tmp.cleanup()

    def call(self, command, root=ROOT, expected=0):
        p = subprocess.run([str(BIN), command, '--project-root', str(root),
                            '--save-dir', str(self.save)], cwd='/tmp', env=self.env,
                           capture_output=True, timeout=45)
        self.assertEqual(p.returncode, expected,
                         (command, p.returncode, p.stdout.decode(), p.stderr.decode()))
        return p

    def fixture(self, name, scene):
        root = self.root / name
        shutil.copytree(ROOT / 'data', root / 'data', dirs_exist_ok=True)
        shutil.copytree(ROOT / 'assets', root / 'assets', dirs_exist_ok=True)
        (root / SCENE).write_text(json.dumps(scene))
        p = subprocess.run([str(CLI), 'validate-content', '--project-root', str(root)],
                           env=self.env, capture_output=True, timeout=30)
        self.assertEqual(p.returncode, 0, p.stdout.decode() + p.stderr.decode())
        return root

    def scene(self):
        return json.loads((ROOT / SCENE).read_bytes())

    def inspect(self, root):
        return json.loads(self.call('inspect', root).stdout)

    def test_01_astra_recovery_under_snail(self):
        self.call('write-held')
        scene = self.scene()
        scene['spawns']['handle_recovery']['position'] = [812, 288]
        root = self.fixture('recovery-under-snail', scene)
        self.assertEqual(self.inspect(root)['puzzle']['dropped_feet'], [812, 288])
        self.call('resume', root)
        self.assertEqual(self.inspect(root)['checkpoint'], 'returned')
        self.assertFalse(self.inspect(root)['puzzle']['snail_seen'])

    def test_02_astra_snail_moved_onto_real_drop(self):
        self.call('write-review-drop')
        original = json.loads((self.save / 'chapter_01.json').read_bytes())
        self.assertAlmostEqual(original['puzzle']['dropped_feet'][0], 994.3072, places=3)
        scene = self.scene()
        scene['objects']['snail']['position'] = [982, 272]
        root = self.fixture('snail-over-drop', scene)
        self.assertEqual(self.inspect(root)['puzzle']['dropped_feet'], original['puzzle']['dropped_feet'])
        self.call('resume', root)
        self.assertEqual(self.inspect(root)['checkpoint'], 'returned')
        self.assertFalse(self.inspect(root)['puzzle']['snail_seen'])

    def test_03_completion_path_property_perturbed_geometry(self):
        rng = random.Random(0x4D32464958)
        original = self.scene()
        # Independent prop motion, exact overlaps, world-edge recovery, and
        # held/drop reloads. Every case goes through content validation + real
        # player movement/focus/E/R; no direct puzzle-action shortcut.
        for i in range(64):
            with self.subTest(seed=i):
                scene = copy.deepcopy(original)
                for obj in scene['objects'].values():
                    obj['position'][0] = 2 * rng.randint(24, 640 - obj['size'][0] // 2 - 24)
                recovery = 2 * rng.randint(12, 628)
                if i % 4 == 0:
                    recovery = scene['objects']['snail']['position'][0] + 12
                elif i % 4 == 1:
                    scene['objects']['crank_handle']['position'][0] = scene['objects']['snail']['position'][0] + 4
                elif i % 4 == 2:
                    recovery = scene['objects']['winch']['position'][0] + 24
                    scene['objects']['fallen_branch']['position'][0] = recovery - 48
                else:
                    recovery = 24 if i % 8 == 3 else 1256
                scene['spawns']['handle_recovery']['position'] = [recovery, 288]
                scene['puzzle']['branch_cleared_position'][0] = scene['objects']['fallen_branch']['position'][0]
                # Also move the full corridor vertically; prop x motion above
                # stays independent rather than translating one fixed layout.
                dy = 2 * rng.randint(0, 32)
                for key in ('world_bounds', 'camera_bounds', 'ground'):
                    scene[key][1] += dy
                for obj in scene['objects'].values():
                    obj['position'][1] += dy
                for spawn in scene['spawns'].values():
                    spawn['position'][1] += dy
                scene['puzzle']['branch_cleared_position'][1] += dy
                root = self.fixture('perturbed', scene)
                self.call('geometry-path', root)
                self.call('write-held', root)
                self.assertEqual(self.inspect(root)['puzzle']['dropped_feet'], [recovery, 288 + dy])
                self.call('resume', root)
                self.assertEqual(self.inspect(root)['checkpoint'], 'returned')

    def test_04_substep_return_edge_and_queue_lifetime(self):
        self.assertIn(b'exactly one return', self.call('return-edge').stdout)

    def test_05_unusable_authored_recovery_blocks_before_save_access(self):
        scene = self.scene()
        # Shared geometry fits the 16px handle here, but the M1 player footprint
        # escapes the world. Reject authoring before accessing any save profile.
        scene['spawns']['handle_recovery']['position'] = [8, 288]
        root = self.fixture('unusable-pickup', scene)
        p = self.call('path', root, expected=2)
        self.assertIn(b'chapter blocked', p.stderr)
        self.assertFalse(self.save.exists())


if __name__ == '__main__':
    (ROOT / 'build').mkdir(exist_ok=True)
    subprocess.run(['odin', 'build', 'src', '-define:M2_SELF_TEST=true',
                    '-out:' + str(BIN)], cwd=ROOT, check=True)
    subprocess.run(['odin', 'build', 'tools/content', '-out:' + str(CLI)], cwd=ROOT, check=True)
    unittest.main(verbosity=2)
