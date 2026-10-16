"""T-E4-2: real filesystem aliases and real-compiler dependency freshness."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from common import Client, server_module


class ReservationAliasTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='tls-e4-alias-', dir='/tmp')
        self.root = Path(self.temp.name).resolve()
        for directory in ('src', 'src/Réservé', 'editor', 'data', 'docs'):
            (self.root / directory).mkdir(exist_ok=True)
        self.originals = {
            'src/Owned.odin': 'package main\n',
            'src/café.odin': 'package main\n// accented\n',
            'src/Réservé/Child.odin': 'package main\n// directory\n',
            'editor/server.py': '# bridge source\n',
            'src/free.odin': 'package main\n// free\n',
            'data/readonly.json': '{}',
            'docs/readonly.md': 'read only',
            'src/forbidden.py': '# read only extension\n',
        }
        for path, text in self.originals.items():
            (self.root / path).write_text(text)
        self.client = Client(self.root, reservations=('src/Owned.odin', 'src/café.odin', 'src/Réservé', 'editor/server.py', 'src/Future.odin'))

    def tearDown(self):
        self.client.close()
        self.temp.cleanup()

    def write(self, path):
        original = (self.root / path).read_bytes()
        return self.client.raw(dict(command='write-source', path=path,
                                    expected_sha256=hashlib.sha256(original).hexdigest(),
                                    text='// replacement\n', request_id='e4_alias'))

    def test_real_case_normalization_mixed_root_extension_and_directory_aliases(self):
        aliases = {
            'src/Owned.odin': ('src/owned.odin', 'SRC/OWNED.ODIN'),
            'src/café.odin': ('src/cafe\u0301.odin', 'sRc/CAFE\u0301.ODIN'),
            'src/Réservé/Child.odin': ('src/re\u0301serve\u0301/child.odin', 'SRC/RÉSERVÉ/CHILD.ODIN'),
            'editor/server.py': ('editor/Server.py', 'EDITOR/SERVER.PY'),
        }
        # This regression must exercise actual filesystem alias resolution, not a mocked OS.
        for original, spellings in aliases.items():
            for alias in (original,) + spellings:
                with self.subTest(alias=alias):
                    self.assertEqual((self.root / alias).stat().st_ino, (self.root / original).stat().st_ino,
                                     'Run alias regression on the real case-insensitive APFS volume')
                    self.assertFalse(self.client.api('read-file', path=alias)['writable'])
                    status, _ = self.write(alias)
                    self.assertEqual(status, 403)
                    self.assertEqual((self.root / original).read_text(), self.originals[original])
        for alias in ('DATA/READONLY.JSON', 'DOCS/READONLY.MD', 'SRC/FORBIDDEN.PY'):
            with self.subTest(alias=alias):
                self.assertEqual(self.write(alias)[0], 403)
        # Canonical allowlisted aliases remain usable when they have no reservation.
        self.assertEqual(self.write('SRC/FREE.ODIN')[0], 200)

    def test_live_identity_and_missing_reservation_creation_policy(self):
        workspace = self.client.bridge.workspace
        os.link(self.root / 'src/Owned.odin', self.root / 'src/other.odin')
        self.assertFalse(workspace.writable('src/other.odin'))
        os.unlink(self.root / 'src/other.odin')
        self.assertFalse(workspace.writable('SRC/future.ODIN'))
        (self.root / 'src/Future.odin').write_text('package main\n')
        self.assertEqual(self.write('SRC/FUTURE.ODIN')[0], 403)
        # A new inode replacing a reservation must remain protected.
        replacement = self.root / 'src/replacement.odin'
        replacement.write_text('package main\n// new inode\n')
        os.replace(replacement, self.root / 'src/Owned.odin')
        self.assertEqual(self.write('src/owned.odin')[0], 403)
        (self.root / 'src/straße.odin').write_text('package main\n')
        # Unicode casefold can collide even where APFS does not resolve the spelling.
        if not (self.root / 'src/STRASSE.ODIN').exists():
            self.assertFalse(workspace.writable('src/STRASSE.ODIN'))

    def test_reservation_rechecked_before_replace(self):
        workspace = self.client.bridge.workspace
        original = workspace.journal
        def reserve(transaction, record):
            original(transaction, record)
            workspace.reservations += ('src/free.odin',)
        with patch.object(workspace, 'journal', side_effect=reserve):
            self.assertEqual(self.write('SRC/FREE.ODIN')[0], 403)
        self.assertEqual((self.root / 'src/free.odin').read_text(), self.originals['src/free.odin'])


@unittest.skipUnless(shutil.which('odin'), 'Real Odin compiler required')
class CompilerInputTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='tls-e4-inputs-', dir='/tmp')
        self.root = Path(self.temp.name).resolve()
        for directory in ('src', 'shared', 'tools/content', 'tools/helper', 'data', 'assets', 'tests'):
            (self.root / directory).mkdir(parents=True, exist_ok=True)
        (self.root / 'src/main.odin').write_text('package main\nmain :: proc() {}\n')
        (self.root / 'tools/content/main.odin').write_text('package main\nmain :: proc() {}\n')
        self.client = Client(self.root)

    def tearDown(self):
        self.client.close()
        self.temp.cleanup()

    def stale(self, command):
        with self.assertRaises(server_module.BridgeError) as caught:
            self.client.bridge.workspace.artifact_path(command)
        self.assertEqual(caught.exception.status, 409)

    def test_astra_imported_helper_and_load_json_reproducers_all_artifact_targets(self):
        for command in ('build-dev', 'build-release', 'build-content'):
            for kind in ('import', 'load'):
                with self.subTest(command=command, kind=kind):
                    source = 'tools/content/main.odin' if command == 'build-content' else 'src/main.odin'
                    if kind == 'import':
                        relative = '../helper' if command == 'build-content' else '../tools/helper'
                        code = 'import helper "' + relative + '"\nmain :: proc() { fmt.println(helper.value) }\n'
                        path, before, after = 'tools/helper/value.odin', 'package helper\nvalue :: "BEFORE"\n', 'package helper\nvalue :: "AFTER"\n'
                    else:
                        relative = '../../tests/payload.json' if command == 'build-content' else '../tests/payload.json'
                        code = 'main :: proc() { fmt.println(string(#load("' + relative + '"))) }\n'
                        path, before, after = 'tests/payload.json', '"BEFORE"', '"AFTER"'
                    (self.root / source).write_text('package main\nimport "core:fmt"\n' + code)
                    (self.root / path).write_text(before)
                    built = self.client.job(command)
                    self.assertEqual(built['exit_code'], 0, built)
                    self.assertTrue(built['current_source'], built)
                    self.assertIn('BEFORE', subprocess.check_output([built['artifact']], text=True))
                    file = self.client.api('read-file', path=path)
                    self.client.api('write-source', path=path, expected_sha256=file['sha256'], text=after, request_id='e4_input')
                    self.stale(command)
                    self.assertNotEqual(built['source_before'], self.client.bridge.workspace.fingerprint(command))
                    if command == 'build-dev':
                        for action in ('run-scene', 'run-journey', 'preview-scene'):
                            self.assertEqual(self.client.raw(dict(command=action))[0], 409)
                    rebuilt = self.client.job(command)
                    self.assertEqual(rebuilt['exit_code'], 0, rebuilt)
                    self.assertIn('AFTER', subprocess.check_output([self.client.bridge.workspace.artifact_path(command)['artifact']], text=True))

    def test_all_regular_bytes_additions_deletions_and_exact_argv(self):
        workspace = self.client.bridge.workspace
        for root in ('src', 'shared', 'tools', 'data', 'assets'):
            path = self.root / root / '.binary-input'
            baseline = workspace.fingerprint('build-dev')
            path.write_bytes(b'\x00BEFORE\xff')
            added = workspace.fingerprint('build-dev')
            self.assertNotEqual(baseline, added, root)
            path.write_bytes(b'\x00AFTER!\xff')
            self.assertNotEqual(added, workspace.fingerprint('build-dev'), root)
            path.unlink()
            self.assertEqual(baseline, workspace.fingerprint('build-dev'), root)
        first = workspace.fingerprint('build-dev', ['odin', 'build', 'src', '-out:a'])
        self.assertNotEqual(first, workspace.fingerprint('build-dev', ['odin', 'build', 'src', '-out:b']))
        built = self.client.job('build-dev')
        self.assertEqual(built['exit_code'], 0, built)
        (self.root / 'assets/image.bin').write_bytes(b'changed runtime/compiler asset')
        self.stale('build-dev')

    def test_load_directory_nested_inputs_and_raw_literal(self):
        (self.root / 'tests/input').mkdir()
        (self.root / 'tests/input/payload.json').write_text('BEFORE')
        (self.root / 'src/main.odin').write_text('package main\nimport "core:fmt"\nmain :: proc() { files := #load_directory(`../tests/input`); fmt.println(string(files[0].data)) }\n')
        built = self.client.job('build-dev')
        self.assertEqual(built['exit_code'], 0, built)
        self.assertIn('BEFORE', subprocess.check_output([built['artifact']], text=True))
        (self.root / 'tests/input/payload.json').write_text('AFTER')
        self.stale('build-dev')
        (self.root / 'tests/input/added').write_text('new file')
        self.assertNotEqual(built['source_before'], self.client.bridge.workspace.fingerprint('build-dev'))

    def test_external_import_load_unknown_expression_and_symlinks_refused_before_spawn(self):
        outside = self.root.parent / (self.root.name + '-external')
        outside.mkdir()
        (outside / 'value.odin').write_text('package helper\nvalue :: 1\n')
        (outside / 'payload.json').write_text('{}')
        try:
            fixtures = [
                'import helper "../../' + outside.name + '"',
                'x :: #load("../../' + outside.name + '/payload.json")',
                'import helper "' + str(outside) + '"',
                'x :: #load("' + str(outside / 'payload.json') + '")',
                'x :: #load_directory("../../' + outside.name + '")',
                'name :: "../tests/payload.json"\nx :: #load(name)',
                'x :: #load("../tests/" + "payload.json")',
                'import helper "unknown:helper"',
                'import helper "core:../outside"',
                'foreign import lib "system:' + str(outside / 'lib.a') + '"',
            ]
            for code in fixtures:
                (self.root / 'src/main.odin').write_text('package main\n' + code + '\nmain :: proc() {}\n')
                for command in ('build-dev', 'build-content'):
                    with self.subTest(code=code, command=command):
                        status, result = self.client.raw(dict(command=command))
                        self.assertEqual(status, 403, result)
                        self.assertIn('Build refused', result['error'])
                        self.assertFalse(self.client.bridge.workspace.jobs)
            (self.root / 'src/main.odin').write_text('package main\nmain :: proc() {}\n')
            (self.root / 'assets/escape').symlink_to(outside, target_is_directory=True)
            self.assertEqual(self.client.raw(dict(command='build-dev'))[0], 403)
            (self.root / 'assets/escape').unlink()
            (self.root / 'tests/payload.json').write_text('{}')
            (self.root / 'tests/escape').symlink_to(outside, target_is_directory=True)
            (self.root / 'src/main.odin').write_text('package main\nx :: #load("../tests/escape/../payload.json")\nmain :: proc() {}\n')
            status, result = self.client.raw(dict(command='build-dev'))
            self.assertEqual(status, 403)
            self.assertIn('symlinked compiler input', result['error'])
        finally:
            shutil.rmtree(outside)

    def test_comments_and_strings_do_not_invent_dependencies(self):
        (self.root / 'src/main.odin').write_text('''package main
// import "../../outside"
/* outer /* #load("../../outside") */ import "../../outside" */
example :: `#load("../../outside")`
main :: proc() { _ = example }
''')
        built = self.client.job('build-dev')
        self.assertEqual(built['exit_code'], 0, built)
        self.client.bridge.workspace.artifact_path('build-dev')


if __name__ == '__main__':
    unittest.main()
