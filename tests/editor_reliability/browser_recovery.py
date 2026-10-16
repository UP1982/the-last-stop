#!/usr/bin/env python3
"""Disposable bridge for T3's real-browser large-history recovery check."""
import json, os, signal, sys, tempfile, time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'editor_workspace'))
from common import ROOT, Client, project
OUT=ROOT/'build/evidence/e4';alive=[True]
signal.signal(signal.SIGTERM,lambda *_:alive.__setitem__(0,False))
with tempfile.TemporaryDirectory(prefix='tls-e4-browser-',dir='/tmp') as directory:
    root=Path(directory).resolve();project(root);home=root/'home';home.mkdir();os.environ['HOME']=str(home)
    client=Client(root);ports=[]
    def state():
        ports.append(client.server.server_port)
        (OUT/'large-browser-state.json').write_text(json.dumps(dict(root=str(root),pid=os.getpid(),url='http://127.0.0.1:%d/#token=%s'%(client.server.server_port,client.bridge.token),ports=ports),indent=2)+'\n')
    state();print('READY',flush=True)
    try:
        deadline=time.monotonic()+600
        while alive[0] and time.monotonic()<deadline and not (root/'stop').exists():
            if (root/'restart').exists():
                (root/'restart').unlink();client.close();client=Client(root);state();print('RESTARTED',flush=True)
            time.sleep(.05)
    finally:client.close()
print('CLEANUP bridge closed; disposable HOME/project removed',flush=True)
