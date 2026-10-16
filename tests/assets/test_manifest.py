#!/usr/bin/env python3
"""Run: python3 -B tests/assets/test_manifest.py (no third-party packages).

Validates every active manifest sprite, including currently unlinked assets.
Source-pack access is deliberately unnecessary for this portable acceptance test.
"""
import hashlib
import json
from pathlib import Path
import unittest

from png_rgba import read_png

ROOT = Path(__file__).resolve().parents[2]


class ManifestAssets(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.assets = json.loads((ROOT / 'data/assets/manifest.json').read_text())['assets']

    def test_files_exist_and_are_confined(self):
        for asset_id, asset in self.assets.items():
            with self.subTest(asset=asset_id):
                path = (ROOT / asset['path']).resolve()
                self.assertTrue(path.is_relative_to((ROOT / 'assets').resolve()))
                self.assertTrue(path.is_file(), str(path))

    def test_exact_file_hashes(self):
        for asset_id, asset in self.assets.items():
            with self.subTest(asset=asset_id):
                self.assertEqual(hashlib.sha256((ROOT / asset['path']).read_bytes()).hexdigest(), asset['sha256'])

    def test_horizontal_strip_dimensions(self):
        for asset_id, asset in self.assets.items():
            with self.subTest(asset=asset_id):
                w, h, _ = read_png(ROOT / asset['path'])
                fw, fh = asset['frame_size']
                self.assertGreater(asset['frame_count'], 0)
                self.assertEqual((w, h), (fw * asset['frame_count'], fh))

    def test_pivots_inside_each_frame(self):
        for asset_id, asset in self.assets.items():
            with self.subTest(asset=asset_id):
                for pivot, size in zip(asset['pivot'], asset['frame_size']):
                    self.assertGreaterEqual(pivot, 0)
                    self.assertLess(pivot, size)


if __name__ == '__main__':
    unittest.main(verbosity=2)
