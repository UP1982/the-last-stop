"""E4-only SIGKILL rendezvous around the actual draft rename."""
import json, os, sys, time
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'editor_workspace'))
from common import server_module
root, phase, marker = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
bridge = server_module.Bridge(root)
current = bridge.workspace.read_draft('scene', 'oliver_obstacle')
replace = os.replace

def rendezvous(src, dst, **kwargs):
    if phase == 'after': replace(src, dst, **kwargs)
    marker.write_text(phase)
    while True: time.sleep(.01)

with patch.object(os, 'replace', side_effect=rendezvous):
    bridge.workspace.write_draft('scene', 'oliver_obstacle', current['sha256'], {'draft': 'complete new', 'revision': 'original'})
