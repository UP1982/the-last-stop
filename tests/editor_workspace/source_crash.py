"""Test-only process interruption around the actual source replacement syscall."""
import hashlib
import os
from pathlib import Path
import sys
import time
from unittest.mock import patch
from common import server_module

root, phase, marker = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
bridge = server_module.Bridge(root)
replace = os.replace

def rendezvous(src, dst, **kwargs):
    if dst != 'main.odin':
        return replace(src, dst, **kwargs)
    if phase == 'after':
        replace(src, dst, **kwargs)
    marker.write_text(phase)
    while True: time.sleep(.01)

path = root / 'src/main.odin'
with patch.object(os, 'replace', side_effect=rendezvous):
    bridge.workspace.write('src/main.odin', hashlib.sha256(path.read_bytes()).hexdigest(), 'package main\n// complete new\n', 'crash_e3')
