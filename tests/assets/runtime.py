#!/usr/bin/env python3
"""Window-free art integration contracts plus actual Odin animation/input tests."""
import json
from pathlib import Path
import re
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[2]

class RuntimeArt(unittest.TestCase):
    def test_import_timing_matches_bounded_runtime_bridge(self):
        sidecar=json.loads((ROOT/'assets/characters/animation_clips.json').read_text())['clips']
        source=(ROOT/'src/art_render.odin').read_text()
        found={k:(int(fps),loop=='true') for k,fps,loop in re.findall(r'\{"(\w+)",(\d+),(true|false)\}',source)}
        self.assertEqual(set(found),set(sidecar))
        assets=json.loads((ROOT/'data/assets/manifest.json').read_text())['assets']
        for k,clip in sidecar.items():
            self.assertEqual(found[k],(clip['fps'],clip['loop']))
            self.assertEqual(assets[k]['frame_count'],clip['frame_count'])
            self.assertEqual(assets[k]['pivot'],clip['pivot'])

    def test_authored_refs_cover_every_supplied_actor_and_train(self):
        scene=json.loads((ROOT/'data/scenes/oliver_obstacle.json').read_text())
        self.assertEqual(scene['objects']['brass']['asset'],'brass_locomotive')
        for path in (ROOT/'data/dialogue').glob('*.json'):
            for beat in json.loads(path.read_text())['beats'].values():
                for key,actor in beat['stage']['actors'].items():
                    self.assertEqual(actor['asset'],key+'_idle_r')
                for prop in beat['stage']['props'].values():
                    if prop['kind']=='train': self.assertEqual(prop['asset'],'brass_locomotive')
                    else: self.assertNotIn('asset',prop)

    def test_actual_animation_and_input_loop(self):
        p=subprocess.run(['odin','run','src','-define:ART3_SELF_TEST=true','-define:DEV_TOOLS=true',
                          '-out:build/art3-selftest'],cwd=ROOT,capture_output=True,timeout=60)
        self.assertEqual(p.returncode,0,p.stderr.decode())
        self.assertIn(b'PASS art3:',p.stdout)

if __name__=='__main__': unittest.main(verbosity=2)
