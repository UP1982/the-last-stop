#!/usr/bin/env python3
"""Compare production pagination/drawing with live raylib bitmap-font metrics."""
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='typography-', dir='/tmp') as directory:
    directory = Path(directory)
    shutil.copyfile(ROOT / 'src/story_text.odin', directory / 'story_text.odin')
    shutil.copyfile(ROOT / 'src/story_ui.odin', directory / 'story_ui.odin')
    shutil.copyfile(ROOT / 'tests/story/typography.odin', directory / 'main.odin')
    subprocess.run(['odin', 'run', str(directory), '-out:' + str(directory / 'test')],
                   cwd=ROOT, check=True, timeout=60)
