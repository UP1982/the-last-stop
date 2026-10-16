#!/usr/bin/env python3
"""M3b contract 4: production playback/save/input in isolated fresh processes."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
BIN = ROOT / 'build/m3b-test'
FIXTURES = ROOT / 'build/m3b-fixtures'
NORMAL = Path.home() / 'Library/Application Support/The Last Stop/saves'
OUT = ROOT / 'build/evidence/m3b'


def hashes(path):
    if not path.exists(): return None
    return {str(p.relative_to(path)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(path.rglob('*')) if p.is_file()}


def call(command, save, binary=BIN, root=ROOT, env=None):
    p = subprocess.run([str(binary), command, '--save-dir', str(save), '--project-root', str(root)],
                       cwd='/tmp', capture_output=True, timeout=60,
                       env=dict(os.environ, **(env or {})))
    assert p.returncode == 0, (command, p.returncode, p.stdout.decode(), p.stderr.decode())
    return p.stdout.decode()


class StoryRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='tls-m3b-', dir=ROOT / 'build')
        self.directory = Path(self.temp.name)
        self.save = self.directory / 'profile'
        self.path = self.save / 'chapter_01.json'

    def tearDown(self): self.temp.cleanup()
    def seed(self, name): call('write-' + name, self.save, binary=FIXTURES)
    def record(self): return json.loads(self.path.read_bytes())

    def test_01_every_beat_page_convergence_pause_input_and_guards(self):
        output = call('selftest', self.save)
        self.assertIn('52 cases', output)
        self.assertIn('PASS guards', output)
        (OUT / 'runtime-selftest.txt').write_text(output)

    def test_02_edited_long_text_all_roles_pagination_and_unicode(self):
        content = self.directory / 'content'
        shutil.copytree(ROOT / 'data', content / 'data')
        for path in (content / 'data/dialogue').glob('*.json'):
            d = json.loads(path.read_bytes())
            for line in d['lines'].values():
                line['text'] += ' — ' + 'A quiet journey… ' * 25
            path.write_text(json.dumps(d, ensure_ascii=False))
        path = content / 'data/chapters/chapter_01.json'
        d = json.loads(path.read_bytes())
        for key in ('end_card', 'supper_card'): d['strings'][key] += ' — ' + 'Welcome… ' * 35
        path.write_text(json.dumps(d, ensure_ascii=False))
        before = hashes(content)
        output = call('selftest', self.save, root=content)
        self.assertNotIn('paginated positions: 0', output)
        self.assertEqual(hashes(content), before)
        (OUT / 'runtime-long-text.txt').write_text(output)

    def test_03_all_checkpoints_and_puzzle_states_fresh_process_to_title(self):
        results = []
        for state in ('chapter_start','boarded','shelf','held','dropped','installed','cranking','cleared','returned','arrival','complete'):
            with self.subTest(state=state):
                self.seed(state)
                original = self.path.read_bytes()
                expected = self.record()['checkpoint']
                output = call('resume', self.save)
                self.assertIn('RESTORED', output)
                self.assertIn('cues 0 0', output)
                self.assertIn('checkpoint Complete mode Title flower true', output)
                self.assertEqual(self.record()['checkpoint'], 'complete')
                if state in ('cleared','returned','arrival','complete'):
                    self.assertIn('clearance cues 0', output)
                results.append(dict(state=state, checkpoint=expected, original=json.loads(original), output=output))
        (OUT / 'runtime-reloads.json').write_text(json.dumps(results, indent=2) + '\n')

    def test_04_quit_before_and_after_farewell_commit(self):
        for side in ('before','after'):
            self.seed('arrival')
            output = call(side + '-arrival', self.save)
            self.assertEqual(self.record()['checkpoint'], 'arrival' if side == 'before' else 'complete')
            output += call('resume', self.save)
            self.assertIn('mode Title flower true', output)
            (OUT / ('runtime-quit-' + side + '.txt')).write_text(output)

    def test_05_failed_save_retry_serializes_current_state_without_effects(self):
        outputs = []
        for fault in ('temp','write','sync','close','rename','directory_sync'):
            self.seed('arrival')
            output = call('retry', self.save, env={'TLS_M3B_FAULT': fault})
            self.assertIn('PASS failed-save retry', output)
            self.assertEqual(self.record()['checkpoint'], 'complete')
            outputs.append(fault + '\n' + output)
        (OUT / 'runtime-failed-save.txt').write_text('\n'.join(outputs))

    def test_06_new_game_writes_chapter_start_before_presentation(self):
        output = call('new', self.save)
        self.assertEqual(self.record()['checkpoint'], 'chapter_start')
        self.assertIn('mode Station_Intro flower false', output)
        self.assertEqual(self.record()['puzzle']['handle_location'], 'shelf')


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    before = {'data': hashes(ROOT / 'data'), 'normal_saves': hashes(NORMAL)}
    for output, define in ((BIN,'M3B_SELF_TEST'),(FIXTURES,'M2_SELF_TEST')):
        subprocess.run(['odin','build','src','-define:' + define + '=true','-define:M2_TEST_HOOKS=true','-out:' + str(output)], cwd=ROOT, check=True)
    result = unittest.main(exit=False, verbosity=2).result
    after = {'data': hashes(ROOT / 'data'), 'normal_saves': hashes(NORMAL)}
    assert before == after, 'authored content or normal saves changed'
    (OUT / 'runtime-isolation.json').write_text(json.dumps(dict(before=before, after=after), indent=2) + '\n')
    raise SystemExit(0 if result.wasSuccessful() else 1)
