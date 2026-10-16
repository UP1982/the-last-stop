#!/usr/bin/env python3
"""Window-free E0b acceptance: real runtime adapter, roots and allocation cycles.
All mutated content and package-layout fixtures live in temporary build folders.
"""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
TEST = ROOT / 'build/e0b-runtime-test'
SCENE = 'data/scenes/oliver_obstacle.json'


def run(args, cwd=ROOT):
    p = subprocess.run(list(map(str, args)), cwd=cwd, capture_output=True, timeout=90)
    if p.returncode:
        raise AssertionError('%s\nexit %s\n%s\n%s' % (args, p.returncode, p.stdout.decode(), p.stderr.decode()))
    return p


class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='e0b-tests-', dir=str(ROOT / 'build'))
        self.root = Path(self.tmp.name)
        shutil.copytree(ROOT / 'data', self.root / 'data')
        shutil.copytree(ROOT / 'assets', self.root / 'assets')

    def tearDown(self):
        self.tmp.cleanup()

    def load(self, valid=True, binary=TEST, extra=()):
        p = run([binary, 'valid' if valid else 'invalid', '--project-root', self.root, *extra], cwd='/tmp')
        self.assertIn(b'PASS E0b valid' if valid else b'PASS E0b invalid', p.stdout)
        return p

    def test_real_graph_from_another_cwd(self):
        p = run([TEST, 'valid'], cwd='/tmp')
        self.assertIn(b'PASS E0b valid', p.stdout)

    def test_malformed_missing_and_incomplete_graph(self):
        chapter = self.root / 'data/chapters/chapter_01.json'
        original = chapter.read_bytes()
        chapter.write_bytes(b'{"kind":')
        self.assertIn(b'expected_value', self.load(False).stderr)
        chapter.unlink()
        self.assertIn(b'unsafe_path', self.load(False).stderr)
        chapter.write_bytes(original)
        (self.root / 'data/dialogue/oliver_arrival.json').unlink()
        self.assertIn(b'unsafe_path', self.load(False).stderr)

    def test_scene_v2_rejects_old_units_and_undersized_camera(self):
        path = self.root / SCENE
        current = json.loads(path.read_bytes())
        self.assertEqual(current['schema_version'], 2)
        # Old-unit content is rejected at the envelope before geometry can be
        # interpreted, even when the surrounding chapter/dialogue remains v1.
        old = dict(current, schema_version=1)
        path.write_text(json.dumps(old))
        self.assertIn(b'unsupported_version', self.load(False).stderr)
        for bounds in ([0, 0, 639, 360], [0, 0, 640, 359]):
            invalid = dict(current, camera_bounds=bounds)
            path.write_text(json.dumps(invalid))
            self.assertIn(b'camera', self.load(False).stderr)
        path.write_text(json.dumps(current))
        self.load()

    def test_authored_geometry_drives_runtime(self):
        path = self.root / SCENE
        scene = json.loads(path.read_bytes())
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
        scene['objects']['brass']['collision'] = [0, 0, 16, 16]
        scene['objects']['crank_handle']['interaction'] = [-40, -16, 96, 64]
        path.write_text(json.dumps(scene))
        self.load()

    def test_preview_determinism_and_isolated_profile(self):
        self.load(extra=['--preview-scene', 'oliver_obstacle', '--preview-session', 'e0b-test'])
        for session in ('../saves', 'UPPER', 'a/b', 'a' * 65):
            with self.subTest(session=session):
                self.assertIn(b'preview:', self.load(False, extra=['--preview-scene', 'oliver_obstacle', '--preview-session', session]).stderr)

    def test_executable_adjacent_precedence_and_no_invalid_fallback(self):
        binary = self.root / 'game-test'
        shutil.copy2(TEST, binary)
        # Adjacent data takes precedence over --project-root even when invalid.
        chapter = self.root / 'data/chapters/chapter_01.json'
        chapter.write_bytes(b'{')
        p = run([binary, 'invalid', '--project-root', ROOT], cwd='/tmp')
        self.assertIn(str(self.root).encode(), p.stderr)

    def test_app_bundle_resources(self):
        contents = self.root / 'The Last Stop.app/Contents'
        executable = contents / 'MacOS/the-last-stop'
        executable.parent.mkdir(parents=True)
        shutil.copy2(TEST, executable)
        resources = contents / 'Resources'
        resources.mkdir()
        shutil.move(str(self.root / 'data'), resources / 'data')
        shutil.move(str(self.root / 'assets'), resources / 'assets')
        p = run([executable, 'valid'], cwd='/tmp')
        self.assertIn(b'PASS E0b valid', p.stdout)

    def test_release_dependency_graph_has_no_editor(self):
        deps = self.root / 'release-deps.json'
        run(['odin', 'build', 'src', '-out:' + str(self.root / 'release-test'), '-export-dependencies:json', '-export-dependencies-file:' + str(deps)])
        exported = deps.read_text()
        self.assertIn('/shared/content/', exported)
        self.assertNotIn('content_edit', exported)
        for path in (ROOT / 'src').glob('*.odin'):
            self.assertNotIn('shared/content_edit', path.read_text())
        release_test = self.root / 'release-headless-test'
        run(['odin', 'build', 'src', '-define:E0B_SELF_TEST=true', '-out:' + str(release_test)])
        for args in (['--dump-scene'], ['--preview-scene', 'oliver_obstacle', '--preview-session', 'test']):
            p = run([release_test, 'invalid', '--project-root', ROOT, *args], cwd='/tmp')
            self.assertIn(b'unsupported option', p.stderr)



if __name__ == '__main__':
    run(['odin', 'build', 'src', '-define:E0B_SELF_TEST=true', '-define:DEV_TOOLS=true', '-out:' + str(TEST)])
    unittest.main(verbosity=2)
